import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/parent_resource.dart';
import 'package:trueanchor/features/community/domain/resource_filter.dart';

ParentResource _resource(String id, String title, List<String> tagIds) =>
    ParentResource(
      id: id,
      title: title,
      url: 'https://example.org/$id',
      sortOrder: 0,
      createdAt: DateTime(2026),
      tagIds: tagIds,
    );

void main() {
  final resources = [
    _resource('1', 'Media literacy guide', ['media']),
    _resource('2', 'Talking about identity', ['identity', 'parenting']),
    _resource('3', 'Family devotions', []),
  ];

  List<String> ids(List<ParentResource> list) => [for (final r in list) r.id];

  test('no filter returns everything in order', () {
    expect(ids(const ResourceFilter().apply(resources)), ['1', '2', '3']);
  });

  test('tag filter matches any selected tag', () {
    const filter = ResourceFilter(tagIds: {'media', 'parenting'});
    expect(ids(filter.apply(resources)), ['1', '2']);
  });

  test('text matches the title case-insensitively', () {
    expect(ids(const ResourceFilter(text: ' IDENTITY ').apply(resources)),
        ['2']);
  });

  test('tags and text combine', () {
    const filter = ResourceFilter(tagIds: {'media', 'identity'}, text: 'guide');
    expect(ids(filter.apply(resources)), ['1']);
  });

  test('toggleTag keeps text; withText keeps tags', () {
    final filter = const ResourceFilter(text: 'x').toggleTag('t1');
    expect(filter, const ResourceFilter(tagIds: {'t1'}, text: 'x'));
    expect(filter.withText('y'),
        const ResourceFilter(tagIds: {'t1'}, text: 'y'));
    expect(filter.toggleTag('t1').tagIds, isEmpty);
  });
}
