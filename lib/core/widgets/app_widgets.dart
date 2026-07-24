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

/// CLAUDE.md: "Confirm destructive actions." Returns true only on confirm.
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
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
        borderRadius: BorderRadius.circular(8),
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
        content: Text(message),
        backgroundColor: isError ? scheme.errorContainer : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
