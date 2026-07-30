import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/message.dart';
import '../domain/message_thread.dart';
import '../domain/messaging_repository.dart';
import '../infrastructure/supabase_messaging_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => SupabaseMessagingRepository(ref.watch(supabaseClientProvider)),
);

/// The caller's inbox, most recent conversation first.
class ThreadList extends AsyncNotifier<List<MessageThread>> {
  @override
  Future<List<MessageThread>> build() async {
    // Re-runs on sign-out, so one person's conversations never survive into
    // the next session.
    ref.watch(currentUserIdProvider);

    final profile = await ref.watch(currentProfileProvider.future);
    if (profile == null || !profile.role.canUseMessaging) return const [];

    return ref.watch(messagingRepositoryProvider).fetchThreads();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// Opens the conversation and folds it into the list.
  ///
  /// Idempotent, because `open_thread()` is: tapping "Message my pastor" twice
  /// returns the same thread rather than starting a second one.
  Future<MessageThread> open({String? withId}) async {
    final thread =
        await ref.read(messagingRepositoryProvider).openThread(withId: withId);
    final current = state.value ?? const <MessageThread>[];
    state = AsyncData([
      thread,
      ...current.where((existing) => existing.id != thread.id),
    ]);
    return thread;
  }

  /// Moves a thread to the top after a message lands in it, matching what the
  /// `trg_bump_thread_activity` trigger just did server-side.
  void bump(String threadId, DateTime at) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((thread) => thread.id == threadId);
    if (index < 0) return;
    final bumped = current[index].copyWith(lastMessageAt: at);
    state = AsyncData([
      bumped,
      ...current.where((thread) => thread.id != threadId),
    ]);
  }

  Future<void> markRead(MessageThread thread) async {
    await ref.read(messagingRepositoryProvider).markRead(thread);
    // The receipt only drives an unread badge, so re-reading the row is not
    // worth a round trip -- the next refresh picks up the stamped value.
    await refresh();
  }
}

final threadListProvider =
    AsyncNotifierProvider<ThreadList, List<MessageThread>>(ThreadList.new);

/// One conversation's messages, oldest first.
class ThreadMessages extends AsyncNotifier<List<Message>> {
  ThreadMessages(this.threadId);

  /// A family notifier takes its argument through the constructor in Riverpod
  /// 3; `build` stays parameterless.
  final String threadId;

  @override
  Future<List<Message>> build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(messagingRepositoryProvider).fetchMessages(threadId);
  }

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    // The write happens first: a bubble must never appear for a message the
    // database refused.
    final sent = await ref
        .read(messagingRepositoryProvider)
        .send(threadId: threadId, body: trimmed);

    state = AsyncData([...(state.value ?? const <Message>[]), sent]);
    ref.read(threadListProvider.notifier).bump(threadId, sent.createdAt);
  }

  /// Withdraws a message inside the five-minute window.
  ///
  /// A delete outside the window matches no row and reports success, so the
  /// list is re-read rather than assumed — if the message is still there, the
  /// window had closed.
  Future<void> remove(String messageId) async {
    await ref.read(messagingRepositoryProvider).deleteMessage(messageId);
    state = await AsyncValue.guard(
      () => ref.read(messagingRepositoryProvider).fetchMessages(threadId),
    );
  }
}

final threadMessagesProvider =
    AsyncNotifierProvider.family<ThreadMessages, List<Message>, String>(
  ThreadMessages.new,
);

/// The youth pastors a member may write to. Empty for anyone who is not
/// messaging one — a pastor picks from their own youth, not from this.
final churchYouthPastorsProvider =
    FutureProvider<List<PastorOption>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.role.canMessagePastor) return const [];
  return ref.watch(messagingRepositoryProvider).fetchYouthPastors();
});

/// The single conversation to show in place of an inbox, or null when a list is
/// the right screen.
///
/// A member has one youth pastor and therefore one thread, so an inbox listing
/// exactly one row is a tap that teaches nothing — they already know who they
/// are writing to. Two youth pastors means two threads and the list earns its
/// place back. A youth pastor always gets the list: they have many, and
/// collapsing into whichever is newest would hide the others.
final soloThreadProvider = Provider<MessageThread?>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || !profile.role.canMessagePastor) return null;

  final threads = ref.watch(threadListProvider).value ?? const [];
  return threads.length == 1 ? threads.first : null;
});

/// How many conversations have something new in them. Drives the nav badge.
final unreadThreadCountProvider = Provider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final threads = ref.watch(threadListProvider).value ?? const [];
  return threads.where((thread) => thread.isUnreadFor(userId)).length;
});
