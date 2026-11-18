import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/vote.dart';

/// ▲ up-count ▼ down-count. Tapping your current vote again clears it.
/// [onVote] receives 1 (up) or -1 (down); errors are shown as a snack.
class VoteBar extends StatelessWidget {
  const VoteBar({required this.votes, required this.onVote, super.key});

  final VoteTally votes;
  final Future<void> Function(int direction) onVote;

  Future<void> _tap(BuildContext context, int direction) async {
    try {
      await onVote(direction);
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Vote not saved: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VoteButton(
          icon: Icons.arrow_upward,
          count: votes.upvotes,
          selected: votes.myVote == 1,
          tooltip: votes.myVote == 1 ? 'Remove upvote' : 'Upvote',
          semanticNoun: 'upvote',
          onPressed: () => _tap(context, 1),
        ),
        const SizedBox(width: AppTheme.space1),
        _VoteButton(
          icon: Icons.arrow_downward,
          count: votes.downvotes,
          selected: votes.myVote == -1,
          tooltip: votes.myVote == -1 ? 'Remove downvote' : 'Downvote',
          semanticNoun: 'downvote',
          onPressed: () => _tap(context, -1),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.count,
    required this.selected,
    required this.tooltip,
    required this.semanticNoun,
    required this.onPressed,
  });

  final IconData icon;
  final int count;
  final bool selected;
  final String tooltip;
  final String semanticNoun;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$count ${count == 1 ? semanticNoun : '${semanticNoun}s'}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space2,
              vertical: AppTheme.space1,
            ),
            decoration: selected
                ? BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppTheme.space1),
                Text(
                  '$count',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Upvote-only "helpful" toggle for replies.
class HelpfulButton extends StatelessWidget {
  const HelpfulButton({
    required this.count,
    required this.marked,
    required this.onToggle,
    super.key,
  });

  final int count;
  final bool marked;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = marked ? scheme.primary : scheme.onSurfaceVariant;
    return Tooltip(
      message: marked ? 'Remove helpful' : 'Mark helpful',
      child: Semantics(
        button: true,
        selected: marked,
        label: 'Helpful, $count',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            try {
              await onToggle();
            } catch (e) {
              if (context.mounted) {
                showAppSnack(context, 'Not saved: $e', isError: true);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space1,
              vertical: AppTheme.space1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  marked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: AppTheme.space1),
                Text(
                  count == 0 ? 'Helpful' : 'Helpful · $count',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
