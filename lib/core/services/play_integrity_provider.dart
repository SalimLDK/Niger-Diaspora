import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'play_integrity_service.dart';

part 'play_integrity_provider.g.dart';

/// Provider for the Play Integrity service instance
@riverpod
PlayIntegrityService playIntegrityService(Ref ref) {
  return PlayIntegrityService();
}

/// State for integrity check results
class IntegrityCheckState {
  final bool isLoading;
  final PlayIntegrityVerdict? verdict;
  final String? error;

  const IntegrityCheckState({
    this.isLoading = false,
    this.verdict,
    this.error,
  });

  IntegrityCheckState copyWith({
    bool? isLoading,
    PlayIntegrityVerdict? verdict,
    String? error,
  }) {
    return IntegrityCheckState(
      isLoading: isLoading ?? this.isLoading,
      verdict: verdict ?? this.verdict,
      error: error,
    );
  }

  bool get isSecure => verdict?.isSecure ?? false;
  bool get isHighlySecure => verdict?.isHighlySecure ?? false;
  bool get hasChecked => verdict != null || error != null;
}

/// Notifier for managing integrity check state
@riverpod
class IntegrityCheck extends _$IntegrityCheck {
  @override
  IntegrityCheckState build() {
    return const IntegrityCheckState();
  }

  /// Perform an integrity check
  Future<PlayIntegrityVerdict> check({String? nonce}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(playIntegrityServiceProvider);
      final verdict = await service.checkIntegrity(nonce: nonce);

      if (verdict.hasError) {
        state = state.copyWith(
          isLoading: false,
          error: verdict.error,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          verdict: verdict,
        );
      }

      return verdict;
    } catch (e) {
      final error = 'Integrity check failed: $e';
      state = state.copyWith(
        isLoading: false,
        error: error,
      );
      return PlayIntegrityVerdict.error(error);
    }
  }

  /// Check if the device meets minimum security requirements
  Future<bool> requireSecureDevice({String? nonce}) async {
    final verdict = await check(nonce: nonce);
    return verdict.isSecure;
  }

  /// Check if the device meets high security requirements
  Future<bool> requireHighlySecureDevice({String? nonce}) async {
    final verdict = await check(nonce: nonce);
    return verdict.isHighlySecure;
  }

  /// Clear the current verdict state
  void clear() {
    state = const IntegrityCheckState();
  }
}

/// Provider to check if Play Integrity is available
@riverpod
Future<bool> playIntegrityAvailable(Ref ref) async {
  final service = ref.read(playIntegrityServiceProvider);
  return service.isAvailable();
}
