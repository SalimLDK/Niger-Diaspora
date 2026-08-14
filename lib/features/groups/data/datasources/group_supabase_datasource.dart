import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/models/country.dart';
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
  // APPARTENANCE
  // ═══════════════════════════════════════════

  /// Lit l'appartenance réelle depuis `group_members` pour les groupes donnés.
  ///
  /// La colonne `groups.member_ids` est **NULL sur toutes les lignes** et
  /// `groups.member_count` n'est pas tenu à jour : un groupe avec un membre
  /// réel s'affichait « Membres · 0 », et « Rejoindre le groupe » était
  /// proposé à quelqu'un qui en faisait déjà partie. Les deux se déduisent
  /// donc de la table d'appartenance, seule source vraie.
  ///
  /// Une seule requête pour toute la liste : compter groupe par groupe ferait
  /// un N+1 sur les écrans de découverte.
  Future<Map<String, ({List<String> members, List<String> admins})>>
      _membershipFor(List<String> groupIds) async {
    if (groupIds.isEmpty) return const {};
    try {
      final rows = await _supabase
          .from('group_members')
          .select('group_id, user_id, role')
          .inFilter('group_id', groupIds) as List;

      final members = <String, List<String>>{};
      final admins = <String, List<String>>{};
      for (final r in rows) {
        final gid = r['group_id'] as String?;
        final uid = r['user_id'] as String?;
        if (gid == null || uid == null) continue;
        (members[gid] ??= <String>[]).add(uid);
        final role = r['role'] as String?;
        if (role == 'owner' || role == 'admin') {
          (admins[gid] ??= <String>[]).add(uid);
        }
      }
      return {
        for (final gid in groupIds)
          gid: (
            members: members[gid] ?? const <String>[],
            admins: admins[gid] ?? const <String>[],
          ),
      };
    } catch (_) {
      // Appartenance illisible (RLS, réseau) : on rend les lignes telles
      // quelles plutôt que de faire disparaître les groupes.
      return const {};
    }
  }

  /// Applique l'appartenance réelle à une ligne `groups` avant décodage.
  Map<String, dynamic> _withMembership(
    Map<String, dynamic> row,
    Map<String, ({List<String> members, List<String> admins})> membership,
  ) {
    final gid = row['id'] as String?;
    final entry = gid == null ? null : membership[gid];
    if (entry == null) return row;
    final patched = Map<String, dynamic>.from(row);
    patched['member_ids'] = entry.members;
    if (entry.admins.isNotEmpty) patched['admin_ids'] = entry.admins;
    // `member_count` de la table n'est volontairement pas repris :
    // `GroupEntity.memberCount` est un getter sur `memberIds.length`, donc le
    // compte suit l'appartenance et ne peut plus la contredire.
    return patched;
  }

  /// Décode une liste de lignes `groups` en y injectant l'appartenance réelle.
  Future<List<GroupModel>> _decodeWithMembership(List rows) async {
    final ids = [
      for (final r in rows)
        if ((r as Map)['id'] is String) r['id'] as String,
    ];
    final membership = await _membershipFor(ids);
    return rows
        .map(
          (r) => GroupModel.fromJson(
            _mapGroup(
              _withMembership(Map<String, dynamic>.from(r as Map), membership),
            ),
          ),
        )
        .toList();
  }

  // ═══════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════

  @override
  Future<List<GroupModel>> getGroups() async {
    // Comme partout ailleurs dans ce fichier : sans session Supabase établie,
    // la lecture part en anonyme et RLS renvoie zéro ligne. L'onglet
    // « Découvrir » affichait alors « Aucun groupe public pour l'instant »
    // alors que la base en contenait — un état vide qui ment.
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    final data = await _supabase
        .from('groups')
        .select()
        .eq('is_private', false)
        .order('member_count', ascending: false)
        .limit(50);
    return _decodeWithMembership(data as List);
  }

  @override
  Future<List<GroupModel>> getGroupsByCategory(String category) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    final data = await _supabase
        .from('groups')
        .select()
        .eq('category', category)
        .eq('is_private', false)
        .order('member_count', ascending: false)
        .limit(50);
    return _decodeWithMembership(data as List);
  }

  @override
  Future<GroupModel> getGroupById(String groupId) async {
    // Sans session Supabase authentifiée, RLS bloque la lecture → l'écran de
    // détails du groupe (ouvert depuis une conversation, sans initialGroup)
    // restait en chargement infini.
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    final data = await _supabase.from('groups').select().eq('id', groupId).single();

    // L'appartenance vient de `group_members`, pour **tous** les membres et
    // pas seulement pour soi : la fiche 9d affiche un compte et une liste, et
    // ne rapiécer que sa propre ligne donnait « Membres · 0 » au-dessus d'un
    // membre bien affiché.
    final membership = await _membershipFor([groupId]);
    return GroupModel.fromJson(
      _mapGroup(_withMembership(Map<String, dynamic>.from(data), membership)),
    );
  }

  Future<GroupModel?> getGroupByName(String name) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
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
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          // Comme getGroupById : `groups.member_ids`/`admin_ids` sont NULL en
          // base, seule `group_members` fait foi. Sans ce correctif, la fiche
          // groupe atteinte SANS `initialGroup` (ex. depuis l'en-tête de la
          // conversation) affichait « Membres · 0 » et « Rejoindre le groupe »
          // à des membres réels — le flux réactif écrasait en permanence la
          // lecture ponctuelle correcte de `groupDetailNotifierProvider` via
          // le `??` de `GroupDetailScreen`.
          final membership = await _membershipFor([groupId]);
          return GroupModel.fromJson(
            _mapGroup(
              _withMembership(Map<String, dynamic>.from(rows.first), membership),
            ),
          );
        });
  }

  @override
  Future<List<GroupModel>> getMyGroups(String userId) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();

    // SECURITY DEFINER RPC — returns JSONB to bypass PostgREST schema column selection
    final raw = await _supabase.rpc('get_my_groups');
    final rows = raw is List ? raw : [];

    if (rows.isEmpty) return [];

    final groups = await _decodeWithMembership(rows);

    // `get_my_groups` ne renvoie que des groupes dont on est membre : si
    // l'appartenance n'a pas pu être lue (RLS, réseau), on s'y ajoute quand
    // même, sinon « Mes groupes » proposerait « Rejoindre » sur ses propres
    // groupes.
    return groups
        .map(
          (g) =>
              g.memberIds.contains(userId)
                  ? g
                  : g.copyWith(memberIds: [...g.memberIds, userId]),
        )
        .toList();
  }

  @override
  Future<List<GroupModel>> searchGroups(String query) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    final data = await _supabase
        .from('groups')
        .select()
        .ilike('name', '%$query%')
        .eq('is_private', false)
        // `limit(30)` sans `order` rendait 30 groupes **arbitraires** :
        // Postgres ne promet aucun ordre sans ORDER BY. Deux recherches
        // identiques pouvaient donc donner deux listes différentes, et passé
        // 30 correspondances les mêmes groupes pouvaient rester introuvables
        // pour toujours.
        //
        // Tri sur le champ **filtré**, donc garanti présent dans chaque
        // résultat. `member_count` aurait mis les groupes vivants en tête,
        // mais ce compteur a déjà dérivé par le passé (un commit existe pour
        // le recaler) : trier dessus ferait dépendre la visibilité d'un
        // groupe d'une valeur dénormalisée. Le nom, lui, est ce qu'on vient
        // de chercher.
        .order('name')
        .limit(30);
    return _decodeWithMembership(data as List);
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
      // Point de passage unique de toute création côté app : un groupe sans
      // pays serait invisible dans « Découvrir » dès qu'un filtre pays est
      // actif, et l'écran en pose un tout seul. Le défaut est aussi posé côté
      // base (`insert_group`, et le `DEFAULT` de la colonne) pour les écrivains
      // qui ne passeraient pas par ici.
      'p_country_code': group.country?.trim().isNotEmpty == true
          ? group.country
          : kDefaultCountryCode,
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
    // Sans ça, la personne restait participante de la conversation du
    // groupe indéfiniment après son départ (accès en lecture aux messages
    // envoyés après coup) : `group_members` et `conversations.participant_ids`
    // sont deux tables distinctes, ce DELETE ne touche que la première. La
    // RPC agit sur l'appelant authentifié (firebase_uid), jamais sur `userId`
    // fourni par le client — cohérent avec le fait que `leaveGroup` n'est
    // appelé aujourd'hui qu'avec `currentUser.id`.
    await _supabase.rpc('leave_group_conversation', params: {
      'p_group_id': groupId,
    });
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
