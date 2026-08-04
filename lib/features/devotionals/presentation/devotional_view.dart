import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/devotional.dart';

/// Renders one devotional in four sections: Verse of the Day, Upward
/// Reflection, Inward Reflection prompts, and Outward. Pure display — no
/// providers, no navigation — so it can be reused by the today page, history,
/// or any future preview screen.
///
/// The interactive Inward Reflection input is NOT part of this widget — it is
/// added by the parent (e.g. TodayPage) between the upward and outward
/// sections via [inwardChild].
class DevotionalView extends StatelessWidget {
  const DevotionalView({
    required this.devotional,
    this.inwardChild,
    super.key,
  });

  final Devotional devotional;

  /// Slot for the interactive Inward Reflection card, inserted between the
  /// prompts and the Outward section.
  final Widget? inwardChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(devotional.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppTheme.space4),

        // — Verse of the Day —
        _SectionHeader(icon: Icons.auto_stories_outlined, label: 'Verse of the Day'),
        const SizedBox(height: AppTheme.space3),
        _ScriptureBlock(devotional: devotional),
        const SizedBox(height: AppTheme.space5),

        // — Upward Reflection —
        _SectionHeader(icon: Icons.arrow_upward, label: 'Upward Reflection'),
        const SizedBox(height: AppTheme.space3),
        for (final paragraph in _paragraphs(devotional.body)) ...[
          Text(paragraph, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppTheme.space4),
        ],

        // — Inward Reflection —
        _SectionHeader(
          icon: Icons.self_improvement_outlined,
          label: 'Inward Reflection',
        ),
        const SizedBox(height: AppTheme.space3),
        if (devotional.hasQuestions) ...[
          for (var i = 0; i < devotional.discussionQuestions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}.', style: theme.textTheme.bodyLarge),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(
                    child: Text(
                      devotional.discussionQuestions[i],
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (inwardChild != null) ...[
          const SizedBox(height: AppTheme.space2),
          inwardChild!,
        ],
        const SizedBox(height: AppTheme.space5),

        // — Outward —
        if (devotional.outwardText != null) ...[
          _SectionHeader(icon: Icons.diversity_3_outlined, label: 'Outward'),
          const SizedBox(height: AppTheme.space3),
          Text(devotional.outwardText!, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppTheme.space5),
        ],

        if (devotional.copyrightNotice != null)
          Text(
            devotional.copyrightNotice!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppTheme.space2),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ScriptureBlock extends StatelessWidget {
  const _ScriptureBlock({required this.devotional});

  final Devotional devotional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            devotional.scriptureText,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          Text(
            devotional.attribution,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

List<String> _paragraphs(String body) => body
    .split(RegExp(r'\n\s*\n'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList(growable: false);
