const chatMessageDeleteWindow = Duration(minutes: 5);

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.senderName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return ChatMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      senderName: sender is Map<String, dynamic> ? _nameOf(sender) : null,
    );
  }

  final String id;
  final String groupId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? senderName;

  bool isSentBy(String? userId) => userId != null && senderId == userId;

  bool canDeleteAt(DateTime now, {String? userId}) =>
      isSentBy(userId) && now.difference(createdAt) < chatMessageDeleteWindow;

  static Map<String, dynamic> toInsertJson({
    required String groupId,
    required String senderId,
    required String body,
  }) =>
      {
        'group_id': groupId,
        'sender_id': senderId,
        'body': body.trim(),
      };
}

String? _nameOf(Map<String, dynamic> sender) {
  final name = [
    sender['first_name'] as String? ?? '',
    sender['last_name'] as String? ?? '',
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();
  return name.isEmpty ? null : name;
}
