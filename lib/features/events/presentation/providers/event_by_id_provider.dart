import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/event_entity.dart';
import 'event_provider.dart';

final eventByIdProvider =
    FutureProvider.autoDispose.family<EventEntity?, String>((ref, eventId) async {
  final repository = ref.watch(eventRepositoryProvider);
  final result = await repository.getEventById(eventId);
  return result.fold((_) => null, (event) => event);
});
