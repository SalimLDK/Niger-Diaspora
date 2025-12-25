import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/firebase_collections.dart';

part 'home_provider.g.dart';

class HomeStats {
  final int membersCount;
  final int groupsCount;
  final int eventsCount;

  const HomeStats({
    this.membersCount = 0,
    this.groupsCount = 0,
    this.eventsCount = 0,
  });
}

@riverpod
class HomeStatsNotifier extends _$HomeStatsNotifier {
  @override
  AsyncValue<HomeStats> build() {
    _loadStats();
    return const AsyncValue.loading();
  }

  Future<void> _loadStats() async {
    state = const AsyncValue.loading();

    try {
      final firestore = FirebaseFirestore.instance;

      // Compter les membres (profils visibles)
      final profilesSnapshot = await firestore
          .collection(FirebaseCollections.profiles)
          .where('isVisible', isEqualTo: true)
          .count()
          .get();

      // Compter les groupes
      final groupsSnapshot = await firestore
          .collection(FirebaseCollections.groups)
          .count()
          .get();

      // Compter les événements à venir
      final eventsSnapshot = await firestore
          .collection(FirebaseCollections.events)
          .where('startDate', isGreaterThan: Timestamp.now())
          .count()
          .get();

      state = AsyncValue.data(HomeStats(
        membersCount: profilesSnapshot.count ?? 0,
        groupsCount: groupsSnapshot.count ?? 0,
        eventsCount: eventsSnapshot.count ?? 0,
      ));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    await _loadStats();
  }
}

String formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}
