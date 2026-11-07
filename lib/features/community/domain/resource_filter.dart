import 'package:flutter/foundation.dart';

import 'parent_resource.dart';

/// Tag + text filter for the Parent Hub. The resource list is small and
/// global, so it's filtered on the client rather than per keystroke in SQL.
@immutable
class ResourceFilter {
  const ResourceFilter({this.tagIds = const {}, this.text = ''});

  /// Matches resources carrying ANY of these tags; empty means all.
  final Set<String> tagIds;
  final String text;

  bool get isFiltered => tagIds.isNotEmpty || text.trim().isNotEmpty;

  ResourceFilter toggleTag(String tagId) => ResourceFilter(
        tagIds: tagIds.contains(tagId)
            ? ({...tagIds}..remove(tagId))
            : {...tagIds, tagId},
        text: text,
      );

  ResourceFilter withText(String value) =>
      ResourceFilter(tagIds: tagIds, text: value);

  List<ParentResource> apply(List<ParentResource> resources) {
    final needle = text.trim().toLowerCase();
    return [
      for (final r in resources)
        if ((tagIds.isEmpty || r.tagIds.any(tagIds.contains)) &&
            (needle.isEmpty || r.title.toLowerCase().contains(needle)))
          r,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is ResourceFilter &&
      setEquals(other.tagIds, tagIds) &&
      other.text == text;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(tagIds), text);
}
