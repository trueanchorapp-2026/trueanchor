import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/group_chat_providers.dart';
import '../domain/chat_message.dart';

class GroupChatPage extends ConsumerStatefulWidget {
  const GroupChatPage({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
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

  void _markReadOnce() {
    if (_markedRead) return;
    _markedRead = true;
    ref.read(groupChatRepositoryProvider).markRead(widget.groupId);
    ref.read(chatGroupListProvider.notifier).bumpRead(widget.groupId);
  }

  void _openAtNewestOnce(List<ChatMessage> messages) {
    if (_openedAtNewest || messages.isEmpty) return;
    _openedAtNewest = true;
    _scrollToEnd();
  }

  void _scrollToEnd({int passes = 3}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (_scroll.offset < end) _scroll.jumpTo(end);
      if (passes > 1) _scrollToEnd(passes: passes - 1);
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(groupMessagesProvider(widget.groupId).notifier)
          .send(body);
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

  Future<void> _delete(ChatMessage message) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this message?',
      message:
          'It will be removed for everyone. After five minutes a message can '
          'no longer be deleted.',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(groupMessagesProvider(widget.groupId).notifier)
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
    final messagesState = ref.watch(groupMessagesProvider(widget.groupId));

    final groups = ref.watch(chatGroupListProvider).value ?? const [];
    final group = groups
        .where((g) => g.id == widget.groupId)
        .firstOrNull;

    _markReadOnce();

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Group'),
        actions: [
          if (group != null && group.isCreatedBy(userId))
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Manage group',
              onPressed: () =>
                  context.push(Routes.groupManageFor(widget.groupId)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView(
              value: messagesState,
              onRetry: () =>
                  ref.invalidate(groupMessagesProvider(widget.groupId)),
              builder: (messages) {
                if (messages.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Nothing here yet',
                    message: 'Say hello to the group.',
                  );
                }
                _openAtNewestOnce(messages);
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space4,
                    AppTheme.space3,
                    AppTheme.space4,
                    AppTheme.space4,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _GroupBubble(
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
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  const _GroupBubble({
    required this.message,
    required this.userId,
    required this.onDelete,
  });

  final ChatMessage message;
  final String? userId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.isSentBy(userId);
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
              if (!mine && message.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    message.senderName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
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
