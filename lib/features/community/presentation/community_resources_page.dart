import 'package:flutter/material.dart';

import '../../../core/widgets/app_widgets.dart';

class CommunityResourcesPage extends StatelessWidget {
  const CommunityResourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'Parent resources',
        message: 'Curated resources for parents — biblical worldview guides, '
            'media literacy, identity conversation starters, and practical '
            'parenting tools — are coming soon.',
      ),
    );
  }
}
