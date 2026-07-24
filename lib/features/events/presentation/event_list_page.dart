import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../application/event_providers.dart';
import '../domain/event.dart';

class EventListPage extends ConsumerWidget {
  const EventListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsState = ref.watch(eventListProvider);
    final canManage =
        ref.watch(currentProfileProvider).value?.role.canManageEvents ?? false;

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.eventEditor),
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(eventListProvider.notifier).refresh(),
        child: AsyncValueView(
          value: eventsState,
          onRetry: () => ref.read(eventListProvider.notifier).refresh(),
          builder: (events) {
            if (events.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: EmptyState(
                      icon: Icons.event_outlined,
                      title: 'No events yet',
                      message: canManage
                          ? 'Add your first event so families can see what is '
                              'coming up.'
                          : 'Your church has not posted any events yet. Check '
                              'back soon.',
                    ),
                  ),
                ),
              );
            }

            final now = DateTime.now();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                96, // clears the FAB
              ),
              itemCount: events.length,
              itemBuilder: (context, index) => _EventCard(
                event: events[index],
                canManage: canManage,
                isPast: events[index].isPast(now),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({
    required this.event,
    required this.canManage,
    required this.isPast,
  });

  final Event event;
  final bool canManage;
  final bool isPast;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this event?',
      message: 'Families will no longer see it. This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(eventListProvider.notifier).remove(event.id);
      if (context.mounted) showAppSnack(context, 'Event deleted.');
    } catch (error) {
      if (context.mounted) showAppSnack(context, '$error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Opacity(
        opacity: isPast ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canManage) ...[
                    IconButton(
                      tooltip: 'Edit event',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () =>
                          context.push(Routes.eventEditor, extra: event),
                    ),
                    IconButton(
                      tooltip: 'Delete event',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _delete(context, ref),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppTheme.space2),
              _IconLine(
                icon: Icons.schedule,
                text: _formatWhen(event.startsAt, event.endsAt),
                color: onMuted,
              ),
              if (event.location != null) ...[
                const SizedBox(height: AppTheme.space1),
                _IconLine(
                  icon: Icons.place_outlined,
                  text: event.location!,
                  color: onMuted,
                ),
              ],
              if (event.description != null) ...[
                const SizedBox(height: AppTheme.space3),
                Text(
                  event.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: AppTheme.space2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// "Sat, Jul 25, 2026 · 6:00 – 8:00 PM", collapsing the end when it is on the
/// same day or absent.
String _formatWhen(DateTime start, DateTime? end) {
  final date = DateFormat.yMMMEd().format(start);
  final startTime = DateFormat.jm().format(start);
  if (end == null) return '$date · $startTime';

  final sameDay =
      start.year == end.year && start.month == end.month && start.day == end.day;
  final endText =
      sameDay ? DateFormat.jm().format(end) : DateFormat.yMMMEd().add_jm().format(end);
  return '$date · $startTime – $endText';
}
