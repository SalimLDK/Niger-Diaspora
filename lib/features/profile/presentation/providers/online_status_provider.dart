import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/online_status_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'profile_provider.dart';

part 'online_status_provider.g.dart';

/// Provider for the OnlineStatusService instance
@riverpod
OnlineStatusService onlineStatusService(Ref ref) {
  return OnlineStatusService.instance;
}

/// Provider that streams a specific user's online status
@riverpod
Stream<bool> userOnlineStatus(Ref ref, String userId) {
  final service = ref.watch(onlineStatusServiceProvider);
  return service.getUserOnlineStatus(userId);
}

/// Provider that streams a specific user's last seen timestamp
@riverpod
Stream<DateTime?> userLastSeen(Ref ref, String userId) {
  final service = ref.watch(onlineStatusServiceProvider);
  return service.getUserLastSeen(userId);
}

/// Provider for the current user's online status visibility preference
@riverpod
class CurrentUserOnlineStatusVisibility
    extends _$CurrentUserOnlineStatusVisibility {
  @override
  Future<bool> build() async {
    final currentUser = await ref.watch(currentUserAsyncProvider.future);
    if (currentUser == null) return true;

    // Get the current value from the profile
    final profile = await ref.watch(userStreamProvider(currentUser.id).future);
    return profile?.showOnlineStatus ?? true;
  }

  /// Toggle the current user's online status visibility
  Future<void> toggle() async {
    final currentValue = state.valueOrNull ?? true;
    final newValue = !currentValue;

    state = AsyncValue.data(newValue);

    try {
      final service = ref.read(onlineStatusServiceProvider);
      await service.updateOnlineStatusVisibility(newValue);
    } catch (e, stackTrace) {
      // Revert on error
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Set the online status visibility to a specific value
  Future<void> setValue(bool value) async {
    state = AsyncValue.data(value);

    try {
      final service = ref.read(onlineStatusServiceProvider);
      await service.updateOnlineStatusVisibility(value);
    } catch (e, stackTrace) {
      // Revert on error
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
}
