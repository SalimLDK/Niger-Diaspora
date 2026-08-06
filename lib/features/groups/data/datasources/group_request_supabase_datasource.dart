import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/group_invite_model.dart';
import '../models/group_request_model.dart';
import 'group_request_datasource.dart';

class GroupRequestSupabaseDataSource implements GroupRequestDataSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  // ── JOIN REQUESTS ──────────────────────────────────────────────────────────

  @override
  Future<void> requestToJoinGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String requesterId,
    required String requesterName,
    String? requesterPhotoUrl,
    String? message,
  }) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      // Appartenance lue dans `group_members`, pas dans `groups.member_ids` :
      // cette colonne est vide sur toutes les lignes et le chargement la
      // recalcule depuis `group_members`. Le garde ne se declenchait donc
      // jamais, et un membre pouvait redemander a rejoindre son propre groupe.
      final memberRow = await _supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId)
          .eq('user_id', requesterId)
          .maybeSingle();

      if (memberRow != null) {
        throw ServerException('Vous êtes déjà membre de ce groupe');
      }

      await _supabase.from('group_requests').upsert({
        'group_id': groupId,
        'group_name': groupName,
        'group_image_url': groupImageUrl,
        'requester_id': requesterId,
        'requester_name': requesterName,
        'requester_photo_url': requesterPhotoUrl,
        'status': 'pending',
        'message': message,
      }, onConflict: 'group_id,requester_id',);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> approveJoinRequest(String requestId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      // Statut + appartenance en une transaction cote base.
      //
      // La version precedente faisait trois allers-retours et se trompait sur
      // les deux points qui comptent : `processed_by` recevait l'uid Supabase
      // (un uuid) alors que la colonne et les policies parlent en uid Firebase,
      // et le nouveau membre etait ecrit dans `groups.member_ids`, colonne que
      // le chargement recalcule depuis `group_members` -- approuver
      // n'ajoutait personne. La fonction verifie elle-meme que l'appelant est
      // admin du groupe (migration 20260806180000).
      await _supabase.rpc(
        'approve_group_request',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> rejectJoinRequest(String requestId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      // Meme fonction miroir que l'approbation, pour que `processed_by` soit
      // resolu au meme endroit et dans le meme referentiel d'identite.
      await _supabase.rpc(
        'reject_group_request',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> cancelJoinRequest(String requestId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase.from('group_requests').delete().eq('id', requestId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<GroupRequestModel>> getPendingRequests(String groupId) {
    return _supabase
        .from('group_requests')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .map(
          (rows) => rows
              .where((r) => r['status'] == 'pending')
              .map(_requestFromRow)
              .toList(),
        );
  }

  @override
  Stream<List<GroupRequestModel>> getMyGroupRequests(String userId) {
    return _supabase
        .from('group_requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', userId)
        .map((rows) => rows.map(_requestFromRow).toList());
  }

  // ── INVITES ────────────────────────────────────────────────────────────────

  @override
  Future<void> inviteUserToGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String inviterId,
    required String inviterName,
    required String inviteeId,
    required String inviteeName,
    String? inviteePhotoUrl,
  }) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase.from('group_invites').upsert({
        'group_id': groupId,
        'group_name': groupName,
        'group_image_url': groupImageUrl,
        'inviter_id': inviterId,
        'inviter_name': inviterName,
        'invitee_id': inviteeId,
        'invitee_name': inviteeName,
        'invitee_photo_url': inviteePhotoUrl,
        'status': 'pending',
      }, onConflict: 'group_id,invitee_id',);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> acceptGroupInvite(String inviteId) async {
    try {
      // RLS bloque toute écriture en session anonyme : garantir la session
      // Supabase avant d'accepter (sinon l'update échoue silencieusement).
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final row = await _supabase
          .from('group_invites')
          .select('group_id, invitee_id')
          .eq('id', inviteId)
          .single();

      final groupId = row['group_id'] as String;
      final inviteeId = row['invitee_id'] as String;

      await _supabase.from('group_invites').update({
        'status': 'accepted',
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', inviteId);

      // Appartenance ecrite dans `group_members`, comme `joinGroup` : c'est la
      // seule source lue au chargement, et le trigger de comptage y est
      // accroche. L'ecriture precedente dans `groups.member_ids` n'ajoutait
      // personne. Pas de fonction SECURITY DEFINER ici : l'invite s'inscrit
      // lui-meme, ce que la policy `group_members_own` autorise deja.
      await _supabase.from('group_members').upsert({
        'group_id': groupId,
        'user_id': inviteeId,
        'role': 'member',
      }, onConflict: 'group_id,user_id',);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> declineGroupInvite(String inviteId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase.from('group_invites').update({
        'status': 'declined',
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', inviteId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> cancelGroupInvite(String inviteId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase.from('group_invites').delete().eq('id', inviteId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<GroupInviteModel>> getReceivedInvites(String userId) {
    return _supabase
        .from('group_invites')
        .stream(primaryKey: ['id'])
        .eq('invitee_id', userId)
        .map(
          (rows) => rows
              .where((r) => r['status'] == 'pending')
              .map(_inviteFromRow)
              .toList(),
        );
  }

  @override
  Stream<List<GroupInviteModel>> getSentInvites(String groupId) {
    return _supabase
        .from('group_invites')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .map((rows) => rows.map(_inviteFromRow).toList());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  GroupRequestModel _requestFromRow(Map<String, dynamic> row) {
    return GroupRequestModel.fromJson({
      'id': row['id'],
      'groupId': row['group_id'],
      'groupName': row['group_name'],
      'groupImageUrl': row['group_image_url'],
      'requesterId': row['requester_id'],
      'requesterName': row['requester_name'],
      'requesterPhotoUrl': row['requester_photo_url'],
      'status': row['status'],
      'message': row['message'],
      'createdAt': row['created_at'],
      'processedAt': row['processed_at'],
      'processedBy': row['processed_by'],
    });
  }

  GroupInviteModel _inviteFromRow(Map<String, dynamic> row) {
    return GroupInviteModel.fromJson({
      'id': row['id'],
      'groupId': row['group_id'],
      'groupName': row['group_name'],
      'groupImageUrl': row['group_image_url'],
      'inviterId': row['inviter_id'],
      'inviterName': row['inviter_name'],
      'inviteeId': row['invitee_id'],
      'inviteeName': row['invitee_name'],
      'inviteePhotoUrl': row['invitee_photo_url'],
      'status': row['status'],
      'createdAt': row['created_at'],
      'respondedAt': row['responded_at'],
    });
  }
}
