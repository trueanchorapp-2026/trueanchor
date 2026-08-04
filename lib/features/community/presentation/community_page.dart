import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

/// Placeholder Community page — adults only. Will show community news,
/// discussions, events, and parent resources.
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppTheme.space5),
      child: EmptyState(
        icon: Icons.diversity_3_outlined,
        title: 'Community',
        message: 'Community features are coming soon.',
      ),
    );
  }
}
