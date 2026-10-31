class ParentResource {
  const ParentResource({
    required this.id,
    required this.title,
    required this.url,
    required this.sortOrder,
    required this.createdAt,
  });

  factory ParentResource.fromJson(Map<String, dynamic> json) => ParentResource(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
        sortOrder: json['sort_order'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String title;
  final String url;
  final int sortOrder;
  final DateTime createdAt;
}
