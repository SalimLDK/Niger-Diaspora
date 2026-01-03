import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/services/preferences_service.dart';

part 'home_provider.g.dart';

class HomeStats {
  final int membersCount;
  final int groupsCount;
  final int eventsCount;
  final String? country;

  const HomeStats({
    this.membersCount = 0,
    this.groupsCount = 0,
    this.eventsCount = 0,
    this.country,
  });
}

@riverpod
class HomeStatsNotifier extends _$HomeStatsNotifier {
  static const String _cacheKey = 'home_stats_cache';
  String? _currentCountry;

  @override
  FutureOr<HomeStats> build() async {
    // Keep state alive even when not listened to (navigation away)
    // This allows instant display when returning to Home
    ref.keepAlive();

    // 1. Try to load from cache immediately for instant UI
    final cached = _loadFromCache();
    if (cached != null && cached.country == _currentCountry) {
      // Return cached data if country matches
    }

    // 2. Query Firestore using robust COUNT aggregation
    // This is much cheaper and faster than snapshots
    return _fetchStats();
  }

  /// Met à jour le pays et recharge les statistiques
  Future<void> setCountry(String? country) async {
    if (_currentCountry == country) return;
    _currentCountry = country;
    await refresh();
  }

  Future<HomeStats> _fetchStats() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Build queries based on country filter
      Query<Map<String, dynamic>> membersQuery = firestore
          .collection(FirebaseCollections.profiles)
          .where('isVisible', isEqualTo: true);

      Query<Map<String, dynamic>> groupsQuery = firestore
          .collection(FirebaseCollections.groups)
          .where('isPrivate', isEqualTo: false);

      Query<Map<String, dynamic>> eventsQuery = firestore
          .collection(FirebaseCollections.events)
          .where('startDate', isGreaterThan: Timestamp.now());

      // Apply country filter if set
      if (_currentCountry != null && _currentCountry!.isNotEmpty) {
        membersQuery = membersQuery.where('currentCountry', isEqualTo: _currentCountry);
        groupsQuery = groupsQuery.where('country', isEqualTo: _currentCountry);
        // Events use 'country' field if available
        eventsQuery = eventsQuery.where('country', isEqualTo: _currentCountry);
      }

      // Run queries in parallel
      final results = await Future.wait([
        membersQuery.count().get(),
        groupsQuery.count().get(),
        eventsQuery.count().get(),
      ]);

      final stats = HomeStats(
        membersCount: results[0].count ?? 0,
        groupsCount: results[1].count ?? 0,
        eventsCount: results[2].count ?? 0,
        country: _currentCountry,
      );

      // Cache the fresh result
      _saveToCache(stats);

      return stats;
    } catch (e) {
      // debugPrint('❌ Error fetching home stats: $e');
      // If error, try returning cached data or rethrow
      final cached = _loadFromCache();
      if (cached != null) return cached;
      throw Exception('Impossible de charger les statistiques');
    }
  }

  HomeStats? _loadFromCache() {
    try {
      final prefs = PreferencesService.instance;
      final cacheKeyWithCountry = _currentCountry != null
          ? '${_cacheKey}_$_currentCountry'
          : _cacheKey;
      final cachedJson = prefs.prefs.getString(cacheKeyWithCountry);
      if (cachedJson != null) {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        return HomeStats(
          membersCount: data['membersCount'] as int? ?? 0,
          groupsCount: data['groupsCount'] as int? ?? 0,
          eventsCount: data['eventsCount'] as int? ?? 0,
          country: data['country'] as String?,
        );
      }
    } catch (e) {
      // debugPrint('⚠️ Failed to load cached stats: $e');
    }
    return null;
  }

  Future<void> _saveToCache(HomeStats stats) async {
    try {
      final prefs = PreferencesService.instance;
      final cacheKeyWithCountry = _currentCountry != null
          ? '${_cacheKey}_$_currentCountry'
          : _cacheKey;
      final json = jsonEncode({
        'membersCount': stats.membersCount,
        'groupsCount': stats.groupsCount,
        'eventsCount': stats.eventsCount,
        'country': stats.country,
      });
      await prefs.prefs.setString(cacheKeyWithCountry, json);
    } catch (e) {
      // debugPrint('⚠️ Failed to cache stats: $e');
    }
  }

  Future<void> refresh() async {
    // Invalidate to force a re-fetch
    state = const AsyncValue.loading();
    try {
      final newStats = await _fetchStats();
      state = AsyncValue.data(newStats);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
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
