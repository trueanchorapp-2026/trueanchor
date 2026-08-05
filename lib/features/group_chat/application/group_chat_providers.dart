import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import '../domain/chat_group.dart';
import '../domain/chat_message.dart';
import '../domain/group_chat_repository.dart';
import '../infrastructure/supabase_group_chat_repository.dart';

final groupChatRepositoryProvider = Provider<GroupChatRepository>(
  (ref) => SupabaseGroupChatRepository(ref.watch(supabaseClientProvider)),
);

class ChatGroupList extends AsyncNotifier<List<ChatGroup>> {
  @override
  Future<List<ChatGroup>> build() async {
    ref.watch(currentUserIdProvider);
    final profile = await ref.watch(currentProfileProvider.future);
    if (profile == null || !profile.role.canUseMessaging) return const [];
    return ref.watch(groupChatRepositoryProvider).fetchGroups();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(groupChatRepositoryProvider).fetchGroups(),
    );
  }

  Future<ChatGroup> create(String name) async {
    final created =
        await ref.read(groupChatRepositoryProvider).createGroup(name);
    final current = state.value ?? const <ChatGroup>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> remove(String id) async {
    await ref.read(groupChatRepositoryProvider).deleteGroup(id);
    final current = state.value ?? const <ChatGroup>[];
    state = AsyncData(current.where((g) => g.id != id).toList());
  }
}

final chatGroupListProvider =
    AsyncNotifierProvider<ChatGroupList, List<ChatGroup>>(ChatGroupList.new);

class GroupMessages extends AsyncNotifier<List<ChatMessage>> {
  GroupMessages(this.groupId);

  final String groupId;

  @override
  Future<List<ChatMessage>> build() {
    ref.watch(currentUserIdProvider);
    return ref
        .watch(groupChatRepositoryProvider)
        .fetchMessages(groupId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () =>
          ref.read(groupChatRepositoryProvider).fetchMessages(groupId),
    );
  }

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final sent = await ref
        .read(groupChatRepositoryProvider)
        .send(groupId: groupId, body: trimmed);
    final current = state.value ?? const <ChatMessage>[];
    state = AsyncData([...current, sent]);
  }

  Future<void> remove(String messageId) async {
    await ref.read(groupChatRepositoryProvider).deleteMessage(messageId);
    state = await AsyncValue.guard(
      () =>
          ref.read(groupChatRepositoryProvider).fetchMessages(groupId),
    );
  }
}

final groupMessagesProvider =
    AsyncNotifierProvider.family<GroupMessages, List<ChatMessage>, String>(
  GroupMessages.new,
);

final groupMembersProvider =
    FutureProvider.family<List<dynamic>, String>((ref, groupId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(groupChatRepositoryProvider).fetchMembers(groupId);
});

final addableYouthProvider = FutureProvider<List<Profile>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.role.canCreateGroupChat) return const [];
  final people = await ref.watch(profileRepositoryProvider).fetchChurchMembers(
        profile.churchId!,
      );
  return people.where((p) => p.role == UserRole.youth).toList();
});
