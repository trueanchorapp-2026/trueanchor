import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../journal/application/journal_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/messaging_providers.dart';
import '../domain/message_thread.dart';
import '../domain/messaging_repository.dart';
import 'messaging_disclosure.dart';
import 'thread_page.dart';

/// The Messages tab.
///
/// Usually an inbox — a youth pastor has one thread per family member who has
/// written to them. But a member has one youth pastor and therefore one
/// conversation, and a list of exactly one row is a tap that teaches nothing:
/// they already know who they are writing to. So for that case the tab *is* the
/// conversation, the way a texting app opens on the thread rather than on a
/// directory. A church with two youth pastors gives a member two threads, and
/// then the list is the honest screen again.
class ThreadListPage extends ConsumerWidget {
  const ThreadListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsState = ref.watch(threadListProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final canStart = profile?.role.canMessagePastor ?? false;

    // Returned before the Scaffold below, which is what drops the FAB: there is
    // nothing left to start. See soloThreadProvider for when this applies.
    final solo = ref.watch(soloThreadProvider);
    if (solo != null) {
      return ThreadView(threadId: solo.id, showPartnerHeader: true);
    }

    Future<void> openWithPastor() async {
      final pastors = await ref.read(churchYouthPastorsProvider.future);
      if (!context.mounted) return;

      // A church may have more than one youth pastor; passing null would pick
      // the longest-serving, which is not the app's choice to make silently.
      final chosen = pastors.length > 1
          ? await _pickPastor(context, pastors)
          : (pastors.isEmpty ? null : pastors.first);
      if (pastors.length > 1 && chosen == null) return;

      try {
        final thread =
            await ref.read(threadListProvider.notifier).open(withId: chosen?.id);
        if (!context.mounted) return;

        // With one conversation this tab has already rebuilt into the thread
        // itself, so pushing would stack a second copy of the screen the user
        // is looking at. Only a member with two pastors still needs the push.
        if (ref.read(soloThreadProvider) == null) {
          context.push(Routes.messageThreadFor(thread.id));
        }
      } on AppException catch (error) {
        if (context.mounted) {
          showAppSnack(context, error.message, isError: true);
        }
      }
    }

    return Scaffold(
      floatingActionButton: canStart
          ? FloatingActionButton.extended(
              onPressed: openWithPastor,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Message'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(threadListProvider.notifier).refresh(),
        child: AsyncValueView(
          value: threadsState,
          onRetry: () => ref.read(threadListProvider.notifier).refresh(),
          builder: (threads) {
            if (threads.isEmpty) {
              return _EmptyInbox(canStart: canStart);
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

Future<PastorOption?> _pickPastor(
  BuildContext context,
  List<PastorOption> pastors,
) =>
    showDialog<PastorOption>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Who would you like to message?'),
        children: [
          for (final pastor in pastors)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(pastor),
              child: Text(pastor.displayName),
            ),
        ],
      ),
    );

class _EmptyInbox extends ConsumerWidget {
  const _EmptyInbox({required this.canStart});

  final bool canStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuses the check the journal editor already makes: telling a youth to
    // message a pastor their church has not appointed is worse than saying so.
    final hasPastor = ref.watch(churchHasYouthPastorProvider).value ?? true;

    final String message;
    if (!canStart) {
      message = 'Messages from the families in your church will appear here.';
    } else if (!hasPastor) {
      message = 'Your church has not set up a youth pastor yet. Once they do, '
          'you can start a private conversation here.';
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
