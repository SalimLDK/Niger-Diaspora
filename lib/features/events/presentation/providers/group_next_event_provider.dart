import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/event_entity.dart';
import 'event_provider.dart';

/// Prochaine rencontre d'un groupe (§9d) : l'événement lié au groupe
/// (`EventEntity.groupId`) le plus proche dans le futur, ou `null` s'il n'y en
/// a pas. Filtrage/tri côté client (la requête datasource est single-field).
final groupNextEventProvider =
    FutureProvider.autoDispose.family<EventEntity?, String>((ref, groupId) async {
  final repository = ref.watch(eventRepositoryProvider);
  final result = await repository.getEventsByGroup(groupId);
  return result.fold((_) => null, (events) {
    final now = DateTime.now();
    final upcoming = events
        .where((e) =>
            e.status != EventStatus.cancelled && e.startDate.isAfter(now))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming.isEmpty ? null : upcoming.first;
  });
});
