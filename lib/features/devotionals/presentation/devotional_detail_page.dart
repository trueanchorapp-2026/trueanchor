import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../progress/presentation/progress_check_card.dart';
import '../domain/devotional.dart';
import 'devotional_view.dart';
import 'inward_reflection_card.dart';

/// Full-screen view of a past devotional, with the user's saved Inward
/// Reflection and progress card.
class DevotionalDetailPage extends StatelessWidget {
  const DevotionalDetailPage({required this.devotional, super.key});

  final Devotional devotional;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMEd().format(devotional.publishOn)),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DevotionalView(
                  devotional: devotional,
                  inwardChild: InwardReflectionCard(
                    devotionalId: devotional.id,
                  ),
                ),
                const SizedBox(height: AppTheme.space5),
                const ProgressCheckCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
