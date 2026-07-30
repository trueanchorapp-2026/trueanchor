/// A row of `public.message_threads`: one private conversation between a
/// member (a parent or a youth) and their youth pastor.
class MessageThread {
  const MessageThread({
    required this.id,
    required this.memberId,
    required this.pastorId,
    required this.lastMessageAt,
    this.memberLastReadAt,
    this.pastorLastReadAt,
    this.memberName,
    this.pastorName,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    final member = json['member'];
    final pastor = json['pastor'];
    return MessageThread(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      pastorId: json['pastor_id'] as String,
      lastMessageAt: _parseTime(json['last_message_at']) ?? DateTime.now(),
      memberLastReadAt: _parseTime(json['member_last_read_at']),
      pastorLastReadAt: _parseTime(json['pastor_last_read_at']),
      memberName: member is Map<String, dynamic> ? _nameOf(member) : null,
      pastorName: pastor is Map<String, dynamic> ? _nameOf(pastor) : null,
    );
  }

  final String id;
  final String memberId;
  final String pastorId;
  final DateTime lastMessageAt;

  /// Each participant's own read receipt. Only ever written by that
  /// participant — `private.guard_thread_columns()` reverts the other.
  final DateTime? memberLastReadAt;
  final DateTime? pastorLastReadAt;

  /// Names joined in for the inbox. Readable because of
  /// `profiles_select_thread_partner`, which exposes exactly the people you
  /// are already in a conversation with.
  final String? memberName;
  final String? pastorName;

  bool isMember(String? userId) => userId != null && memberId == userId;

  /// The person on the other end, from the caller's point of view. Falls back
  /// to a role word rather than an empty string: a nameless row in the inbox
  /// looks like a bug, and a member genuinely may not have a name to show if
  /// the join was omitted.
  String otherPartyName(String? userId) {
    final name = isMember(userId) ? pastorName : memberName;
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return isMember(userId) ? 'Youth pastor' : 'Church member';
  }

  /// Whether there is something new for this caller.
  ///
  /// Picking the right read column is the whole subtlety, which is why it
  /// lives here rather than in a widget: reading the wrong one shows an unread
  /// badge for a message you sent yourself.
  bool isUnreadFor(String? userId) {
    if (userId == null) return false;
    final readAt = isMember(userId) ? memberLastReadAt : pastorLastReadAt;
    if (readAt == null) return true;
    return lastMessageAt.isAfter(readAt);
  }

  /// The read-receipt column this caller owns. Null when they are neither
  /// participant, which RLS would have refused anyway.
  String? readColumnFor(String? userId) {
    if (userId == null) return null;
    if (memberId == userId) return 'member_last_read_at';
    if (pastorId == userId) return 'pastor_last_read_at';
    return null;
  }

  MessageThread copyWith({DateTime? lastMessageAt}) => MessageThread(
        id: id,
        memberId: memberId,
        pastorId: pastorId,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        memberLastReadAt: memberLastReadAt,
        pastorLastReadAt: pastorLastReadAt,
        memberName: memberName,
        pastorName: pastorName,
      );
}

DateTime? _parseTime(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal();

String? _nameOf(Map<String, dynamic> profile) {
  final name = [
    profile['first_name'] as String? ?? '',
    profile['last_name'] as String? ?? '',
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();
  return name.isEmpty ? null : name;
}
