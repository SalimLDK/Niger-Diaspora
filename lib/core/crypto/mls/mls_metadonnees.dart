import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_auth_bridge.dart';

/// Les métadonnées d'un lot de messages MLS, telles que l'écran les attend.
///
/// Un seul objet pour les quatre tables : l'écran demande le fil d'un coup,
/// pas message par message.
@immutable
class MlsMetadonneesLot {
  /// `messageId` → (`userId` → emoji). Une réaction par personne.
  final Map<String, Map<String, String>> reactions;

  /// `messageId` → identifiants de ceux qui ont lu.
  final Map<String, List<String>> lecteurs;

  /// `messageId` → quand chacun a lu.
  final Map<String, Map<String, DateTime>> luA;

  /// `messageId` → identifiants de ceux à qui le message est parvenu.
  final Map<String, List<String>> destinataires;

  /// `messageId` → quand il leur est parvenu.
  final Map<String, Map<String, DateTime>> livreA;

  /// Messages que **moi seul** ai masqués (« supprimer pour moi »).
  final Set<String> masques;

  /// Messages que **moi seul** ai mis en favori.
  final Set<String> etoiles;

  /// Messages supprimés pour tous, par leur expéditeur.
  ///
  /// Relu à chaque passage, et pas seulement à l'arrivée du message : une
  /// suppression se décide après coup, et le cliquet ne repasse jamais sur
  /// un message déjà déchiffré. Sans ça, « supprimer pour tous » ne se
  /// verrait que chez celui qui l'a fait.
  final Set<String> supprimes;

  const MlsMetadonneesLot({
    this.reactions = const {},
    this.lecteurs = const {},
    this.luA = const {},
    this.destinataires = const {},
    this.livreA = const {},
    this.masques = const {},
    this.etoiles = const {},
    this.supprimes = const {},
  });

  static const vide = MlsMetadonneesLot();

  bool get estVide =>
      reactions.isEmpty &&
      lecteurs.isEmpty &&
      destinataires.isEmpty &&
      masques.isEmpty &&
      etoiles.isEmpty &&
      supprimes.isEmpty;
}

/// Les métadonnées en ligne des messages MLS (plan § 4, décision J).
///
/// **Pourquoi elles existent.** Neuf fonctionnalités de la messagerie ne sont
/// pas des messages : réactions, modification, suppression pour tous et pour
/// moi, reçus, non-lus, mentions, aperçu de la liste, favoris. Le legacy les
/// rangeait dans `messages.data`. Une conversation basculée n'a **aucune
/// ligne** dans `messages` : sans ces tables, réagir, supprimer ou accuser
/// réception ne touche rien — en silence.
///
/// **Ce que le serveur y apprend** est assumé (décision J) : qui a réagi et
/// avec quel emoji, qui a lu quoi et quand, qui a masqué ou étoilé, qui est
/// mentionné. Jamais le contenu d'un message. Le prix du multi-appareil :
/// sans ces lignes, un appareil réinstallé ne pourrait rien reconstituer,
/// n'ayant rejoué aucun message.
class MlsMetadonnees {
  MlsMetadonnees({
    required this.userId,
    SupabaseClient? client,
    Future<bool> Function()? ensureAuth,
  })  : _clientOptionnel = client,
        _ensureAuth = ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated;

  final String userId;
  final SupabaseClient? _clientOptionnel;
  final Future<bool> Function() _ensureAuth;

  SupabaseClient get _client => _clientOptionnel ?? Supabase.instance.client;

  /// Toute écriture Supabase passe par là : sans session établie, la requête
  /// part en `anon`, et le RLS la refuse **sans erreur** — 0 ligne touchée,
  /// aucune exception.
  Future<void> _auth() async {
    if (!await _ensureAuth()) throw StateError('Session non établie');
  }

  /// Au-delà, l'URL de la requête `in` devient déraisonnable. Le fil en
  /// charge 200 : deux tours.
  static const _parLot = 100;

  Iterable<List<String>> _lots(List<String> ids) sync* {
    for (var i = 0; i < ids.length; i += _parLot) {
      yield ids.sublist(i, i + _parLot > ids.length ? ids.length : i + _parLot);
    }
  }

  // ── Lecture ──────────────────────────────────────────────────────────────

  /// Les métadonnées des messages donnés, en quatre requêtes par lot.
  ///
  /// Un échec ne coûte pas le fil : il coûte les réactions et les coches, et
  /// se voit dans les journaux. Afficher un fil sans ses réactions vaut mieux
  /// que ne rien afficher.
  Future<MlsMetadonneesLot> pour(Iterable<String> messageIds) async {
    final ids = messageIds.toList(growable: false);
    if (ids.isEmpty) return MlsMetadonneesLot.vide;
    try {
      await _auth();
      final reactions = <String, Map<String, String>>{};
      final lecteurs = <String, List<String>>{};
      final luA = <String, Map<String, DateTime>>{};
      final destinataires = <String, List<String>>{};
      final livreA = <String, Map<String, DateTime>>{};
      final masques = <String>{};
      final etoiles = <String>{};
      final supprimes = <String>{};

      for (final lot in _lots(ids)) {
        final resultats = await Future.wait([
          _client.from('mls_message_reactions').select('message_id, user_id, emoji').inFilter('message_id', lot),
          _client
              .from('mls_message_receipts')
              .select('message_id, user_id, delivered_at, read_at')
              .inFilter('message_id', lot),
          _client.from('mls_message_hidden').select('message_id').inFilter('message_id', lot),
          _client.from('mls_message_stars').select('message_id').inFilter('message_id', lot),
          _client
              .from('mls_messages')
              .select('id')
              .inFilter('id', lot)
              .eq('is_deleted', true),
        ]);

        for (final r in (resultats[0] as List).cast<Map<String, dynamic>>()) {
          final id = r['message_id'] as String;
          (reactions[id] ??= {})[r['user_id'] as String] = r['emoji'] as String;
        }
        for (final r in (resultats[1] as List).cast<Map<String, dynamic>>()) {
          final id = r['message_id'] as String;
          final qui = r['user_id'] as String;
          final livre = DateTime.tryParse(r['delivered_at'] as String? ?? '');
          final lu = DateTime.tryParse(r['read_at'] as String? ?? '');
          if (livre != null) {
            (destinataires[id] ??= []).add(qui);
            (livreA[id] ??= {})[qui] = livre.toLocal();
          }
          if (lu != null) {
            (lecteurs[id] ??= []).add(qui);
            (luA[id] ??= {})[qui] = lu.toLocal();
          }
        }
        // `mls_message_hidden` et `mls_message_stars` ne sont lisibles que par
        // leur auteur (RLS) : ce qui revient est déjà le mien, sans filtre.
        for (final r in (resultats[2] as List).cast<Map<String, dynamic>>()) {
          masques.add(r['message_id'] as String);
        }
        for (final r in (resultats[3] as List).cast<Map<String, dynamic>>()) {
          etoiles.add(r['message_id'] as String);
        }
        for (final r in (resultats[4] as List).cast<Map<String, dynamic>>()) {
          supprimes.add(r['id'] as String);
        }
      }

      return MlsMetadonneesLot(
        reactions: reactions,
        lecteurs: lecteurs,
        luA: luA,
        destinataires: destinataires,
        livreA: livreA,
        masques: masques,
        etoiles: etoiles,
        supprimes: supprimes,
      );
    } catch (e) {
      debugPrint('MlsMetadonnees: lot illisible ($e)');
      return MlsMetadonneesLot.vide;
    }
  }

  /// Ce message est-il un message MLS ? Sert à router une action — réagir,
  /// supprimer, étoiler — vers la bonne table.
  Future<bool> existe(String messageId) async {
    await _auth();
    final row = await _client
        .from('mls_messages')
        .select('id')
        .eq('id', messageId)
        .maybeSingle();
    return row != null;
  }

  // ── Réactions ────────────────────────────────────────────────────────────

  /// Une réaction par personne et par message : poser un emoji remplace le
  /// précédent. C'est la clé primaire `(message_id, user_id)` qui l'impose,
  /// pas une convention côté client.
  Future<void> poserReaction(String messageId, String emoji) async {
    await _auth();
    await _client.from('mls_message_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'message_id,user_id');
  }

  Future<void> retirerReaction(String messageId) async {
    await _auth();
    await _client
        .from('mls_message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }

  // ── Favoris et masquage ──────────────────────────────────────────────────

  Future<void> etoiler(String messageId) async {
    await _auth();
    await _client.from('mls_message_stars').upsert({
      'message_id': messageId,
      'user_id': userId,
    }, onConflict: 'message_id,user_id');
  }

  /// Bascule le favori et rend son **nouvel** état.
  ///
  /// L'état est relu en base, pas déduit de l'écran : le même message peut
  /// avoir été étoilé depuis un autre appareil, et c'est justement ce que la
  /// table apporte.
  Future<bool> basculerEtoile(String messageId) async {
    await _auth();
    final deja = await _client
        .from('mls_message_stars')
        .select('message_id')
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .maybeSingle();
    if (deja == null) {
      await etoiler(messageId);
      return true;
    }
    await retirerEtoile(messageId);
    return false;
  }

  Future<void> retirerEtoile(String messageId) async {
    await _auth();
    await _client
        .from('mls_message_stars')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }

  /// « Supprimer pour moi » : le message reste chez les autres, et disparaît
  /// sur **tous mes appareils** — c'est ce que la table apporte par rapport à
  /// un simple oubli local.
  Future<void> masquer(String messageId) async {
    await _auth();
    await _client.from('mls_message_hidden').upsert({
      'message_id': messageId,
      'user_id': userId,
    }, onConflict: 'message_id,user_id');
  }

  // ── Suppression pour tous ────────────────────────────────────────────────

  /// Le serveur cesse de servir le ciphertext. Il ne l'a jamais compris, mais
  /// il peut encore le retenir : c'est l'`UPDATE` qui le lui interdit.
  ///
  /// Seul l'expéditeur y est autorisé (RLS), et seules ces colonnes sont
  /// modifiables (`GRANT UPDATE (…)`) : le ciphertext, lui, ne se réécrit
  /// jamais.
  Future<void> supprimerPourTous(String messageId) async {
    await _auth();
    await _client.from('mls_messages').update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  /// Marque le message comme modifié. Le **nouveau texte** n'entre pas ici :
  /// il voyage chiffré, dans un message de contrôle. La colonne ne dit que
  /// « ce message a été modifié », ce que le serveur voit de toute façon en
  /// voyant passer le contrôle.
  Future<void> marquerModifie(String messageId) async {
    await _auth();
    await _client.from('mls_messages').update({
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  // ── Reçus ────────────────────────────────────────────────────────────────

  /// Pose « livré » puis « lu » sur les messages donnés.
  ///
  /// **Ce qui est déjà posé n'est jamais réécrit.** Un `upsert` de tout le
  /// lot serait plus court d'une requête, mais il remettrait `read_at` à
  /// maintenant **à chaque ouverture** de la discussion : « lu à 14 h 03 »
  /// deviendrait « lu à l'instant », indéfiniment, et l'écran d'information
  /// d'un message ne dirait plus rien de vrai. L'heure du premier coup d'œil
  /// est la seule qui ait un sens.
  Future<void> marquer(
    Iterable<String> messageIds, {
    required bool lu,
  }) async {
    final ids = messageIds.toList(growable: false);
    if (ids.isEmpty) return;
    await _auth();
    final maintenant = DateTime.now().toUtc().toIso8601String();

    for (final lot in _lots(ids)) {
      final existants = <String, bool>{}; // message_id → déjà lu
      for (final r in ((await _client
              .from('mls_message_receipts')
              .select('message_id, read_at')
              .inFilter('message_id', lot)
              .eq('user_id', userId)) as List)
          .cast<Map<String, dynamic>>()) {
        existants[r['message_id'] as String] = r['read_at'] != null;
      }

      final aCreer = [for (final id in lot) if (!existants.containsKey(id)) id];
      if (aCreer.isNotEmpty) {
        await _client.from('mls_message_receipts').insert([
          for (final id in aCreer)
            {
              'message_id': id,
              'user_id': userId,
              'delivered_at': maintenant,
              if (lu) 'read_at': maintenant,
            },
        ]);
      }

      if (!lu) continue;
      final aAvancer = [
        for (final e in existants.entries) if (!e.value) e.key,
      ];
      if (aAvancer.isNotEmpty) {
        await _client
            .from('mls_message_receipts')
            .update({'read_at': maintenant})
            .inFilter('message_id', aAvancer)
            .eq('user_id', userId);
      }
    }
  }

  /// Les messages de la conversation qui ne sont pas de moi — ceux dont je
  /// peux accuser réception. Le RLS ne rend que mes conversations.
  Future<List<String>> messagesDesAutres(String conversationId) async {
    await _auth();
    final rows = await _client
        .from('mls_messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .eq('kind', 'content')
        .neq('sender_id', userId);
    return [for (final r in (rows as List).cast<Map<String, dynamic>>()) r['id'] as String];
  }

  // ── Mentions ─────────────────────────────────────────────────────────────

  /// Écrites par l'expéditeur au moment de l'envoi — le RLS n'autorise que
  /// lui. Un échec ici ne doit pas faire échouer l'envoi : le message est
  /// parti, seule la pastille « @ » du destinataire manquerait.
  Future<void> poserMentions(String messageId, Iterable<String> userIds) async {
    final ids = userIds.toSet()..remove(userId);
    if (ids.isEmpty) return;
    try {
      await _auth();
      await _client.from('mls_message_mentions').upsert([
        for (final id in ids) {'message_id': messageId, 'user_id': id},
      ], onConflict: 'message_id,user_id');
    } catch (e) {
      debugPrint('MlsMetadonnees: mentions non posées ($e)');
    }
  }

  // ── Non-lus ──────────────────────────────────────────────────────────────

  /// `conversationId` → (non-lus, mentions non lues), depuis la vue.
  ///
  /// La vue ne rend que **mes** lignes : c'est `firebase_uid()` qui la
  /// filtre, pas un `where` du client — une conversation absente vaut zéro.
  Future<Map<String, ({int nonLus, int mentions})>> nonLus() async {
    try {
      await _auth();
      final rows = await _client
          .from('mls_unread_counts')
          .select('conversation_id, unread, unread_mentions');
      return {
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          r['conversation_id'] as String: (
            nonLus: (r['unread'] as num?)?.toInt() ?? 0,
            mentions: (r['unread_mentions'] as num?)?.toInt() ?? 0,
          ),
      };
    } catch (e) {
      debugPrint('MlsMetadonnees: compteurs illisibles ($e)');
      return const {};
    }
  }
}
