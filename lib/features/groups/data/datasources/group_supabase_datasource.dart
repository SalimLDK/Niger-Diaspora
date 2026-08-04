import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/group_model.dart';
import '../models/group_pinned_item_model.dart';
import 'group_remote_datasource.dart';

Map<String, dynamic> _mapGroup(Map<String, dynamic> row) => {
  'id': row['id'],
  'name': row['name'],
  'description': row['description'] ?? '',
  'imageUrl': row['avatar_url'],
  'creatorId': row['creator_id'],
  'creatorName': row['creator_name'],
  'adminIds': (row['admin_ids'] as List?)?.cast<String>() ?? [],
  'moderatorIds': (row['moderator_ids'] as List?)?.cast<String>() ?? [],
  'memberIds': (row['member_ids'] as List?)?.cast<String>() ?? [],
  'category': row['category'] ?? 'general',
  'isPrivate': row['is_private'] ?? false,
  'location': row['group_location'],
  'tags': (row['tags'] as List?)?.cast<String>() ?? [],
  'country': row['country_code'],
  'originRegion': row['origin_region'],
  'createdAt': row['created_at'],
  'memberCount': row['member_count'] ?? 0,
  'permissions': (row['permissions'] as Map?)?.cast<String, dynamic>() ?? {},
  'isOfficial': row['is_official'] ?? false,
};

class GroupSupabaseDataSource implements GroupRemoteDataSource {
  final SupabaseClient _supabase;

  GroupSupabaseDataSource({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ═══════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════

  @override
  Future<List<GroupModel>> getGroups() async {
    final data = await _supabase
        .from('groups')
        .select()
        .eq('is_private', false)
        .order('member_count', ascending: false)
        .limit(50);
    return (data as List).map((r) => GroupModel.fromJson(_mapGroup(r))).toList();
  }

  @override
  Future<List<GroupModel>> getGroupsByCategory(String category) async {
    final data = await _supabase
        .from('groups')
        .select()
        .eq('category', category)
        .eq('is_private', false)
        .order('member_count', ascending: false)
        .limit(50);
    return (data as List).map((r) => GroupModel.fromJson(_mapGroup(r))).toList();
  }

  @override
  Future<GroupModel> getGroupById(String groupId) async {
    // Sans session Supabase authentifiée, RLS bloque la lecture → l'écran de
    // détails du groupe (ouvert depuis une conversation, sans initialGroup)
    // restait en chargement infini.
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    final data = await _supabase.from('groups').select().eq('id', groupId).single();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return GroupModel.fromJson(_mapGroup(data));

    final membership = await _supabase
        .from('group_members')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (membership == null) return GroupModel.fromJson(_mapGroup(data));

    final role = membership['role'] as String?;
    final patchedRow = Map<String, dynamic>.from(data);
    final members = List<String>.from((data['member_ids'] as List?) ?? []);
    final admins = List<String>.from((data['admin_ids'] as List?) ?? []);
    if (!members.contains(userId)) members.add(userId);
    if ((role == 'owner' || role == 'admin') && !admins.contains(userId)) {
      admins.add(userId);
    }
    patchedRow['member_ids'] = members;
    patchedRow['admin_ids'] = admins;
    return GroupModel.fromJson(_mapGroup(patchedRow));
  }

  Future<GroupModel?> getGroupByName(String name) async {
    final data = await _supabase
        .from('groups')
        .select()
        .ilike('name', name)
        .limit(1);
    if ((data as List).isEmpty) return null;
    return GroupModel.fromJson(_mapGroup(data.first));
  }

  @override
  Stream<GroupModel?> getGroupStream(String groupId) async* {
    // Session d'abord : un .stream() créé en anon fait son fetch initial sous
    // RLS sans droits → 0 ligne pour toujours (groupe « introuvable », écran
    // de détails en chargement infini, permissions par défaut).
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    yield* _supabase
        .from('groups')
        .stream(primaryKey: ['id'])
        .eq('id', groupId)
        .map((rows) => rows.isEmpty ? null : GroupModel.fromJson(_mapGroup(rows.first)));
  }

  @override
  Future<List<GroupModel>> getMyGroups(String userId) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();

    // SECURITY DEFINER RPC — returns JSONB to bypass PostgREST schema column selection
    final raw = await _supabase.rpc('get_my_groups');
    final rows = raw is List ? raw : [];

    if (rows.isEmpty) return [];

    // Fetch roles from group_members to patch memberIds/adminIds
    Map<String, String> roleMap = {};
    try {
      final memberships = await _supabase
          .from('group_members')
          .select('group_id, role')
          .eq('user_id', userId) as List;
      roleMap = {for (final m in memberships) m['group_id'] as String: m['role'] as String};
    } catch (_) {}

    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      final groupId = row['id'] as String;
      final role = roleMap[groupId] ?? (row['creator_id'] == userId ? 'owner' : 'member');
      final patchedRow = Map<String, dynamic>.from(row);
      final members = List<String>.from((row['member_ids'] as List?) ?? []);
      final admins = List<String>.from((row['admin_ids'] as List?) ?? []);
      if (!members.contains(userId)) members.add(userId);
      if ((role == 'owner' || role == 'admin') && !admins.contains(userId)) {
        admins.add(userId);
      }
      patchedRow['member_ids'] = members;
      patchedRow['admin_ids'] = admins;
      return GroupModel.fromJson(_mapGroup(patchedRow));
    }).toList();
  }

  @override
  Future<List<GroupModel>> searchGroups(String query) async {
    final data = await _supabase
        .from('groups')
        .select()
        .ilike('name', '%$query%')
        .eq('is_private', false)
        .limit(30);
    return (data as List).map((r) => GroupModel.fromJson(_mapGroup(r))).toList();
  }

  // ═══════════════════════════════════════════
  // WRITE
  // ═══════════════════════════════════════════

  @override
  Future<GroupModel> createGroup(GroupModel group) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }

    final row = await _supabase.rpc('insert_group', params: {
      'p_name': group.name,
      'p_description': group.description,
      'p_avatar_url': group.imageUrl,
      'p_creator_name': group.creatorName,
      'p_category': group.category,
      'p_is_private': group.isPrivate,
      'p_group_location': group.location,
      'p_tags': group.tags,
      'p_country_code': group.country,
      'p_origin_region': group.originRegion,
    },) as Map<String, dynamic>?;

    if (row == null) throw ServerException('insert_group returned no data');

    // The RPC returns only the groups table row — member_ids/admin_ids are not
    // aggregated. Patch them with the creator since the RPC inserts them as 'owner'.
    final userId = _supabase.auth.currentUser?.id;
    final patchedRow = Map<String, dynamic>.from(row);
    if (userId != null) {
      patchedRow['member_ids'] = [userId];
      patchedRow['admin_ids'] = [userId];
    }

    return GroupModel.fromJson(_mapGroup(patchedRow));
  }

  @override
  Future<GroupModel> updateGroup(GroupModel group) async {
    final data = await _supabase
        .from('groups')
        .update({
          'name': group.name,
          'description': group.description,
          'avatar_url': group.imageUrl,
          'category': group.category,
          'is_private': group.isPrivate,
          'group_location': group.location,
          'tags': group.tags,
          'permissions': group.permissions,
          'moderator_ids': group.moderatorIds,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', group.id)
        .select()
        .single();
    return GroupModel.fromJson(_mapGroup(data));
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _supabase.rpc('delete_group', params: {'p_group_id': groupId});
  }

  @override
  Future<void> joinGroup(String groupId, String userId) async {
    await _supabase.from('group_members').upsert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
    }, onConflict: 'group_id,user_id',);
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    await _supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await leaveGroup(groupId, userId);
  }

  // System messages sont gérés via Firestore (messaging feature non migrée)
  @override
  Future<void> sendPromotedSystemMessage(String groupId, String userId) async {}

  @override
  Future<void> sendDemotedSystemMessage(String groupId, String userId) async {}

  @override
  Future<void> sendGroupRenamedSystemMessage(String groupId, String newName) async {}

  Stream<List<GroupPinnedItemModel>> getPinnedItemsStream({
    String? groupId,
    String? conversationId,
  }) async* {
    assert(groupId != null || conversationId != null);
    // Session d'abord (voir getGroupStream) : sinon RLS anon = bandeau
    // épinglé définitivement vide.
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    final column = groupId != null ? 'group_id' : 'conversation_id';
    final value = groupId ?? conversationId!;
    yield* _supabase
        .from('group_pinned_items')
        .stream(primaryKey: ['id'])
        .eq(column, value)
        .order('sort_order')
        .map((rows) => rows.map(GroupPinnedItemModel.fromJson).toList());
  }

  Future<GroupPinnedItemModel> pinItem({
    String? groupId,
    String? conversationId,
    required String itemType,
    required String itemId,
    required String pinnedBy,
  }) async {
    assert(groupId != null || conversationId != null);
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final row = await _supabase
        .from('group_pinned_items')
        .insert({
          'group_id': groupId,
          'conversation_id': conversationId,
          'item_type': itemType,
          'item_id': itemId,
          'pinned_by': pinnedBy,
        })
        .select()
        .single();
    return GroupPinnedItemModel.fromJson(row);
  }

  @override
  Future<GroupModel> ensureOfficialGroup({
    required String countryCode,
    required String countryName,
  }) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final row = await _supabase.rpc(
      'get_or_create_official_group',
      params: {
        'p_country_code': countryCode,
        'p_country_name': countryName,
      },
    );
    return GroupModel.fromJson(_mapGroup(row as Map<String, dynamic>));
  }

  Future<void> unpinItem(String pinnedItemId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    await _supabase.from('group_pinned_items').delete().eq('id', pinnedItemId);
  }
}
