import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/sticker_entity.dart';
import '../../domain/entities/sticker_pack_entity.dart';
import '../models/sticker_model.dart';
import '../models/sticker_pack_model.dart';

class StickerSupabaseDataSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  // ============ Converters ============

  StickerPackEntity _packFromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );
    return StickerPackModel.fromJson({
      'id': row['id'].toString(),
      'name': row['name'],
      'description': row['description'],
      'thumbnailUrl': row['cover_url'] ?? '',
      'creatorId': row['creator_id'] ?? '',
      'creatorName': data['creatorName'],
      'stickers': const [],
      'isOfficial': row['is_official'] ?? false,
      'isPremium': (row['price'] as int? ?? 0) > 0,
      'isPublic': row['is_public'] ?? true,
      'status': 'approved',
      'downloadCount': data['downloadCount'] ?? 0,
      'createdAt': row['created_at'],
    }).toEntity();
  }

  StickerEntity _stickerFromRow(Map<String, dynamic> row) {
    return StickerModel.fromJson({
      'id': row['id'].toString(),
      'packId': row['pack_id'].toString(),
      'url': row['url'],
      'emoji': row['emoji'],
      'order': row['sort_order'] ?? 0,
      'isAnimated': row['is_animated'] ?? false,
    }).toEntity();
  }

  /// Attache ├á chaque pack ses stickers. Les stickers de tous les packs sont
  /// charg├®s en une seule requ├¬te (et non une par pack) pour ├®viter le N+1.
  Future<List<StickerPackEntity>> _attachStickers(
    List<Map<String, dynamic>> packRows,
  ) async {
    if (packRows.isEmpty) return const [];

    final packIds = packRows.map((r) => r['id'].toString()).toList();
    final stickerRows = await _supabase
        .from('stickers')
        .select()
        .inFilter('pack_id', packIds)
        .order('sort_order', ascending: true);

    final byPack = <String, List<StickerEntity>>{};
    for (final row in stickerRows as List) {
      final sticker = _stickerFromRow(row as Map<String, dynamic>);
      byPack.putIfAbsent(sticker.packId, () => []).add(sticker);
    }

    return packRows
        .map(
          (row) => _packFromRow(
            row,
          ).copyWith(stickers: byPack[row['id'].toString()] ?? const []),
        )
        .toList();
  }

  // ============ Sticker Packs ============

  /// Stickers d'un pack donn├®, tri├®s par `sort_order`.
  Future<List<StickerEntity>> getStickersByPack(String packId) async {
    final rows = await _supabase
        .from('stickers')
        .select()
        .eq('pack_id', packId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => _stickerFromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Stream of official sticker packs
  Stream<List<StickerPackEntity>> getOfficialPacks() {
    return _supabase
        .from('sticker_packs')
        .stream(primaryKey: ['id'])
        .eq('is_official', true)
        .asyncMap(_attachStickers);
  }

  /// Stream of all approved public packs
  Stream<List<StickerPackEntity>> getPublicPacks() {
    return _supabase
        .from('sticker_packs')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .asyncMap(_attachStickers);
  }

  /// Get a specific sticker pack by ID
  Future<StickerPackEntity?> getPackById(String packId) async {
    final row = await _supabase
        .from('sticker_packs')
        .select()
        .eq('id', packId)
        .maybeSingle();
    if (row == null) return null;
    final packs = await _attachStickers([row]);
    return packs.first;
  }

  /// Stream of user's added sticker packs (via user_sticker_packs join)
  Stream<List<StickerPackEntity>> getUserPacks(String userId) {
    final controller = StreamController<List<StickerPackEntity>>();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('user_sticker_packs')
            .select('pack_id, sticker_packs(*)')
            .eq('user_id', userId)
            .order('added_at', ascending: false);

        final packRows = rows
            .map((row) => row['sticker_packs'] as Map<String, dynamic>?)
            .whereType<Map<String, dynamic>>()
            .toList();
        final packs = await _attachStickers(packRows);

        if (!controller.isClosed) controller.add(packs);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final channel = _supabase.channel('user_sticker_packs_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_sticker_packs',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Stream of user's created packs
  Stream<List<StickerPackEntity>> getUserCreatedPacks(String userId) {
    final controller = StreamController<List<StickerPackEntity>>();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('sticker_packs')
            .select()
            .eq('creator_id', userId)
            .order('created_at', ascending: false);
        final packs = await _attachStickers(
          rows.cast<Map<String, dynamic>>().toList(),
        );
        if (!controller.isClosed) controller.add(packs);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final channel = _supabase.channel('sticker_packs_created_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sticker_packs',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'creator_id',
        value: userId,
      ),
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Add a sticker pack to user's collection
  Future<void> addPackToUser(String userId, String packId) async {
    await _supabase.from('user_sticker_packs').upsert({
      'user_id': userId,
      'pack_id': packId,
      'added_at': DateTime.now().toIso8601String(),
    });
  }

  /// Remove a sticker pack from user's collection
  Future<void> removePackFromUser(String userId, String packId) async {
    await _supabase
        .from('user_sticker_packs')
        .delete()
        .eq('user_id', userId)
        .eq('pack_id', packId);
  }

  /// Check if user has a specific pack
  Future<bool> userHasPack(String userId, String packId) async {
    final row = await _supabase
        .from('user_sticker_packs')
        .select('pack_id')
        .eq('user_id', userId)
        .eq('pack_id', packId)
        .maybeSingle();
    return row != null;
  }

  // ============ Recent Stickers ============

  /// Stream of recent stickers used by user
  Stream<List<StickerEntity>> getRecentStickers(String userId) {
    final controller = StreamController<List<StickerEntity>>();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('user_recent_stickers')
            .select('sticker_id, used_at, stickers(*)')
            .eq('user_id', userId)
            .order('used_at', ascending: false)
            .limit(30);

        final stickers = rows
            .map((row) {
              final s = row['stickers'] as Map<String, dynamic>?;
              if (s == null) return null;
              return _stickerFromRow(s);
            })
            .whereType<StickerEntity>()
            .toList();

        if (!controller.isClosed) controller.add(stickers);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final channel = _supabase.channel('recent_stickers_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_recent_stickers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Add a sticker to recent stickers
  Future<void> addToRecentStickers(String userId, StickerEntity sticker) async {
    await _supabase.from('user_recent_stickers').upsert({
      'user_id': userId,
      'sticker_id': sticker.id,
      'used_at': DateTime.now().toIso8601String(),
    });
  }

  // ============ Favorite Stickers ============

  /// Stream of favorite stickers
  Stream<List<StickerEntity>> getFavoriteStickers(String userId) {
    final controller = StreamController<List<StickerEntity>>();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('user_favorite_stickers')
            .select('sticker_id, added_at, stickers(*)')
            .eq('user_id', userId)
            .order('added_at', ascending: false);

        final stickers = rows
            .map((row) {
              final s = row['stickers'] as Map<String, dynamic>?;
              if (s == null) return null;
              return _stickerFromRow(s);
            })
            .whereType<StickerEntity>()
            .toList();

        if (!controller.isClosed) controller.add(stickers);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final channel = _supabase.channel('favorite_stickers_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_favorite_stickers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => fetch(),
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Toggle sticker as favorite ÔÇö returns true if added, false if removed
  Future<bool> toggleFavorite(String userId, StickerEntity sticker) async {
    final existing = await _supabase
        .from('user_favorite_stickers')
        .select('sticker_id')
        .eq('user_id', userId)
        .eq('sticker_id', sticker.id)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('user_favorite_stickers')
          .delete()
          .eq('user_id', userId)
          .eq('sticker_id', sticker.id);
      return false;
    } else {
      await _supabase.from('user_favorite_stickers').upsert({
        'user_id': userId,
        'sticker_id': sticker.id,
        'added_at': DateTime.now().toIso8601String(),
      });
      return true;
    }
  }

  /// Check if sticker is favorite
  Future<bool> isFavorite(
    String userId,
    String packId,
    String stickerId,
  ) async {
    final row = await _supabase
        .from('user_favorite_stickers')
        .select('sticker_id')
        .eq('user_id', userId)
        .eq('sticker_id', stickerId)
        .maybeSingle();
    return row != null;
  }

  // ============ Create Sticker Pack ============

  /// Not implemented: file uploads still require Firebase Storage.
  Future<String> createStickerPack({
    required String userId,
    required String userName,
    required String name,
    String? description,
    required File thumbnailFile,
    required List<File> stickerFiles,
    bool isPublic = true,
  }) {
    throw UnimplementedError(
      'createStickerPack: file uploads are handled by Firebase Storage. '
      'Migrate storage to Supabase Storage before implementing this method.',
    );
  }

  /// Not implemented ÔÇö see [createStickerPack].
  Future<String> uploadStickerFile({
    required String packId,
    required String fileName,
    required File file,
    required bool isUserCreated,
    String? userId,
  }) {
    throw UnimplementedError(
      '_uploadStickerFile: file uploads are handled by Firebase Storage.',
    );
  }

  /// Delete a user-created sticker pack
  Future<void> deleteStickerPack(String packId, String userId) async {
    final pack = await getPackById(packId);
    if (pack == null || pack.creatorId != userId) {
      throw Exception('Cannot delete this pack');
    }

    await _supabase
        .from('sticker_packs')
        .delete()
        .eq('id', packId);

    await removePackFromUser(userId, packId);
  }
}
