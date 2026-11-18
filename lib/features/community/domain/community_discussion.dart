import 'discussion_image.dart';
import 'topic_tag.dart';
import 'vote.dart';

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
    this.lastActivityAt,
    this.imageUrls = const [],
    this.tagIds = const [],
    this.votes = const VoteTally(),
  });

  factory CommunityDiscussion.fromJson(Map<String, dynamic> json) =>
      CommunityDiscussion(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        authorId: json['author_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        // The search RPC returns the author's name flat, not embedded.
        authorName: _authorNameFrom(json['author'] ??
            {
              'first_name': json['author_first_name'],
              'last_name': json['author_last_name'],
            }),
        replyCount: json['reply_count'] as int?,
        lastActivityAt:
            DateTime.tryParse(json['last_activity_at'] as String? ?? '')
                ?.toLocal(),
        imageUrls: DiscussionImages.urlsFromJson(json['image_urls']),
        tagIds: TopicTag.idsFromJson(json['tag_ids'] ?? json['tags']),
        votes: VoteTally.fromJson(json),
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
  final DateTime? lastActivityAt;
  final List<String> imageUrls;
  final List<String> tagIds;
  final VoteTally votes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isAuthoredBy(String userId) => authorId == userId;

  CommunityDiscussion copyWith({
    List<String>? tagIds,
    int? replyCount,
    DateTime? lastActivityAt,
    VoteTally? votes,
  }) =>
      CommunityDiscussion(
        id: id,
        communityId: communityId,
        authorId: authorId,
        title: title,
        body: body,
        createdAt: createdAt,
        updatedAt: updatedAt,
        authorName: authorName,
        replyCount: replyCount ?? this.replyCount,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
        imageUrls: imageUrls,
        tagIds: tagIds ?? this.tagIds,
        votes: votes ?? this.votes,
      );

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
    List<String> imageUrls = const [],
  }) =>
      {
        'community_id': communityId,
        'author_id': authorId,
        'title': title.trim(),
        'body': body.trim(),
        'image_urls': imageUrls,
      };

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
    this.imageUrls = const [],
    this.helpfulCount = 0,
    this.markedHelpfulByMe = false,
  });

  factory DiscussionReply.fromJson(Map<String, dynamic> json) {
    // `my_votes` is an embed of community_reply_votes; RLS limits it to the
    // caller's own row, so non-empty means "I marked this helpful".
    final mine = json['my_votes'];
    return DiscussionReply(
      id: json['id'] as String,
      discussionId: json['discussion_id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String,
      authorName: _authorNameFrom(json['author']),
      imageUrls: DiscussionImages.urlsFromJson(json['image_urls']),
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      markedHelpfulByMe: mine is List && mine.isNotEmpty,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }

  final String id;
  final String discussionId;
  final String authorId;
  final String body;
  final String? authorName;
  final List<String> imageUrls;
  final int helpfulCount;
  final bool markedHelpfulByMe;
  final DateTime createdAt;

  bool isAuthoredBy(String userId) => authorId == userId;

  DiscussionReply copyWith({int? helpfulCount, bool? markedHelpfulByMe}) =>
      DiscussionReply(
        id: id,
        discussionId: discussionId,
        authorId: authorId,
        body: body,
        createdAt: createdAt,
        authorName: authorName,
        imageUrls: imageUrls,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        markedHelpfulByMe: markedHelpfulByMe ?? this.markedHelpfulByMe,
      );

  /// The reply after the user toggles "helpful" (optimistic update).
  DiscussionReply toggledHelpful() {
    final on = !markedHelpfulByMe;
    final count = helpfulCount + (on ? 1 : -1);
    return copyWith(
      markedHelpfulByMe: on,
      helpfulCount: count < 0 ? 0 : count,
    );
  }

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
    List<String> imageUrls = const [],
  }) =>
      {
        'discussion_id': discussionId,
        'author_id': authorId,
        'body': body.trim(),
        'image_urls': imageUrls,
      };
}
