import 'package:flutter/foundation.dart';

enum FeedSort {
  newest('Newest', 'newest'),
  recentActivity('Recent activity', 'activity'),
  mostReplies('Most replies', 'replies'),
  top('Top', 'top'),
  oldest('Oldest', 'oldest'),
  title('A–Z', 'title');

  const FeedSort(this.label, this.wireValue);

  final String label;

  /// The `p_sort` value understood by the search RPCs.
  final String wireValue;

  static const discussionSorts = [
    newest,
    recentActivity,
    mostReplies,
    top,
    oldest,
  ];
  static const newsSorts = [newest, top, oldest];
  static const resourceSorts = [newest, top, oldest, title];
}

/// What a community feed (discussions, news, Parent Hub) is filtered and
/// sorted by.
@immutable
class FeedQuery {
  const FeedQuery({
    this.tagIds = const {},
    this.text = '',
    this.sort = FeedSort.newest,
  });

  /// Matches posts carrying ANY of these tags; empty means all.
  final Set<String> tagIds;
  final String text;
  final FeedSort sort;

  /// True when the list is narrowed (tags or text); sort alone isn't a filter.
  bool get isFiltered => tagIds.isNotEmpty || text.trim().isNotEmpty;

  /// Whether a just-created post belongs at the top of the current list
  /// (otherwise the server decides where it goes).
  bool get newPostGoesFirst =>
      !isFiltered &&
      (sort == FeedSort.newest || sort == FeedSort.recentActivity);

  FeedQuery copyWith({
    Set<String>? tagIds,
    String? text,
    FeedSort? sort,
  }) =>
      FeedQuery(
        tagIds: tagIds ?? this.tagIds,
        text: text ?? this.text,
        sort: sort ?? this.sort,
      );

  FeedQuery toggleTag(String tagId) => copyWith(
        tagIds: tagIds.contains(tagId)
            ? ({...tagIds}..remove(tagId))
            : {...tagIds, tagId},
      );

  /// Clears tags and text but keeps the chosen sort.
  FeedQuery cleared() => FeedQuery(sort: sort);

  Map<String, dynamic> toRpcParams(String communityId) {
    final trimmed = text.trim();
    return {
      'p_community_id': communityId,
      'p_tag_ids': tagIds.isEmpty ? null : (tagIds.toList()..sort()),
      'p_query': trimmed.isEmpty ? null : trimmed,
      'p_sort': sort.wireValue,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FeedQuery &&
      setEquals(other.tagIds, tagIds) &&
      other.text == text &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(tagIds), text, sort);
}
