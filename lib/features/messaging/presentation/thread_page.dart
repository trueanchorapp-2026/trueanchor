import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/messaging_providers.dart';
import '../domain/message.dart';
import '../domain/message_thread.dart';
import 'messaging_disclosure.dart';

/// One conversation, reached from a list. A top-level route rather than a shell
/// child: a thread you navigated *into* is a place you come back from, and the
/// nav bar would invite you to leave it mid-reply.
///
/// The name of the other party is the whole header — there is no subject line,
/// because a private conversation with one person does not need one.
class ThreadPage extends ConsumerWidget {
  const ThreadPage({required this.threadId, super.key});

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final thread = ref
        .watch(threadListProvider)
        .value
        ?.where((candidate) => candidate.id == threadId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(thread?.otherPartyName(userId) ?? 'Conversation'),
      ),
      // The AppBar already names the other party, so the header would repeat it.
      body: ThreadView(threadId: threadId, showPartnerHeader: false),
    );
  }
}

/// The conversation itself: disclosure, bubbles, composer.
///
/// Deliberately Scaffold-less so it can serve twice. A youth pastor reaches it
/// by pushing [ThreadPage] off their inbox; a member with a single conversation
/// gets it rendered straight into the Messages tab, with no list in between.
/// [showPartnerHeader] is what covers the difference — inside the shell the
/// AppBar says "Messages", so the name has to come from the body.
class ThreadView extends ConsumerStatefulWidget {
  const ThreadView({
    required this.threadId,
    required this.showPartnerHeader,
    super.key,
  });

  final String threadId;
  final bool showPartnerHeader;

  @override
  ConsumerState<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends ConsumerState<ThreadView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _markedRead = false;
  bool _openedAtNewest = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Stamps the read receipt once the thread is on screen and its row is known.
  /// Guarded by [_markedRead] because the provider rebuilds on every send.
  void _markReadOnce(MessageThread? thread) {
    if (_markedRead || thread == null) return;
    final userId = ref.read(currentUserIdProvider);
    if (!thread.isUnreadFor(userId)) return;
    _markedRead = true;
    ref.read(threadListProvider.notifier).markRead(thread);
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(threadMessagesProvider(widget.threadId).notifier).send(body);
      // Only cleared on success: a failed send must leave the words the user
      // typed in the box, not lose them.
      _controller.clear();
      _scrollToEnd();
    } on Object catch (error) {
      if (mounted) {
        showAppSnack(context, mapError(error).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Opens the conversation on the newest message rather than the oldest.
  ///
  /// Messages run oldest-first, so an untouched list starts at the beginning of
  /// the transcript — which, for the person who just received something, is the
  /// wrong end of it. Guarded like [_markReadOnce] because the provider rebuilds
  /// on every send, and after the first frame the scroll position is the user's.
  void _openAtNewestOnce(List<Message> messages) {
    if (_openedAtNewest || messages.isEmpty) return;
    _openedAtNewest = true;
    _scrollToEnd();
  }

  /// Jumps to the bottom, over several frames.
  ///
  /// [ListView.builder] only *estimates* `maxScrollExtent` for items it has not
  /// laid out, so on a long thread a single jump lands short of the end and then
  /// stops. Each pass re-reads the extent once the previous jump has been laid
  /// out; it settles quickly and is a no-op once there is nowhere left to go.
  void _scrollToEnd({int passes = 3}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (_scroll.offset < end) _scroll.jumpTo(end);
      if (passes > 1) _scrollToEnd(passes: passes - 1);
    });
  }

  Future<void> _delete(Message message) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this message?',
      message: 'It will be removed for both of you. After five minutes a '
          'message can no longer be deleted.',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(threadMessagesProvider(widget.threadId).notifier)
          .remove(message.id);
    } on Object catch (error) {
      if (mounted) {
        showAppSnack(context, mapError(error).message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final messagesState = ref.watch(threadMessagesProvider(widget.threadId));

    final threads = ref.watch(threadListProvider).value ?? const [];
    final thread = threads
        .where((candidate) => candidate.id == widget.threadId)
        .firstOrNull;
    _markReadOnce(thread);

    return Column(
      children: [
        if (widget.showPartnerHeader && thread != null)
          _PartnerHeader(name: thread.otherPartyName(userId)),
        const Padding(
          padding: EdgeInsets.all(AppTheme.space3),
          child: MessagingDisclosure(),
        ),
        Expanded(
          child: AsyncValueView(
            value: messagesState,
            onRetry: () =>
                ref.invalidate(threadMessagesProvider(widget.threadId)),
            builder: (messages) {
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Nothing here yet',
                  message: 'Say hello. Only the two of you can read this.',
                );
              }
              _openAtNewestOnce(messages);
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space4,
                  0,
                  AppTheme.space4,
                  AppTheme.space4,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) => _Bubble(
                  message: messages[index],
                  userId: userId,
                  onDelete: () => _delete(messages[index]),
                ),
              );
            },
          ),
        ),
        _Composer(
          controller: _controller,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }
}

/// Who you are writing to, for when the AppBar above is naming the tab instead.
class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space3,
        AppTheme.space4,
        0,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Text(name, style: theme.textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.userId,
    required this.onDelete,
  });

  final Message message;
  final String? userId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.isSentBy(userId);
    // Recomputed on every build rather than on a timer: the window closing is
    // not worth a rebuild, and the database refuses a late delete anyway.
    final deletable = message.canDeleteAt(DateTime.now(), userId: userId);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: deletable ? onDelete : null,
        child: Container(
          margin: const EdgeInsets.only(top: AppTheme.space2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space3,
            vertical: AppTheme.space2,
          ),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: mine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mine
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jm().format(message.createdAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (deletable) ...[
                    const SizedBox(width: AppTheme.space2),
                    InkWell(
                      onTap: onDelete,
                      child: Text(
                        'Delete',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}
