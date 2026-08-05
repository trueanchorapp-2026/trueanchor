import 'chat_group.dart';
import 'chat_group_member.dart';
import 'chat_message.dart';

abstract interface class GroupChatRepository {
  Future<List<ChatGroup>> fetchGroups();
  Future<ChatGroup> createGroup(String name);
  Future<ChatGroup> updateGroup({required String id, required String name});
  Future<void> deleteGroup(String id);

  Future<List<ChatGroupMember>> fetchMembers(String groupId);
  Future<ChatGroupMember> addMember({
    required String groupId,
    required String profileId,
  });
  Future<void> removeMember({
    required String groupId,
    required String profileId,
  });

  Future<List<ChatMessage>> fetchMessages(String groupId);
  Future<ChatMessage> send({required String groupId, required String body});
  Future<void> deleteMessage(String id);

  Future<void> markRead(String groupId);
}
