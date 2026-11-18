import 'package:flutter/material.dart';

import '../domain/published_post.dart';
import 'published_post_widgets.dart';

class CommunityNewsPage extends StatelessWidget {
  const CommunityNewsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const PublishedFeed(kind: PublishedKind.news);
}
