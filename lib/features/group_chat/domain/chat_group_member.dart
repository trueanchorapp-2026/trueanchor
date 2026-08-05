class ChatGroupMember {
  const ChatGroupMember({
    required this.id,
    required this.groupId,
    required this.profileId,
    required this.joinedAt,
    this.lastReadAt,
    this.memberName,
  });

  factory ChatGroupMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    return ChatGroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      profileId: json['profile_id'] as String,
      lastReadAt:
          DateTime.tryParse(json['last_read_at'] as String? ?? '')?.toLocal(),
      joinedAt:
          DateTime.tryParse(json['joined_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      memberName: profile is Map<String, dynamic> ? _nameOf(profile) : null,
    );
  }

  final String id;
  final String groupId;
  final String profileId;
  final DateTime? lastReadAt;
  final DateTime joinedAt;
  final String? memberName;
}

String? _nameOf(Map<String, dynamic> profile) {
  final name = [
    profile['first_name'] as String? ?? '',
    profile['last_name'] as String? ?? '',
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();
  return name.isEmpty ? null : name;
}
