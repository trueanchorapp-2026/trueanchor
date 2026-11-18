import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Centres and width-caps a form/content column so it stays readable on wide
/// web viewports instead of stretching edge to edge.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Publishes the width of the shell's body (the screen minus the navigation
/// rail) so [feedInsets] can centre content without a LayoutBuilder per page.
class ContentWidthScope extends InheritedWidget {
  const ContentWidthScope({
    required this.width,
    required super.child,
    super.key,
  });

  final double width;

  @override
  bool updateShouldNotify(ContentWidthScope oldWidget) =>
      width != oldWidget.width;
}

/// List padding that centres content and caps it at [maxWidth] on wide web
/// viewports, with a 16px gutter on phones. Goes on the scrollable's own
/// `padding` rather than wrapping it in a ConstrainedBox, so the scrollable
/// stays full width and the scroll wheel and pull-to-refresh work anywhere
/// on screen, not just over the column.
///
/// Pass [AppTheme.fabClearance] as [bottom] for a list under a FAB.
EdgeInsets feedInsets(
  BuildContext context, {
  double bottom = AppTheme.space4,
  double maxWidth = AppTheme.maxFeedWidth,
}) {
  final width =
      context.dependOnInheritedWidgetOfExactType<ContentWidthScope>()?.width ??
          MediaQuery.sizeOf(context).width;
  return feedInsetsFor(width, bottom: bottom, maxWidth: maxWidth);
}

/// [feedInsets] for a known [width]; split out so it can be unit tested.
EdgeInsets feedInsetsFor(
  double width, {
  double bottom = AppTheme.space4,
  double maxWidth = AppTheme.maxFeedWidth,
}) {
  final side = width > maxWidth + 2 * AppTheme.space4
      ? (width - maxWidth) / 2
      : AppTheme.space4;
  return EdgeInsets.fromLTRB(side, AppTheme.space4, side, bottom);
}

/// A [ListView] of [children] padded by [feedInsets]: centred and
/// width-capped on wide screens, edge to edge with a 16px gutter on phones.
class ContentList extends StatelessWidget {
  const ContentList({
    required this.children,
    this.maxWidth = AppTheme.maxFeedWidth,
    this.bottom = AppTheme.space4,
    this.physics,
    super.key,
  });

  final List<Widget> children;
  final double maxWidth;
  final double bottom;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: feedInsets(context, bottom: bottom, maxWidth: maxWidth),
      physics: physics,
      children: children,
    );
  }
}

/// The app's standard tappable summary card: a leading icon, a title, an
/// optional subtitle, and either a chevron (when tappable) or [trailing].
/// [child] adds a body below the header row, for cards that list items.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.color,
    this.trailing,
    this.onTap,
    this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;

  /// Card fill; defaults to the theme's card colour.
  final Color? color;

  /// Replaces the default chevron.
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trailingWidget = trailing ??
        (onTap != null
            ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
            : null);

    return Card(
      margin: EdgeInsets.zero,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28, color: iconColor ?? scheme.primary),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: AppTheme.space2),
                    trailingWidget,
                  ],
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: AppTheme.space3),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error affordances.
/// Keeps `.when(...)` boilerplate out of every page.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.builder,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(message: '$error', onRetry: onRetry),
      data: builder,
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: AppTheme.space3),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.space4),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: AppTheme.space4),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppTheme.space2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.space5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A small pill label. [muted] picks the low-emphasis surface, for facts that
/// are merely informational; the default carries emphasis, for facts the user
/// is meant to notice.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.icon,
    this.muted = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background =
        muted ? scheme.surfaceContainerHighest : scheme.secondaryContainer;
    final foreground =
        muted ? scheme.onSurfaceVariant : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: AppTheme.space1),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// An advisory note inside a form — something the user should know before
/// submitting, but which does not block them. Distinct from [FormErrorBanner],
/// which reports a failure that already happened.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.message,
    this.icon = Icons.info_outline,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// One sharing tick, with the explanation of who it reaches sitting under it
/// rather than behind a tooltip — this is the one control in the app where
/// guessing wrong exposes something the author meant to keep close.
///
/// Shared by the journal editor and the Love in Action editor, which ask the
/// same two questions off the same `EntryVisibility` ladder.
class SharingCheckbox extends StatelessWidget {
  const SharingCheckbox({
    required this.enabled,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
    super.key,
  });

  final bool enabled;
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: value,
      onChanged: enabled ? (checked) => onChanged(checked ?? false) : null,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// One number and its label, sized to share a [Row] with its peers.
///
/// Deliberately [Expanded]: a row of these divides the width evenly, so four
/// stats line up whatever their digits. Used by the engagement dashboard, the
/// pastor's drill-down, and the weekly summary card.
class StatTile extends StatelessWidget {
  const StatTile({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// CLAUDE.md: "Confirm destructive actions." Returns true only on confirm.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            minimumSize: const Size(88, 40),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showAppSnack(BuildContext context, String message, {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: isError ? TextStyle(color: scheme.onErrorContainer) : null,
        ),
        backgroundColor: isError ? scheme.errorContainer : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
