
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_auth_bridge.dart';
import 'bytea.dart';
import 'mls_device_registry.dart';

/// Un commit publié : l'epoch qu'il produit, et qui l'a émis.
class MlsCommitRow {
  final String conversationId;
  final int epoch;
  final String senderDeviceId;
  final Uint8List commit;
  final Uint8List? groupInfo;
  final DateTime createdAt;

  const MlsCommitRow({
    required this.conversationId,
    required this.epoch,
    required this.senderDeviceId,
    required this.commit,
    this.groupInfo,
    required this.createdAt,
  });

  factory MlsCommitRow.fromRow(Map<String, dynamic> r) => MlsCommitRow(
        conversationId: r['conversation_id'] as String,
        epoch: (r['epoch'] as num).toInt(),
        senderDeviceId: r['sender_device_id'] as String,
        commit: depuisBytea(r['commit'] as String),
        groupInfo: r['group_info'] is String ? depuisBytea(r['group_info'] as String) : null,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class MlsWelcomeRow {
  final String id;
  final String conversationId;
  final String recipientDeviceId;
  final int epoch;
  final Uint8List welcome;
  final DateTime? consumedAt;

  const MlsWelcomeRow({
    required this.id,
    required this.conversationId,
    required this.recipientDeviceId,
    required this.epoch,
    required this.welcome,
    this.consumedAt,
  });

  factory MlsWelcomeRow.fromRow(Map<String, dynamic> r) => MlsWelcomeRow(
        id: r['id'] as String,
        conversationId: r['conversation_id'] as String,
        recipientDeviceId: r['recipient_device_id'] as String,
        epoch: (r['epoch'] as num).toInt(),
        welcome: depuisBytea(r['welcome'] as String),
        consumedAt: DateTime.tryParse(r['consumed_at'] as String? ?? ''),
      );
}

class MlsMessageRow {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderDeviceId;
  final int epoch;
  final String kind;
  final String contentType;
  final Uint8List ciphertext;
  final String? replyToId;
  final bool isDeleted;
  final DateTime createdAt;

  const MlsMessageRow({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderDeviceId,
    required this.epoch,
    required this.kind,
    required this.contentType,
    required this.ciphertext,
    this.replyToId,
    this.isDeleted = false,
    required this.createdAt,
  });

  factory MlsMessageRow.fromRow(Map<String, dynamic> r) => MlsMessageRow(
        id: r['id'] as String,
        conversationId: r['conversation_id'] as String,
        senderId: r['sender_id'] as String,
        senderDeviceId: r['sender_device_id'] as String,
        epoch: (r['epoch'] as num).toInt(),
        kind: r['kind'] as String,
        contentType: r['content_type'] as String,
        ciphertext: depuisBytea(r['ciphertext'] as String),
        replyToId: r['reply_to_id'] as String?,
        isDeleted: r['is_deleted'] == true,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  Map<String, dynamic> toInsert() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_device_id': senderDeviceId,
        'epoch': epoch,
        'kind': kind,
        'content_type': contentType,
        'ciphertext': versBytea(ciphertext),
        if (replyToId != null) 'reply_to_id': replyToId,
      };
}

/// Un KeyPackage réclamé par `claim_key_package`.
class MlsKeyPackageClaim {
  final String id;
  final String deviceId;
  final Uint8List keyPackage;
  final bool isLastResort;

  const MlsKeyPackageClaim({
    required this.id,
    required this.deviceId,
    required this.keyPackage,
    required this.isLastResort,
  });
}

/// Deux commits pour le même epoch : le serveur a pris l'autre.
class EpochConflict implements Exception {
  final String conversationId;
  final int epoch;
  const EpochConflict(this.conversationId, this.epoch);

  @override
  String toString() => 'EpochConflict($conversationId, $epoch)';
}

/// Le transport MLS : les tables, rien que les tables. Aucune cryptographie
/// ici — un ciphertext entre, un ciphertext sort.
///
/// Toute lecture passe par `ensureAuthenticated()` : sous `anon`, PostgREST
/// rend 0 ligne **sans erreur**, et l'app conclurait qu'il n'y a rien à
/// traiter (7e forme des échecs muets de Supabase).
class MlsDelivery {
  MlsDelivery({SupabaseClient? client, Future<bool> Function()? ensureAuth})
      : _clientOptionnel = client,
        _ensureAuth = ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated;

  final SupabaseClient? _clientOptionnel;
  final Future<bool> Function() _ensureAuth;

  SupabaseClient get _client => _clientOptionnel ?? Supabase.instance.client;

  Future<void> _auth() async {
    if (!await _ensureAuth()) throw StateError('Session non établie');
  }

  // ── Conversations et appareils ───────────────────────────────────────────

  Future<Map<String, dynamic>?> conversation(String conversationId) async {
    await _auth();
    return _client
        .from('conversations')
        .select('id, type, participant_ids, mls_since')
        .eq('id', conversationId)
        .maybeSingle();
  }

  /// Pose `mls_since` si absent. Idempotent ; le trigger refuse toute
  /// modification ultérieure.
  Future<void> marquerMlsSince(String conversationId) async {
    await _auth();
    await _client
        .from('conversations')
        .update({'mls_since': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId)
        .isFilter('mls_since', null);
  }

  Future<List<MlsDeviceRecord>> activeDevicesOf(String userId) async {
    await _auth();
    final rows = await _client
        .from('mls_devices')
        .select()
        .eq('user_id', userId)
        .isFilter('revoked_at', null);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => MlsDeviceRecord.fromRow(r))
        .toList();
  }

  Future<MlsKeyPackageClaim?> claimKeyPackage(String deviceId) async {
    await _auth();
    final r = await _client.rpc('claim_key_package', params: {'p_device_id': deviceId});
    if (r is! Map || r['id'] == null) return null;
    final m = Map<String, dynamic>.from(r);
    return MlsKeyPackageClaim(
      id: m['id'] as String,
      deviceId: m['device_id'] as String,
      keyPackage: depuisBytea(m['key_package'] as String),
      isLastResort: m['is_last_resort'] == true,
    );
  }

  Future<void> upsertConversationDevice(
    String conversationId,
    String deviceId,
    String status, {
    int? epochAdded,
    int? epochRemoved,
  }) async {
    await _auth();
    await _client.from('conversation_devices').upsert({
      'conversation_id': conversationId,
      'device_id': deviceId,
      'status': status,
      if (epochAdded != null) 'epoch_added': epochAdded,
      if (epochRemoved != null) 'epoch_removed': epochRemoved,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'conversation_id,device_id');
  }

  // ── Commits ──────────────────────────────────────────────────────────────

  /// Lève [EpochConflict] si un autre commit occupe déjà cet epoch.
  Future<void> publishCommit({
    required String conversationId,
    required int epoch,
    required String senderDeviceId,
    required Uint8List commit,
    Uint8List? groupInfo,
  }) async {
    await _auth();
    try {
      await _client.from('mls_commits').insert({
        'conversation_id': conversationId,
        'epoch': epoch,
        'sender_device_id': senderDeviceId,
        'commit': versBytea(commit),
        if (groupInfo != null) 'group_info': versBytea(groupInfo),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw EpochConflict(conversationId, epoch);
      rethrow;
    }
  }

  /// Publie l'arbre public du groupe (§ 5.7), celui de l'epoch courant.
  ///
  /// Écrit par le dernier committeur, lu par un arrivant qui rejoint un
  /// groupe ouvert. Aucun secret : c'est un arbre de clés publiques.
  Future<void> publierGroupInfo(String conversationId, Uint8List groupInfo) async {
    await _auth();
    try {
      await _client
          .from('conversations')
          .update({'mls_group_info': versBytea(groupInfo)})
          .eq('id', conversationId);
    } catch (e) {
      // Même raison que pour la lecture : tant que la colonne n'existe pas,
      // ne rien publier coûte une jointure externe, pas un message.
      debugPrint('MlsDelivery: arbre public non publié ($e)');
    }
  }

  /// L'arbre public publié pour cette conversation, s'il y en a un.
  ///
  /// Requête **séparée**, et tolérante à son propre échec : `mls_group_info`
  /// est une colonne récente, et la mettre dans le select principal ferait
  /// échouer la requête entière tant que la migration n'est pas appliquée —
  /// donc chaque envoi de message, pour une colonne qui ne sert qu'à une
  /// jointure externe. C'est la règle que ce dépôt a déjà payée côté Edge
  /// Functions.
  Future<Uint8List?> groupInfo(String conversationId) async {
    await _auth();
    try {
      final row = await _client
          .from('conversations')
          .select('mls_group_info')
          .eq('id', conversationId)
          .maybeSingle();
      final brut = row?['mls_group_info'] as String?;
      return brut == null ? null : depuisBytea(brut);
    } catch (e) {
      debugPrint('MlsDelivery: arbre public illisible ($e)');
      return null;
    }
  }

  Future<List<MlsCommitRow>> commitsAfter(String conversationId, int epoch) async {
    await _auth();
    final rows = await _client
        .from('mls_commits')
        .select()
        .eq('conversation_id', conversationId)
        .gt('epoch', epoch)
        .order('epoch', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>().map(MlsCommitRow.fromRow).toList();
  }

  /// Le plus haut epoch publié, `null` si la conversation n'a pas de groupe.
  Future<int?> currentEpoch(String conversationId) async {
    await _auth();
    final rows = await _client
        .from('mls_commits')
        .select('epoch')
        .eq('conversation_id', conversationId)
        .order('epoch', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return ((rows.first as Map)['epoch'] as num).toInt();
  }

  // ── Welcome ──────────────────────────────────────────────────────────────

  Future<void> publishWelcomes({
    required String conversationId,
    required int epoch,
    required Map<String, Uint8List> parAppareil,
  }) async {
    if (parAppareil.isEmpty) return;
    await _auth();
    await _client.from('mls_welcomes').insert([
      for (final e in parAppareil.entries)
        {
          'conversation_id': conversationId,
          'recipient_device_id': e.key,
          'epoch': epoch,
          'welcome': versBytea(e.value),
        },
    ]);
  }

  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async {
    await _auth();
    var q = _client
        .from('mls_welcomes')
        .select()
        .eq('recipient_device_id', deviceId)
        .isFilter('consumed_at', null);
    if (conversationId != null) q = q.eq('conversation_id', conversationId);
    final rows = await q.order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>().map(MlsWelcomeRow.fromRow).toList();
  }

  Future<void> markWelcomeConsumed(String id) async {
    await _auth();
    await _client
        .from('mls_welcomes')
        .update({'consumed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  Future<void> publishMessage(MlsMessageRow row) async {
    await _auth();
    await _client.from('mls_messages').insert(row.toInsert());
  }

  Future<List<MlsMessageRow>> messagesAfter(
    String conversationId,
    DateTime? after, {
    int limit = 200,
  }) async {
    await _auth();
    var q = _client.from('mls_messages').select().eq('conversation_id', conversationId);
    if (after != null) q = q.gt('created_at', after.toUtc().toIso8601String());
    final rows = await q.order('created_at', ascending: true).limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(MlsMessageRow.fromRow).toList();
  }

  // ── Diagnostics ──────────────────────────────────────────────────────────

  /// Un code et des compteurs. Jamais un octet de contenu.
  Future<void> diagnostic(
    String userId,
    String event, {
    String? deviceId,
    Map<String, dynamic>? detail,
  }) async {
    try {
      await _client.from('mls_diagnostics').insert({
        'user_id': userId,
        if (deviceId != null) 'device_id': deviceId,
        'event': event,
        if (detail != null) 'detail': detail,
      });
    } catch (e) {
      debugPrint('MlsDelivery: diagnostic non écrit ($e)');
    }
  }
}
