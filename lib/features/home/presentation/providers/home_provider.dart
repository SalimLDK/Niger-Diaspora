import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

@Riverpod(keepAlive: true)
class HomeStatsNotifier extends _$HomeStatsNotifier {
  @override
  Future<HomeStats> build() async {
    return _loadStats();
  }

  Future<HomeStats> _loadStats() async {
    int members = 0;
    int groups = 0;
    int events = 0;

    final firestore = FirebaseFirestore.instance;

    // 1. Membres
    try {
      final snapshot =
          await firestore
              .collection(FirebaseCollections.profiles)
              .where('isVisible', isEqualTo: true)
              .count()
              .get();
      members = snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Erreur chargement stats membres: $e');
    }

    // 2. Groupes
    try {
      final snapshot =
          await firestore.collection(FirebaseCollections.groups).count().get();
      groups = snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Erreur chargement stats groupes: $e');
    }

    // 3. Événements
    try {
      final snapshot =
          await firestore
              .collection(FirebaseCollections.events)
              .where('startDate', isGreaterThan: Timestamp.now())
              .count()
              .get();
      events = snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Erreur chargement stats événements: $e');
    }

    return HomeStats(
      membersCount: members,
      groupsCount: groups,
      eventsCount: events,
    );
  }

  Future<void> refresh() async {
    // Invalidate self to trigger a rebuild
    ref.invalidateSelf();
    // Wait for the new value (optional, but helpful for UI feedback if needed)
    await future;
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
