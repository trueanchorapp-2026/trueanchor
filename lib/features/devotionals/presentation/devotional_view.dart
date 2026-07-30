import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/devotional.dart';

/// Renders one devotional. Pure display — no providers, no navigation — so it
/// can be reused by any future archive or preview screen.
class DevotionalView extends StatelessWidget {
  const DevotionalView({required this.devotional, super.key});

  final Devotional devotional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(devotional.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppTheme.space4),
        _ScriptureBlock(devotional: devotional),
        const SizedBox(height: AppTheme.space5),
        for (final paragraph in _paragraphs(devotional.body)) ...[
          Text(paragraph, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppTheme.space4),
        ],
        if (devotional.hasQuestions) ...[
          const SizedBox(height: AppTheme.space2),
          Text('Talk about it', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.space3),
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
        if (devotional.hasActivity) ...[
          const SizedBox(height: AppTheme.space3),
          Text('Try this', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.space2),
          Text(devotional.activity!, style: theme.textTheme.bodyLarge),
        ],
        // A licensed translation requires its notice wherever the verse text
        // appears. Public domain texts carry none, so this stays hidden.
        if (devotional.copyrightNotice != null) ...[
          const SizedBox(height: AppTheme.space5),
          Text(
            devotional.copyrightNotice!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
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

/// Devotional bodies are plain text with blank lines between paragraphs — no
/// markdown is rendered in V1, so splitting on blank lines is the whole layout.
List<String> _paragraphs(String body) => body
    .split(RegExp(r'\n\s*\n'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList(growable: false);
