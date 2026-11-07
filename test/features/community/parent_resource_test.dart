import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/parent_resource.dart';

void main() {
  test('ParentResource.fromJson reads a parent_resources row', () {
    final resource = ParentResource.fromJson({
      'id': 'r1',
      'title': 'Media literacy guide',
      'url': 'https://example.org/guide',
      'sort_order': 2,
      'created_at': '2026-10-01T12:00:00Z',
    });

    expect(resource.id, 'r1');
    expect(resource.title, 'Media literacy guide');
    expect(resource.url, 'https://example.org/guide');
    expect(resource.sortOrder, 2);
    expect(resource.createdAt, DateTime.utc(2026, 10, 1, 12));
    expect(resource.tagIds, isEmpty);
  });

  test('ParentResource.fromJson reads embedded tags', () {
    final resource = ParentResource.fromJson({
      'id': 'r1',
      'title': 'Guide',
      'url': 'https://example.org/guide',
      'sort_order': 0,
      'created_at': '2026-10-01T12:00:00Z',
      'tags': [
        {'tag_id': 't1'},
        {'tag_id': 't2'},
      ],
    });

    expect(resource.tagIds, ['t1', 't2']);
  });
}
