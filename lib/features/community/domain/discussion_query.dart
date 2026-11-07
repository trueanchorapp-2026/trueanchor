import 'package:flutter/foundation.dart';

enum DiscussionSort {
  newest('Newest', 'newest'),
  recentActivity('Recent activity', 'activity'),
  mostReplies('Most replies', 'replies'),
  oldest('Oldest', 'oldest');

  const DiscussionSort(this.label, this.wireValue);

  final String label;

  /// The `p_sort` value understood by `search_community_discussions`.
  final String wireValue;
}

/// What the discussions list is currently filtered and sorted by.
@immutable
class DiscussionQuery {
  const DiscussionQuery({
    this.tagIds = const {},
    this.text = '',
    this.sort = DiscussionSort.newest,
  });

  /// Matches discussions carrying ANY of these tags; empty means all.
  final Set<String> tagIds;
  final String text;
  final DiscussionSort sort;

  /// True when the list is narrowed (tags or text); sort alone isn't a filter.
  bool get isFiltered => tagIds.isNotEmpty || text.trim().isNotEmpty;

  DiscussionQuery copyWith({
    Set<String>? tagIds,
    String? text,
    DiscussionSort? sort,
  }) =>
      DiscussionQuery(
        tagIds: tagIds ?? this.tagIds,
        text: text ?? this.text,
        sort: sort ?? this.sort,
      );

  DiscussionQuery toggleTag(String tagId) => copyWith(
        tagIds: tagIds.contains(tagId)
            ? ({...tagIds}..remove(tagId))
            : {...tagIds, tagId},
      );

  /// Clears tags and text but keeps the chosen sort.
  DiscussionQuery cleared() => DiscussionQuery(sort: sort);

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
      other is DiscussionQuery &&
      setEquals(other.tagIds, tagIds) &&
      other.text == text &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(tagIds), text, sort);
}
