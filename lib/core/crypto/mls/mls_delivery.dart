
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

  /// Posé par l'expéditeur avec le contrôle `edit`. Un appareil qui n'a pas
  /// reçu ce contrôle — arrivé après, réinstallé — affiche quand même
  /// « modifié » sous le texte d'origine, plutôt que de faire passer une
  /// version périmée pour la dernière.
  final DateTime? editedAt;
  final DateTime createdAt;

  /// Échéance du minuteur, telle que le service de livraison la voit — une
  /// **aide au balayage**, jamais une autorité : la durée qui fait foi
  /// voyage dans le payload chiffré (`MlsPayload.ttl`), hors de sa portée.
  final DateTime? expiresAt;

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
    this.editedAt,
    required this.createdAt,
    this.expiresAt,
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
        editedAt: DateTime.tryParse(r['edited_at'] as String? ?? ''),
        createdAt: DateTime.parse(r['created_at'] as String),
        expiresAt: r['expires_at'] is String
            ? DateTime.tryParse(r['expires_at'] as String)
            : null,
      );

  /// La même ligne, avec l'horodatage que le serveur lui a donné.
  ///
  /// [createdAt] est fabriqué localement au moment d'émettre, parce que
  /// [toInsert] n'envoie pas `created_at` — la colonne a son défaut serveur.
  /// Ce que le serveur a retenu ne se sait qu'au retour de l'insertion :
  /// c'est là qu'on recolle la vraie valeur, et nulle part ailleurs.
  MlsMessageRow avecCreatedAt(DateTime quand) => MlsMessageRow(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderDeviceId: senderDeviceId,
        epoch: epoch,
        kind: kind,
        contentType: contentType,
        ciphertext: ciphertext,
        replyToId: replyToId,
        isDeleted: isDeleted,
        editedAt: editedAt,
        createdAt: quand,
        expiresAt: expiresAt,
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
        if (expiresAt != null)
          'expires_at': expiresAt!.toUtc().toIso8601String(),
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
        .select('id, type, participant_ids, mls_since, data')
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

    // **On relit, et on lève si la date n'est pas là.**
    //
    // Compter les lignes touchées ne suffirait pas : zéro ligne veut dire
    // « déjà posée » — le cas idempotent, parfaitement normal — **ou** « le
    // serveur a refusé ». Un `update` que le RLS écarte ne lève pas, il touche
    // zéro ligne sans un mot. Seule la relecture sépare les deux.
    //
    // Ce que coûterait le silence : le groupe MLS vient d'être créé et le
    // message suivant part chiffré, mais sans `mls_since` le serveur continue
    // d'accepter du clair dans la même conversation. Elle se retrouverait à
    // cheval sur les deux chemins, sans séparateur et sans gel — un état que
    // rien ne rattrape ensuite, puisque la date est définitive une fois posée.
    final ligne = await _client
        .from('conversations')
        .select('mls_since')
        .eq('id', conversationId)
        .maybeSingle();
    if (ligne?['mls_since'] == null) {
      throw StateError('bascule non enregistrée pour $conversationId');
    }
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

  /// Insère le message et rend l'horodatage que **le serveur** lui a donné.
  ///
  /// `toInsert` n'envoie pas `created_at` : la colonne a son défaut serveur.
  /// Sans ce retour, l'expéditeur gardait sa propre heure pour une ligne que
  /// le serveur avait datée autrement — deux valeurs pour le même message,
  /// écartées de la latence d'envoi, et rien pour dire laquelle fait foi.
  ///
  /// Ce que cet écart coûte, aux deux endroits qui comptent dessus :
  ///
  ///   - **l'échéance d'un message éphémère**, que `MlsMessageMapper` compte
  ///     depuis `row.createdAt` en disant, juste à côté, que c'est « le seul
  ///     horodatage que l'expéditeur ne choisit pas ». Pour ses propres
  ///     messages, l'expéditeur le choisissait — et une horloge de téléphone
  ///     décalée de quelques minutes, ce qui est banal, décalait d'autant la
  ///     durée de vie réelle de la note.
  ///   - **l'aperçu de la liste des discussions**, qui n'a que l'horodatage
  ///     pour reconnaître dans le cache local le message que le serveur
  ///     annonce comme le dernier. La latence seule ne suffisait pas à le
  ///     casser — `MessageRepositoryImpl.apercuDepuisCache` tronque à la
  ///     seconde, donc tolère l'aller-retour — mais un décalage d'horloge le
  ///     casse, et la discussion retombe alors sur son libellé de type
  ///     jusqu'au prochain rechargement du fil en ligne.
  ///
  /// La garde d'aperçu, elle, ne bouge pas : elle refuse un message caché qui
  /// n'est pas le dernier, et elle a raison de le faire — un aperçu faux
  /// serait pire qu'un libellé générique. C'est la valeur écrite qu'on
  /// corrige, pas la comparaison.
  ///
  /// L'insertion et la relecture forment une seule requête PostgREST, donc
  /// une seule transaction : pas de message inséré sans réponse de plus
  /// qu'avant. `null` seulement si le serveur ne rend rien — l'appelant garde
  /// alors son heure locale, comme avant, et n'y perd que l'aperçu.
  ///
  /// **Pas de `maybeSingle()` ici, et ce n'est pas un oubli.** Sur un POST, il
  /// remplace l'`Accept` par `application/vnd.pgrst.object+json` pour réclamer
  /// un objet nu, et sa correction de forme (« body is List » dans
  /// `postgrest_builder`) ne couvre que les GET. Une réponse en tableau lève
  /// donc un `type 'List<dynamic>' is not a subtype of 'Map'` — trouvé par
  /// `mls_publish_created_at_test.dart` avant que ça ne parte sur un
  /// téléphone. Ce serait un échec d'envoi annoncé pour un message **déjà
  /// inséré**, donc un doublon à la reprise, pour un horodatage dont on sait
  /// se passer. La forme liste n'a aucune de ces arêtes : zéro ligne est une
  /// liste vide, pas un 406 rattrapé.
  ///
  /// Rien ici ne lève sur une réponse inattendue : la relecture est un
  /// confort, l'insertion est le contrat.
  Future<DateTime?> publishMessage(MlsMessageRow row) async {
    await _auth();
    final rendu = await _client
        .from('mls_messages')
        .insert(row.toInsert())
        .select('created_at');
    final quand = rendu.isEmpty ? null : rendu.first['created_at'];
    return quand is String ? DateTime.tryParse(quand)?.toUtc() : null;
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
