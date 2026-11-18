import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/scenic_header.dart';
import '../domain/devotional.dart';
import 'devotional_section.dart';

/// Renders one devotional. Pure display — no providers, no navigation — so it
/// can be reused by the today page, history, or any future preview screen.
///
/// Structured (weekly) devotionals render every section in order: Verse,
/// Context, Go Deeper, Summary, Upward, Inward, Outward, Prayer,
/// Self-Application, Love in Action. Legacy rows render Verse, Upward (body),
/// Inward (discussion questions) and Outward.
///
/// Interactive pieces come from the parent through slots: [inwardChild] (the
/// inline journal card), [outwardChild] (e.g. "Log Love in Action") and
/// [prayerChild].
class DevotionalView extends StatelessWidget {
  const DevotionalView({
    required this.devotional,
    this.inwardChild,
    this.outwardChild,
    this.prayerChild,
    this.scenicVerse = false,
    super.key,
  });

  final Devotional devotional;

  /// Slot for the interactive Inward Reflection card, below the prompts.
  final Widget? inwardChild;

  /// Slot rendered below the Outward text.
  final Widget? outwardChild;

  /// Slot rendered in the Prayer section.
  final Widget? prayerChild;

  /// Set the verse on the landscape hero band. Reserved for today's
  /// devotional; history keeps the plain block.
  final bool scenicVerse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = devotional;
    const gap = SizedBox(height: AppTheme.space5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.themeLabel != null) ...[
          Text(
            'This week: ${d.themeLabel}',
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppTheme.space2),
        ],
        Text(d.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppTheme.space4),
        _Verse(devotional: d, scenic: scenicVerse),
        gap,
        if (d.isStructured) ..._structured(context) else ..._legacy(context),
        if (d.copyrightNotice != null)
          Text(
            d.copyrightNotice!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  List<Widget> _structured(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = devotional;
    const gap = SizedBox(height: AppTheme.space5);
    final themeTitle = d.theme?.title;

    return [
      if (d.context != null) ...[
        DevotionalSection(
          icon: Icons.history_edu_outlined,
          label: themeTitle == null ? 'In Context' : '$themeTitle in Context',
          body: d.context,
        ),
        gap,
      ],
      if (d.deeperText != null) ...[
        _GoDeeper(devotional: d),
        gap,
      ],
      if (d.summary != null) ...[
        DevotionalSection(
          icon: Icons.summarize_outlined,
          label: 'Summary',
          body: d.summary,
        ),
        gap,
      ],
      DevotionalSection(
        icon: Icons.arrow_upward,
        label: 'Upward',
        color: scheme.primary,
        container: scheme.primaryContainer,
        body: d.upwardBody,
        questions: d.upwardQuestions,
      ),
      gap,
      DevotionalSection(
        icon: Icons.self_improvement_outlined,
        label: 'Inward',
        color: scheme.secondary,
        container: scheme.secondaryContainer,
        body: d.inwardBody,
        questions: d.inwardPrompts,
        child: inwardChild,
      ),
      gap,
      if (d.outwardText != null) ...[
        DevotionalSection(
          icon: Icons.diversity_3_outlined,
          label: 'Outward',
          color: scheme.tertiary,
          container: scheme.tertiaryContainer,
          body: d.outwardText,
          questions: d.outwardQuestions,
        ),
        gap,
      ],
      if (d.prayer != null || prayerChild != null) ...[
        DevotionalSection(
          icon: Icons.volunteer_activism_outlined,
          label: 'Prayer',
          body: d.prayer,
          child: prayerChild,
        ),
        gap,
      ],
      if (d.selfApplicationQuestions.isNotEmpty) ...[
        DevotionalSection(
          icon: Icons.checklist_outlined,
          label: 'Self-Application',
          questions: d.selfApplicationQuestions,
          questionsLabel: null,
        ),
        gap,
      ],
      if (d.loveInAction != null) ...[
        DevotionalSection(
          icon: Icons.favorite_outline,
          label: 'Love in Action',
          color: scheme.tertiary,
          container: scheme.tertiaryContainer,
          body: d.loveInAction,
          questions: d.loveInActionQuestions,
          child: outwardChild,
        ),
        gap,
      ],
    ];
  }

  List<Widget> _legacy(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = devotional;
    const gap = SizedBox(height: AppTheme.space5);

    return [
      DevotionalSection(
        icon: Icons.arrow_upward,
        label: 'Upward Reflection',
        color: scheme.primary,
        container: scheme.primaryContainer,
        body: d.upwardText,
      ),
      gap,
      DevotionalSection(
        icon: Icons.self_improvement_outlined,
        label: 'Inward Reflection',
        color: scheme.secondary,
        container: scheme.secondaryContainer,
        questions: d.inwardPrompts,
        questionsLabel: null,
        child: inwardChild,
      ),
      gap,
      if (d.outwardText != null) ...[
        DevotionalSection(
          icon: Icons.diversity_3_outlined,
          label: 'Outward',
          color: scheme.tertiary,
          container: scheme.tertiaryContainer,
          body: d.outwardText,
          child: outwardChild,
        ),
        gap,
      ],
      if (prayerChild != null) ...[
        DevotionalSection(
          icon: Icons.volunteer_activism_outlined,
          label: 'Prayer',
          child: prayerChild,
        ),
        gap,
      ],
    ];
  }
}

class _Verse extends StatelessWidget {
  const _Verse({required this.devotional, required this.scenic});

  final Devotional devotional;
  final bool scenic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const header = DevotionalSectionHeader(
      icon: Icons.auto_stories_outlined,
      label: 'Verse of the Day',
    );
    final text = _VerseText(
      text: devotional.scriptureText,
      attribution: devotional.attribution,
    );

    if (scenic) {
      return ScenicHeader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, const SizedBox(height: AppTheme.space3), text],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: AppTheme.space3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: text,
        ),
      ],
    );
  }
}

/// The Go Deeper passage, collapsed by default: it is long, and the verse of
/// the day already sits above it.
class _GoDeeper extends StatelessWidget {
  const _GoDeeper({required this.devotional});

  final Devotional devotional;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Theme(
        // Drop the ExpansionTile's divider lines inside the rounded block.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: AppTheme.space4),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTheme.space4,
            0,
            AppTheme.space4,
            AppTheme.space4,
          ),
          title: DevotionalSectionHeader(
            icon: Icons.menu_book_outlined,
            label: devotional.deeperReference == null
                ? 'Go Deeper'
                : 'Go Deeper | ${devotional.deeperReference}',
          ),
          children: [
            _VerseText(
              text: devotional.deeperText!,
              attribution: devotional.deeperAttribution,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseText extends StatelessWidget {
  const _VerseText({required this.text, this.attribution});

  final String text;
  final String? attribution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: AppTheme.serifFamily,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: scheme.onSurface,
          ),
        ),
        if (attribution != null) ...[
          const SizedBox(height: AppTheme.space3),
          Text(
            attribution!,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
