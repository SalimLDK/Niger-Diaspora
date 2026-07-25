import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/sticker_supabase_datasource.dart';
import '../../domain/entities/sticker_entity.dart';
import '../../domain/entities/sticker_pack_entity.dart';

// ============ Data Source Provider ============

/// Provider for the sticker data source
final stickerDataSourceProvider = Provider<StickerSupabaseDataSource>((ref) {
  return StickerSupabaseDataSource();
});

// ============ Stream Providers ============

/// Stream of official sticker packs
final officialStickerPacksProvider = StreamProvider<List<StickerPackEntity>>((ref) {
  final dataSource = ref.watch(stickerDataSourceProvider);
  return dataSource.getOfficialPacks();
});

/// Stream of all public sticker packs
final publicStickerPacksProvider = StreamProvider<List<StickerPackEntity>>((ref) {
  final dataSource = ref.watch(stickerDataSourceProvider);
  return dataSource.getPublicPacks();
});

/// Stream of user's added sticker packs
final userStickerPacksProvider = StreamProvider<List<StickerPackEntity>>((ref) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  final dataSource = ref.watch(stickerDataSourceProvider);
  yield* dataSource.getUserPacks(currentUser.id);
});

/// Stream of user's created sticker packs
final userCreatedPacksProvider = StreamProvider<List<StickerPackEntity>>((ref) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  final dataSource = ref.watch(stickerDataSourceProvider);
  yield* dataSource.getUserCreatedPacks(currentUser.id);
});

/// Stream of recent stickers used by user
final recentStickersProvider = StreamProvider<List<StickerEntity>>((ref) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  final dataSource = ref.watch(stickerDataSourceProvider);
  yield* dataSource.getRecentStickers(currentUser.id);
});

/// Stream of favorite stickers
final favoriteStickersProvider = StreamProvider<List<StickerEntity>>((ref) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  final dataSource = ref.watch(stickerDataSourceProvider);
  yield* dataSource.getFavoriteStickers(currentUser.id);
});

/// Get a specific sticker pack by ID
final stickerPackByIdProvider = FutureProvider.family<StickerPackEntity?, String>((ref, packId) async {
  final dataSource = ref.watch(stickerDataSourceProvider);
  return dataSource.getPackById(packId);
});

/// Check if user has a specific pack
final userHasPackProvider = FutureProvider.family<bool, String>((ref, packId) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return false;

  final dataSource = ref.watch(stickerDataSourceProvider);
  return dataSource.userHasPack(currentUser.id, packId);
});

// ============ State Notifier for Actions ============

/// State for sticker actions
class StickerActionsState {
  final bool isLoading;
  final String? error;

  const StickerActionsState({
    this.isLoading = false,
    this.error,
  });

  StickerActionsState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return StickerActionsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for sticker actions
class StickerActionsNotifier extends StateNotifier<StickerActionsState> {
  final StickerSupabaseDataSource _dataSource;
  final Ref _ref;

  StickerActionsNotifier(this._dataSource, this._ref)
      : super(const StickerActionsState());

  /// Add a pack to user's collection
  Future<bool> addPackToUser(String packId) async {
    final currentUser = await _ref.read(currentUserProvider.future);
    if (currentUser == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dataSource.addPackToUser(currentUser.id, packId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Remove a pack from user's collection
  Future<bool> removePackFromUser(String packId) async {
    final currentUser = await _ref.read(currentUserProvider.future);
    if (currentUser == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dataSource.removePackFromUser(currentUser.id, packId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Add sticker to recent stickers
  Future<void> addToRecent(StickerEntity sticker) async {
    final currentUser = await _ref.read(currentUserProvider.future);
    if (currentUser == null) return;

    try {
      await _dataSource.addToRecentStickers(currentUser.id, sticker);
    } catch (_) {
      // Silent fail for recent stickers
    }
  }

  /// Toggle sticker as favorite
  Future<bool> toggleFavorite(StickerEntity sticker) async {
    final currentUser = await _ref.read(currentUserProvider.future);
    if (currentUser == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final isFavorite = await _dataSource.toggleFavorite(currentUser.id, sticker);
      state = state.copyWith(isLoading: false);
      return isFavorite;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Create a new sticker pack
  Future<String?> createStickerPack({
    required String name,
    String? description,
    required File thumbnailFile,
    required List<File> stickerFiles,
    bool isPublic = true,
  }) async {
    final currentUser = await _ref.read(currentUserProvider.future);
    if (currentUser == null) return null;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final packId = await _dataSource.createStickerPack(
        userId: currentUser.id,
        userName: currentUser.displayName ?? 'Unknown',
        name: name,
        description: description,
        thumbnailFile: thumbnailFile,
        stickerFiles: stickerFiles,
        isPublic: isPublic,
      );
      state = state.copyWith(isLoading: false);
      return packId;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Delete a user-created sticker pack
  Future<bool> deleteStickerPack(String packId) async {
    final currentUser = await _ref.read(currentUserProvider.future);
    if (currentUser == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dataSource.deleteStickerPack(packId, currentUser.id);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

/// Provider for sticker actions
final stickerActionsProvider =
    StateNotifierProvider<StickerActionsNotifier, StickerActionsState>((ref) {
  final dataSource = ref.watch(stickerDataSourceProvider);
  return StickerActionsNotifier(dataSource, ref);
});

// ============ Combined Providers ============

/// Combined list of all user's available sticker packs (official + added)
final allUserPacksProvider = Provider<AsyncValue<List<StickerPackEntity>>>((ref) {
  final officialPacks = ref.watch(officialStickerPacksProvider);
  final userPacks = ref.watch(userStickerPacksProvider);

  return officialPacks.when(
    data: (official) => userPacks.when(
      data: (user) {
        // Combine and deduplicate
        final allPacks = <String, StickerPackEntity>{};
        for (final pack in official) {
          allPacks[pack.id] = pack;
        }
        for (final pack in user) {
          allPacks[pack.id] = pack;
        }
        return AsyncValue.data(allPacks.values.toList());
      },
      loading: () => AsyncValue.data(official),
      error: (e, s) => AsyncValue.data(official),
    ),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});
