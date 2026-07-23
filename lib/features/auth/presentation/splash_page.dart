import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shown while the session is restored and the profile row is fetched.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.anchor, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: AppTheme.space4),
            Text('TrueAnchor', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppTheme.space6),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
