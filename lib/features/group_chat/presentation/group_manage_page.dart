import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/domain/profile.dart';
import '../application/group_chat_providers.dart';
import '../domain/chat_group_member.dart';

class GroupManagePage extends ConsumerStatefulWidget {
  const GroupManagePage({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends ConsumerState<GroupManagePage> {
  final _nameController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _hydrate(String name) {
    if (_nameController.text.isEmpty) {
      _nameController.text = name;
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(groupChatRepositoryProvider)
          .updateGroup(id: widget.groupId, name: name);
      ref.invalidate(chatGroupListProvider);
      if (mounted) showAppSnack(context, 'Group renamed');
    } on Object catch (error) {
      setState(() => _error = mapError(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addMember() async {
    final youth = await ref.read(addableYouthProvider.future);
    if (!mounted) return;

    final members =
        ref.read(groupMembersProvider(widget.groupId)).value ?? const [];
    final memberIds = {for (final m in members) m.profileId};
    final available = youth.where((p) => !memberIds.contains(p.id)).toList();

    if (available.isEmpty) {
      showAppSnack(context, 'All youth in your church are already in this group');
      return;
    }

    final picked = await _pickYouth(context, available);
    if (picked == null || !mounted) return;

    try {
      await ref.read(groupChatRepositoryProvider).addMember(
            groupId: widget.groupId,
            profileId: picked.id,
          );
      ref.invalidate(groupMembersProvider(widget.groupId));
      if (mounted) showAppSnack(context, '${picked.fullName} added');
    } on Object catch (error) {
      if (mounted) {
        showAppSnack(context, mapError(error).message, isError: true);
      }
    }
  }

  Future<void> _removeMember(ChatGroupMember member) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove ${member.memberName ?? 'this member'}?',
      message: 'They will no longer see messages in this group.',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(groupChatRepositoryProvider).removeMember(
            groupId: widget.groupId,
            profileId: member.profileId,
          );
      ref.invalidate(groupMembersProvider(widget.groupId));
      if (mounted) showAppSnack(context, 'Member removed');
    } on Object catch (error) {
      if (mounted) {
        showAppSnack(context, mapError(error).message, isError: true);
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this group?',
      message: 'All messages will be permanently deleted.',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(chatGroupListProvider.notifier).remove(widget.groupId);
      if (mounted) {
        context.pop();
        context.pop();
      }
    } on Object catch (error) {
      if (mounted) {
        showAppSnack(context, mapError(error).message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final membersState = ref.watch(groupMembersProvider(widget.groupId));

    final groups = ref.watch(chatGroupListProvider).value ?? const [];
    final group =
        groups.where((g) => g.id == widget.groupId).firstOrNull;

    if (group != null) _hydrate(group.name);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage group')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space4),
        children: [
          if (_error != null) ...[
            NoticeBanner(message: _error!, icon: Icons.error_outline),
            const SizedBox(height: AppTheme.space3),
          ],
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Group name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          FilledButton(
            onPressed: _saving ? null : _saveName,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save name'),
          ),
          const SizedBox(height: AppTheme.space5),
          Row(
            children: [
              Expanded(
                child: Text('Members', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _addMember,
                icon: const Icon(Icons.person_add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space2),
          membersState.when(
            data: (members) {
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.space4),
                  child: Text('No members yet.'),
                );
              }
              return Column(
                children: [
                  for (final member in members)
                    _MemberTile(
                      member: member,
                      isCreator: group?.isCreatedBy(member.profileId) ?? false,
                      onRemove: () => _removeMember(member),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Failed to load members: $error'),
          ),
          const SizedBox(height: AppTheme.space5),
          OutlinedButton.icon(
            onPressed: _deleteGroup,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete group'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCreator,
    required this.onRemove,
  });

  final ChatGroupMember member;
  final bool isCreator;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = member.memberName ?? 'Unknown';
    return ListTile(
      leading: CircleAvatar(
        child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()),
      ),
      title: Text(name),
      subtitle: isCreator ? const Text('Creator') : null,
      trailing: isCreator
          ? null
          : IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
    );
  }
}

Future<Profile?> _pickYouth(BuildContext context, List<Profile> youth) {
  return showModalBottomSheet<Profile>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: youth.length,
        itemBuilder: (context, index) {
          final person = youth[index];
          return ListTile(
            leading: CircleAvatar(child: Text(person.initials)),
            title: Text(person.fullName),
            subtitle: person.grade != null ? Text('Grade ${person.grade}') : null,
            onTap: () => Navigator.of(context).pop(person),
          );
        },
      ),
    ),
  );
}
