import 'package:flutter/foundation.dart';

import 'feed_query.dart';
import 'topic_tag.dart';
import 'vote.dart';

/// The two kinds of read-only, admin-authored community posts.
enum PublishedKind {
  news('news', 'News', VoteTarget.news, FeedSort.newsSorts),
  resource('resource', 'Resource', VoteTarget.resource, FeedSort.resourceSorts);

  const PublishedKind(this.wireValue, this.label, this.voteTarget, this.sorts);

  /// `p_kind` for `set_post_tags`.
  final String wireValue;
  final String label;
  final VoteTarget voteTarget;

  /// Sort options offered for this feed.
  final List<FeedSort> sorts;

  /// News must have a body; a resource may be just a titled link.
  bool get requiresBody => this == PublishedKind.news;
}

/// A community News post or Parent Hub resource: title, body, optional link,
/// up to [TopicTag.maxPerPost] tags, and votes.
@immutable
class PublishedPost {
  const PublishedPost({
    required this.id,
    required this.kind,
    required this.communityId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.authorId,
    this.authorName,
    this.linkUrl,
    this.tagIds = const [],
    this.votes = const VoteTally(),
  });

  /// Reads a search-RPC row (flat author names, `tag_ids`, `my_vote`) or a
  /// table row with PostgREST embeds (`author`, `tags`, `my_votes`).
  factory PublishedPost.fromJson(PublishedKind kind, Map<String, dynamic> json) =>
      PublishedPost(
        id: json['id'] as String,
        kind: kind,
        communityId: json['community_id'] as String,
        authorId: json['author_id'] as String?,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        linkUrl: _nonEmpty(json['link_url'] as String?),
        authorName: _authorNameFrom(json['author'] ??
            {
              'first_name': json['author_first_name'],
              'last_name': json['author_last_name'],
            }),
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
  final PublishedKind kind;
  final String communityId;
  final String? authorId;
  final String title;
  final String body;
  final String? linkUrl;
  final String? authorName;
  final List<String> tagIds;
  final VoteTally votes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isAuthoredBy(String userId) => authorId == userId;

  PublishedPost copyWith({List<String>? tagIds, VoteTally? votes}) =>
      PublishedPost(
        id: id,
        kind: kind,
        communityId: communityId,
        title: title,
        body: body,
        createdAt: createdAt,
        updatedAt: updatedAt,
        authorId: authorId,
        authorName: authorName,
        linkUrl: linkUrl,
        tagIds: tagIds ?? this.tagIds,
        votes: votes ?? this.votes,
      );

  /// Trims a typed link and adds `https://` when no scheme was given.
  /// Empty input means "no link".
  static String? normalizeLink(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value);
    return hasScheme ? value : 'https://$value';
  }

  /// Whether [raw] (after [normalizeLink]) is a usable web link. Empty is
  /// valid — the link is optional.
  static bool isValidLink(String? raw) {
    final link = normalizeLink(raw);
    if (link == null) return true;
    if (RegExp(r'\s').hasMatch(link)) return false;
    final uri = Uri.tryParse(link);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
  }

  static Map<String, dynamic> toWriteJson({
    required String title,
    required String body,
    String? linkUrl,
  }) =>
      {
        'title': title.trim(),
        'body': body.trim(),
        'link_url': normalizeLink(linkUrl),
      };

  static String? _nonEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  static String? _authorNameFrom(Object? embedded) {
    if (embedded is! Map) return null;
    final parts = [embedded['first_name'], embedded['last_name']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}
