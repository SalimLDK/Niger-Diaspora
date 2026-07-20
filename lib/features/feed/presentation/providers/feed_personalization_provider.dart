import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../profile/presentation/providers/profile_provider.dart';

const _kHashtagWeightsKey = 'feed_hashtag_weights';

/// Loads hashtag interaction weights from SharedPreferences.
final hashtagWeightsProvider = FutureProvider<Map<String, int>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kHashtagWeightsKey);
  if (raw == null) return {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return {};
  }
});

/// Loads the set of user IDs that the current user follows.
final followingIdsProvider = FutureProvider<Set<String>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return {};
  try {
    final rows = await Supabase.instance.client
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', uid);
    return rows
        .map((r) => r['following_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  } catch (_) {
    return {};
  }
});

/// Current user's country from their profile.
final myCountryProvider = FutureProvider<String?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final profileAsync = ref.watch(profileNotifierProvider(uid));
  return profileAsync.whenOrNull(data: (p) => p?.currentCountry);
});

/// Records that the current user interacted with a post containing [hashtags].
/// Increments each hashtag's weight in SharedPreferences.
Future<void> recordHashtagInteraction(List<String> hashtags) async {
  if (hashtags.isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHashtagWeightsKey);
    final weights = <String, int>{};
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      weights.addAll(decoded.map((k, v) => MapEntry(k, (v as num).toInt())));
    }
    for (final tag in hashtags) {
      weights[tag] = (weights[tag] ?? 0) + 1;
    }
    // Cap each weight at 50 to avoid runaway dominance
    for (final tag in weights.keys.toList()) {
      if (weights[tag]! > 50) weights[tag] = 50;
    }
    await prefs.setString(_kHashtagWeightsKey, jsonEncode(weights));
  } catch (_) {}
}
