import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

/// Placeholder Home page — will show notifications and updates.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppTheme.space5),
      child: EmptyState(
        icon: Icons.home_outlined,
        title: 'Home',
        message: 'Notifications and updates will appear here.',
      ),
    );
  }
}
