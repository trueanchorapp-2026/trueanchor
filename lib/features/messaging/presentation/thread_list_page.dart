import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../application/messaging_providers.dart';
import '../domain/message_thread.dart';
import '../domain/messaging_repository.dart';
import 'member_picker_sheet.dart';
import 'messaging_disclosure.dart';
import 'thread_page.dart';

/// The Messages tab.
///
/// Usually an inbox — a youth pastor has one thread per family member in the
/// conversation, and a member has one per youth pastor they have written to.
/// The exception is a member whose church has a single youth pastor: there is
/// only one conversation available to them, and a list of exactly one row is a
/// tap that teaches nothing. For that case the tab *is* the conversation, the
/// way a texting app opens on the thread rather than on a directory. Add a
/// second pastor and the list is the honest screen again — see
/// [soloThreadProvider], which draws that line.
class ThreadListPage extends ConsumerWidget {
  const ThreadListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsState = ref.watch(threadListProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final role = profile?.role;
    final isMember = role?.canMessagePastor ?? false;
    final canStart = role?.canUseMessaging ?? false;

    // Empty for anyone who is not a member, and not fetched for them either.
    final pastorsState = ref.watch(churchYouthPastorsProvider);

    // How many pastors the church has decides between the conversation and the
    // list, so a member's inbox cannot be drawn until that count is known.
    // Rendering the list first and swapping would flash a screen they never
    // asked for.
    if (isMember && pastorsState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Returned before the Scaffold below, which is what drops the FAB — with a
    // single pastor there is nothing left to start.
    final solo = ref.watch(soloThreadProvider);
    if (solo != null) {
      return ThreadView(threadId: solo.id, showPartnerHeader: true);
    }

    /// Opens the thread and shows it, whoever was chosen.
    Future<void> openWith(String id) async {
      try {
        final thread =
            await ref.read(threadListProvider.notifier).open(withId: id);
        if (!context.mounted) return;

        // A member with one pastor is now looking at the conversation already:
        // this tab rebuilt into it the moment the thread landed, and pushing
        // would stack a second copy of the screen in front of them.
        if (ref.read(soloThreadProvider) == null) {
          context.push(Routes.messageThreadFor(thread.id));
        }
      } on AppException catch (error) {
        if (context.mounted) {
          showAppSnack(context, error.message, isError: true);
        }
      }
    }

    /// A parent or youth writing to a pastor. Every pastor stays reachable
    /// however many threads they already hold — `open_thread()` is idempotent,
    /// so picking one they have written to before reopens it rather than
    /// starting a second conversation.
    Future<void> composeToPastor() async {
      final pastors = pastorsState.value ?? const <PastorOption>[];
      if (pastors.isEmpty) {
        showAppSnack(
          context,
          'Your church has not set up a youth pastor yet.',
          isError: true,
        );
        return;
      }

      var chosen = pastors.first;
      if (pastors.length > 1) {
        // Which pastor is never the app's guess to make: passing null would
        // hand the member whichever one has served longest, silently.
        final threads = threadsState.value ?? const <MessageThread>[];
        final picked = await _pickPastor(
          context,
          pastors,
          alreadyMessaging: {for (final thread in threads) thread.pastorId},
        );
        if (picked == null) return;
        chosen = picked;
      }

      await openWith(chosen.id);
    }

    /// A pastor writing to a parent or a youth. They must always name someone —
    /// `open_thread()` has no default for their side, and a pastor's inbox is
    /// otherwise only reachable by waiting to be written to first.
    Future<void> composeToMember() async {
      final chosen = await showMemberPickerSheet(context);
      if (chosen == null || !context.mounted) return;
      await openWith(chosen.id);
    }

    return Scaffold(
      floatingActionButton: canStart
          ? FloatingActionButton.extended(
              onPressed: isMember ? composeToPastor : composeToMember,
              icon: const Icon(Icons.edit_outlined),
              label: Text(isMember ? 'Message' : 'New message'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(threadListProvider.notifier).refresh(),
        child: AsyncValueView(
          value: threadsState,
          onRetry: () => ref.read(threadListProvider.notifier).refresh(),
          builder: (threads) {
            if (threads.isEmpty) {
              return _EmptyInbox(isMember: isMember);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                96, // clears the FAB
              ),
              itemCount: threads.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.space2),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.space2),
                    child: MessagingDisclosure(),
                  );
                }
                return _ThreadTile(
                  thread: threads[index - 1],
                  userId: userId,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Which youth pastor to write to, when the church has more than one.
///
/// [alreadyMessaging] holds the ids the member already has a thread with. They
/// stay in the list and stay selectable — picking one is how you get back to
/// that conversation — but they are labelled, so the member can tell "start
/// something new" from "carry on where I left off" before tapping.
Future<PastorOption?> _pickPastor(
  BuildContext context,
  List<PastorOption> pastors, {
  Set<String> alreadyMessaging = const {},
}) =>
    showDialog<PastorOption>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Who would you like to message?'),
        children: [
          for (final pastor in pastors)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(pastor),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(_initial(pastor.displayName))),
                title: Text(pastor.displayName),
                subtitle: alreadyMessaging.contains(pastor.id)
                    ? const Text('Already messaging')
                    : null,
              ),
            ),
        ],
      ),
    );

class _EmptyInbox extends ConsumerWidget {
  const _EmptyInbox({required this.isMember});

  /// A parent or youth. False for the youth pastor on the other end, whose
  /// empty inbox means something quite different.
  final bool isMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The same list the compose button picks from, so the copy cannot promise
    // a pastor the picker would not offer. Null only if the read failed, and
    // the encouraging wording is the better guess there — telling a youth
    // their church has no pastor when it does is the worse mistake.
    final pastors = ref.watch(churchYouthPastorsProvider).value;

    final String message;
    if (!isMember) {
      message = 'Messages from the families in your church will appear here. '
          'You can also start one yourself.';
    } else if (pastors != null && pastors.isEmpty) {
      message = 'Your church has not set up a youth pastor yet. Once they do, '
          'you can start a private conversation here.';
    } else if (pastors != null && pastors.length > 1) {
      message = 'Start a private conversation with one of your church\'s youth '
          'pastors. Only the two of you can read it.';
    } else {
      message = 'Start a private conversation with your youth pastor. '
          'Only the two of you can read it.';
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyState(
            icon: Icons.forum_outlined,
            title: 'No messages yet',
            message: message,
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.userId});

  final MessageThread thread;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = thread.isUnreadFor(userId);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(_initial(thread.otherPartyName(userId))),
        ),
        title: Text(
          thread.otherPartyName(userId),
          style: unread
              ? theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)
              : theme.textTheme.titleMedium,
        ),
        subtitle: Text(_when(thread.lastMessageAt)),
        trailing: unread
            ? Icon(Icons.circle, size: 10, color: theme.colorScheme.primary)
            : const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.messageThreadFor(thread.id)),
      ),
    );
  }
}

String _initial(String name) =>
    name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

String _when(DateTime at) {
  final now = DateTime.now();
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  return sameDay ? DateFormat.jm().format(at) : DateFormat.yMMMd().format(at);
}
