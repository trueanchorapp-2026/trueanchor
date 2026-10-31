class CommunityDiscussion {
  const CommunityDiscussion({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.replyCount,
    this.imageUrl,
  });

  factory CommunityDiscussion.fromJson(Map<String, dynamic> json) =>
      CommunityDiscussion(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        authorId: json['author_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        authorName: _authorNameFrom(json['author']),
        replyCount: json['reply_count'] as int?,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String communityId;
  final String authorId;
  final String title;
  final String body;
  final String? authorName;
  final int? replyCount;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isAuthoredBy(String userId) => authorId == userId;

  static String? _authorNameFrom(Object? embedded) {
    if (embedded is! Map) return null;
    final parts = [embedded['first_name'], embedded['last_name']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  static Map<String, dynamic> toInsertJson({
    required String communityId,
    required String authorId,
    required String title,
    required String body,
    String? imageUrl,
  }) =>
      {
        'community_id': communityId,
        'author_id': authorId,
        'title': title.trim(),
        'body': body.trim(),
        'image_url': ?imageUrl,
      };

  /// Image types the `discussion-images` bucket accepts (see 0028).
  static const imageContentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
  };

  /// The content type to upload [fileName] as. Unknown extensions fall back
  /// to JPEG, which is what the picker re-encodes to when it compresses.
  static String imageContentTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final extension =
        dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    return imageContentTypes[extension] ?? 'image/jpeg';
  }

  /// [fileName] reduced to characters that are safe in a storage path.
  static String safeImageFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'image' : cleaned;
  }

  static Map<String, dynamic> toUpdateJson({
    required String title,
    required String body,
  }) =>
      {
        'title': title.trim(),
        'body': body.trim(),
      };
}

class DiscussionReply {
  const DiscussionReply({
    required this.id,
    required this.discussionId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorName,
  });

  factory DiscussionReply.fromJson(Map<String, dynamic> json) =>
      DiscussionReply(
        id: json['id'] as String,
        discussionId: json['discussion_id'] as String,
        authorId: json['author_id'] as String,
        body: json['body'] as String,
        authorName: _authorNameFrom(json['author']),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String discussionId;
  final String authorId;
  final String body;
  final String? authorName;
  final DateTime createdAt;

  bool isAuthoredBy(String userId) => authorId == userId;

  static String? _authorNameFrom(Object? embedded) {
    if (embedded is! Map) return null;
    final parts = [embedded['first_name'], embedded['last_name']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  static Map<String, dynamic> toInsertJson({
    required String discussionId,
    required String authorId,
    required String body,
  }) =>
      {
        'discussion_id': discussionId,
        'author_id': authorId,
        'body': body.trim(),
      };
}
