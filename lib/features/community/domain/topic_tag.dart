/// A curated topic (e.g. "School Board") applied to community discussions
/// and Parent Hub resources so they can be filtered by subject.
class TopicTag {
  const TopicTag({
    required this.id,
    required this.slug,
    required this.label,
    this.sortOrder = 0,
  });

  factory TopicTag.fromJson(Map<String, dynamic> json) => TopicTag(
        id: json['id'] as String,
        slug: json['slug'] as String,
        label: json['label'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final String id;
  final String slug;
  final String label;
  final int sortOrder;

  /// Most tags a single discussion may carry (enforced again in 0030).
  static const maxPerPost = 3;

  /// Reads tag ids from either a flat `uuid[]` (the search RPC) or a list of
  /// embedded join rows like `[{tag_id: ...}]` (PostgREST embeds).
  static List<String> idsFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String)
          item
        else if (item is Map && item['tag_id'] is String)
          item['tag_id'] as String,
    ];
  }
}
