class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.churchId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.lastMessageAt,
    this.myLastReadAt,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    final members = json['chat_group_members'];
    final messages = json['chat_messages'];

    DateTime? myLastReadAt;
    if (members is List && members.isNotEmpty) {
      final row = members.first as Map<String, dynamic>;
      myLastReadAt =
          DateTime.tryParse(row['last_read_at'] as String? ?? '')?.toLocal();
    }

    DateTime? lastMessageAt;
    if (messages is List && messages.isNotEmpty) {
      final row = messages.first as Map<String, dynamic>;
      lastMessageAt =
          DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal();
    }

    return ChatGroup(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      lastMessageAt: lastMessageAt,
      myLastReadAt: myLastReadAt,
    );
  }

  final String id;
  final String churchId;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final DateTime? myLastReadAt;

  bool get isUnread =>
      lastMessageAt != null &&
      (myLastReadAt == null || lastMessageAt!.isAfter(myLastReadAt!));

  String get displayName =>
      name.trim().isEmpty ? 'Group chat' : name.trim();

  bool isCreatedBy(String? userId) => userId != null && createdBy == userId;

  ChatGroup withReadAt(DateTime at) => ChatGroup(
        id: id,
        churchId: churchId,
        name: name,
        createdBy: createdBy,
        createdAt: createdAt,
        lastMessageAt: lastMessageAt,
        myLastReadAt: at,
      );

  ChatGroup withSentMessage(DateTime at) => ChatGroup(
        id: id,
        churchId: churchId,
        name: name,
        createdBy: createdBy,
        createdAt: createdAt,
        lastMessageAt: at,
        myLastReadAt: at,
      );
}
