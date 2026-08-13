import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/chat_group.dart';
import '../domain/chat_group_member.dart';
import '../domain/chat_message.dart';
import '../domain/group_chat_repository.dart';

class SupabaseGroupChatRepository implements GroupChatRepository {
  const SupabaseGroupChatRepository(this._client);

  final SupabaseClient _client;

  static const _memberColumns =
      '*, profile:profiles!profile_id(first_name, last_name)';

  static const _messageColumns =
      '*, sender:profiles!sender_id(first_name, last_name)';

  // ---- Groups ----

  @override
  Future<List<ChatGroup>> fetchGroups() async {
    try {
      final userId = _client.auth.currentUser!.id;
      final rows = await _client
          .from('chat_groups')
          .select(
            '*, chat_group_members!inner(last_read_at), '
            'chat_messages(created_at)',
          )
          .eq('chat_group_members.profile_id', userId)
          .order('created_at', ascending: false,
              referencedTable: 'chat_messages')
          .limit(1, referencedTable: 'chat_messages')
          .order('created_at', ascending: false);
      return rows.map(ChatGroup.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<ChatGroup> createGroup(String name) async {
    try {
      final row = await _client
          .rpc<Map<String, dynamic>>('create_chat_group',
              params: {'p_name': name});
      return ChatGroup.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<ChatGroup> updateGroup({
    required String id,
    required String name,
  }) async {
    try {
      final row = await _client
          .from('chat_groups')
          .update({'name': name.trim()})
          .eq('id', id)
          .select()
          .single();
      return ChatGroup.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> deleteGroup(String id) async {
    try {
      await _client.from('chat_groups').delete().eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }

  // ---- Members ----

  @override
  Future<List<ChatGroupMember>> fetchMembers(String groupId) async {
    try {
      final rows = await _client
          .from('chat_group_members')
          .select(_memberColumns)
          .eq('group_id', groupId)
          .order('joined_at');
      return rows.map(ChatGroupMember.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<ChatGroupMember> addMember({
    required String groupId,
    required String profileId,
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
          'add_chat_group_member',
          params: {'p_group_id': groupId, 'p_profile_id': profileId});
      return ChatGroupMember.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String profileId,
  }) async {
    try {
      await _client.rpc('remove_chat_group_member',
          params: {'p_group_id': groupId, 'p_profile_id': profileId});
    } catch (error) {
      throw mapError(error);
    }
  }

  // ---- Messages ----

  @override
  Future<List<ChatMessage>> fetchMessages(String groupId) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select(_messageColumns)
          .eq('group_id', groupId)
          .order('created_at', ascending: true);
      return rows.map(ChatMessage.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<ChatMessage> send({
    required String groupId,
    required String body,
  }) async {
    try {
      final senderId = _client.auth.currentUser!.id;
      final row = await _client
          .from('chat_messages')
          .insert(ChatMessage.toInsertJson(
            groupId: groupId,
            senderId: senderId,
            body: body,
          ))
          .select(_messageColumns)
          .single();
      return ChatMessage.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> deleteMessage(String id) async {
    try {
      await _client.from('chat_messages').delete().eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> markRead(String groupId) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client
          .from('chat_group_members')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('group_id', groupId)
          .eq('profile_id', userId);
    } catch (error) {
      throw mapError(error);
    }
  }
}
