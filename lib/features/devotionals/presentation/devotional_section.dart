import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One devotional section: a header, optional body text, optional numbered
/// questions, and an optional interactive [child] at the bottom.
///
/// Body text is plain: a blank line starts a paragraph, a single newline is a
/// line break, and a line starting with "• " renders as a bullet.
class DevotionalSection extends StatelessWidget {
  const DevotionalSection({
    required this.icon,
    required this.label,
    this.color,
    this.container,
    this.body,
    this.questions = const [],
    this.questionsLabel = 'Reflect',
    this.child,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? container;
  final String? body;
  final List<String> questions;

  /// Heading above [questions]; null shows the list without one.
  final String? questionsLabel;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DevotionalSectionHeader(
          icon: icon,
          label: label,
          color: color,
          container: container,
        ),
        const SizedBox(height: AppTheme.space3),
        if (body != null) PlainTextBody(text: body!),
        if (questions.isNotEmpty) ...[
          if (questionsLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space2),
              child: Text(
                questionsLabel!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color ?? theme.colorScheme.primary,
                ),
              ),
            ),
          for (var i = 0; i < questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}.', style: style),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(child: Text(questions[i], style: style)),
                ],
              ),
            ),
        ],
        if (child != null) ...[
          const SizedBox(height: AppTheme.space2),
          child!,
        ],
      ],
    );
  }
}

/// A section label. Upward, Inward and Outward each pass their own
/// [color]/[container] pair and get a filled badge, so the three directions
/// of growth read as distinct at a glance.
class DevotionalSectionHeader extends StatelessWidget {
  const DevotionalSectionHeader({
    required this.icon,
    required this.label,
    this.color,
    this.container,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Color? container;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.primary;
    return Row(
      children: [
        if (container != null)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: container,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: foreground),
          )
        else
          Icon(icon, size: 20, color: foreground),
        const SizedBox(width: AppTheme.space2),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}

/// Renders authored plain text: paragraphs, line breaks and "• " bullets.
class PlainTextBody extends StatelessWidget {
  const PlainTextBody({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in paragraph.split('\n'))
                  if (line.trimLeft().startsWith('•'))
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppTheme.space2,
                        bottom: AppTheme.space1,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•', style: style),
                          const SizedBox(width: AppTheme.space2),
                          Expanded(
                            child: Text(
                              line.trimLeft().substring(1).trim(),
                              style: style,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(line.trim(), style: style),
              ],
            ),
          ),
      ],
    );
  }
}
