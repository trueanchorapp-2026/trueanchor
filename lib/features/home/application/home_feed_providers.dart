import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../events/application/event_providers.dart';
import '../../events/domain/event.dart';

final upcomingEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventListProvider).value ?? const [];
  final now = DateTime.now();
  return events.where((e) => !e.isPast(now)).take(3).toList();
});
