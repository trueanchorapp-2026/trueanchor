class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.churchId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      churchId: json['church_id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  final String id;
  final String churchId;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  String get displayName =>
      name.trim().isEmpty ? 'Group chat' : name.trim();

  bool isCreatedBy(String? userId) => userId != null && createdBy == userId;
}
