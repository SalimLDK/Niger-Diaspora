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
    this.lu = true,
  });

  /// La lecture du serveur **a abouti**.
  ///
  /// Sans ce drapeau, « aucune métadonnée » et « je n'ai pas réussi à
  /// lire » se rendaient par le même objet vide, et l'appelant ne pouvait
  /// pas les distinguer. C'est la septième forme d'échec muet de ce dépôt —
  /// une requête qui réussit à vide, où l'absence se confond avec la
  /// suppression. Ici elle se payait à l'écran : une réaction retirée côté
  /// serveur restait affichée pour toujours, et une réaction dont l'écriture
  /// avait échoué paraissait avoir pris.
  final bool lu;

  static const vide = MlsMetadonneesLot();

  /// Ce qu'on rend quand la lecture a échoué : rien, et on le dit.
  static const illisible = MlsMetadonneesLot(lu: false);

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
      // **Pas `vide`.** Un lot vide signifie « le serveur ne porte aucune
      // métadonnée », ce qui autorise l'appelant à effacer ce qu'il affichait.
      // Une lecture ratée n'autorise rien de tel : elle doit laisser l'écran
      // tel quel.
      return MlsMetadonneesLot.illisible;
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
    // `ignoreDuplicates` → `ON CONFLICT DO NOTHING`. Un favori n'a aucune
    // charge à écraser, et le `DO UPDATE` d'un upsert ordinaire réécrirait
    // les colonnes de la clé primaire — pour lesquelles cette table n'a
    // volontairement aucun droit d'UPDATE. Le refus serait muet.
    await _client.from('mls_message_stars').upsert({
      'message_id': messageId,
      'user_id': userId,
    }, onConflict: 'message_id,user_id', ignoreDuplicates: true);
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
    // Même raison que pour les favoris : rien à écraser, donc DO NOTHING.
    await _client.from('mls_message_hidden').upsert({
      'message_id': messageId,
      'user_id': userId,
    }, onConflict: 'message_id,user_id', ignoreDuplicates: true);
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
    // **Une RPC, pas un `update`.** Poser `is_deleted` ne suffisait pas : le
    // ciphertext restait en base, et un destinataire qui n'avait pas encore
    // rattrapé pouvait encore le déchiffrer. Le client ne peut pas le vider
    // lui-même — `UPDATE` ne lui est pas accordé sur cette colonne, et cette
    // restriction doit rester, c'est elle qui l'empêche de réécrire son propre
    // message après coup. La fonction fait le geste précis à sa place.
    final id = await _client.rpc<dynamic>(
      'mls_supprimer_pour_tous',
      params: {'p_message_id': messageId},
    );
    // Elle rend l'identifiant touché, ou rien. Sans cette garde, un refus du
    // RLS passerait pour un succès — zéro ligne, aucune erreur : la sixième
    // forme d'échec muet de ce dépôt, celle qui a déjà fait mentir une
    // révocation d'appareil.
    if (id == null) {
      throw StateError(
        'suppression pour tous refusée ou sans cible ($messageId)',
      );
    }
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
        try {
          await _client.from('mls_message_receipts').insert([
            for (final id in aCreer)
              {
                'message_id': id,
                'user_id': userId,
                'delivered_at': maintenant,
                if (lu) 'read_at': maintenant,
              },
          ]);
        } on PostgrestException catch (e) {
          // 23505 : la clé primaire est `(message_id, user_id)`, et un autre
          // appel a créé le reçu entre notre SELECT et notre INSERT.
          //
          // Ce n'est pas théorique : `ConversationScreen.initState` lance
          // `markAsDelivered` **et** `markAsRead` coup sur coup, sans `await`.
          // Ils lisent tous deux « aucun reçu », le premier insère, le second
          // heurte la clé. L'exception remontait jusqu'au `catch` de
          // `markAsRead`, qui rend un `Left` que l'appelant ignore : « livré »
          // était écrit, « lu » ne l'était jamais, et pas une ligne de journal.
          //
          // Vu le 2026-09-15 sur Pixel 10 Pro XL : cinq messages avec
          // `delivered_at` posé et `read_at` nul, même après avoir ouvert la
          // discussion. C'est une course : elle ne tombe pas toujours du même
          // côté, d'où des reçus corrects une heure plus tôt.
          if (e.code != '23505') rethrow;
        }
      }

      if (!lu) continue;
      // Tout le lot, et non les seuls reçus vus au SELECT : entre les deux,
      // l'autre appel a pu créer ceux qui manquaient. `read_at IS NULL` garde
      // la règle d'origine — « lu à 14 h 03 » ne devient pas « lu à
      // l'instant » à chaque ouverture, seule l'heure du premier coup d'œil
      // compte — et rend l'écriture idempotente.
      await _client
          .from('mls_message_receipts')
          .update({'read_at': maintenant})
          .inFilter('message_id', lot)
          .isFilter('read_at', null)
          .eq('user_id', userId);
    }
  }

  /// **Le curseur de lecture** : le dernier message de cette conversation que
  /// j'ai réellement lu.
  ///
  /// C'est l'état dont le séparateur « nouveaux messages » est la
  /// représentation — pas une date de visite, pas un compte. Un compte ne dit
  /// pas **où**, et une date ne survit ni à la pagination ni au fuseau. Le
  /// curseur, lui, désigne un message, et le premier non-lu est celui qui le
  /// suit. Il reste juste même quand ce message n'est pas chargé : son
  /// horodatage suffit à placer le repère dès que la pagination remonte
  /// jusque-là.
  ///
  /// Il vit dans `mls_message_receipts`, qui porte déjà un état **par
  /// utilisateur et par message** : en groupe, un `isRead` porté par le
  /// message serait faux, chaque membre ayant le sien.
  ///
  /// `null` = rien n'a jamais été lu ici ; tout ce qui vient d'autrui est
  /// nouveau.
  Future<({String id, DateTime quand})?> curseurDeLecture(
    String conversationId,
  ) async {
    try {
      await _auth();
      final rows = await _client
          .from('mls_message_receipts')
          .select('message_id, mls_messages!inner(conversation_id, created_at)')
          .eq('user_id', userId)
          .not('read_at', 'is', null)
          .eq('mls_messages.conversation_id', conversationId);

      String? id;
      DateTime? quand;
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final message = r['mls_messages'];
        if (message is! Map) continue;
        final date = DateTime.tryParse(message['created_at'] as String? ?? '');
        if (date == null) continue;
        if (quand == null || date.isAfter(quand)) {
          quand = date;
          id = r['message_id'] as String?;
        }
      }
      if (id == null || quand == null) return null;
      return (id: id, quand: quand);
    } catch (e) {
      debugPrint('MlsMetadonnees: curseur illisible ($e)');
      return null;
    }
  }

  /// Le **premier message non lu** de cette conversation, qu'il soit chargé
  /// ou non.
  ///
  /// C'est le pendant de [curseurDeLecture] : le curseur dit « j'ai lu
  /// jusqu'ici », celui-ci dit « le repère va là ». Le calculer **sur le
  /// serveur** est ce qui le rend compatible avec la pagination : si la page
  /// affichée commence après le premier non-lu, le chercher dans les messages
  /// chargés désignerait le plus ancien de la page, pas le bon. L'identifiant,
  /// lui, attend simplement que la remontée du fil l'amène à l'écran.
  ///
  /// [apres] est la date du curseur ; `null` quand rien n'a jamais été lu, et
  /// tout ce qui vient d'autrui est alors nouveau.
  Future<({String id, DateTime quand})?> premierNonLu(
    String conversationId, {
    DateTime? apres,
  }) async {
    try {
      await _auth();
      var requete = _client
          .from('mls_messages')
          .select('id, created_at')
          .eq('conversation_id', conversationId)
          .eq('kind', 'content')
          .eq('is_deleted', false)
          .neq('sender_id', userId);
      if (apres != null) {
        requete = requete.gt('created_at', apres.toUtc().toIso8601String());
      }
      final rows = await requete.order('created_at', ascending: true).limit(1);
      final liste = (rows as List).cast<Map<String, dynamic>>();
      if (liste.isEmpty) return null;
      final id = liste.first['id'] as String?;
      final quand = DateTime.tryParse(
        liste.first['created_at'] as String? ?? '',
      );
      if (id == null || quand == null) return null;
      return (id: id, quand: quand);
    } catch (e) {
      debugPrint('MlsMetadonnees: premier non-lu illisible ($e)');
      return null;
    }
  }

  /// Avance le curseur : marque lus les messages d'autrui **jusqu'à**
  /// [jusqua] inclus, et pas au-delà.
  ///
  /// C'est la différence avec [messagesDesAutres] + [marquer], qui prend la
  /// conversation entière : ouvrir une discussion ne veut pas dire qu'on a lu
  /// ce qui est resté sous le pli. L'accusé « Lu » que reçoit l'expéditeur
  /// suit donc ce que l'écran a vraiment montré.
  Future<void> marquerLusJusqua(String conversationId, DateTime jusqua) async {
    await _auth();
    final rows = await _client
        .from('mls_messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .eq('kind', 'content')
        .neq('sender_id', userId)
        .lte('created_at', jusqua.toUtc().toIso8601String());
    final ids = [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['id'] as String,
    ];
    await marquer(ids, lu: true);
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
      ], onConflict: 'message_id,user_id', ignoreDuplicates: true);
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

  /// Le dernier message de contenu de chaque conversation basculée, du plus
  /// récent au plus ancien, réduit à un identifiant par conversation.
  ///
  /// Sert à retrouver l'aperçu déjà déchiffré par l'isolate de notification,
  /// qui le range par identifiant de message. On ne demande **que** les
  /// colonnes de métadonnées : le ciphertext ne sort pas d'ici.
  ///
  /// Une seule requête pour toute la liste, bornée : au-delà, les
  /// conversations concernées sont de toute façon plus anciennes que ce que
  /// l'écran montre en premier.
  Future<Map<String, String>> derniersMessages(
    Iterable<String> conversationIds, {
    int limite = 200,
  }) async {
    final ids = conversationIds.toList(growable: false);
    if (ids.isEmpty) return const {};
    try {
      await _auth();
      final rows = await _client
          .from('mls_messages')
          .select('id, conversation_id, created_at')
          .inFilter('conversation_id', ids)
          .eq('kind', 'content')
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(limite);
      final dernier = <String, String>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final conv = r['conversation_id'] as String?;
        final id = r['id'] as String?;
        if (conv == null || id == null) continue;
        // Tri décroissant : la première vue est la plus récente.
        dernier.putIfAbsent(conv, () => id);
      }
      return dernier;
    } catch (e) {
      debugPrint('MlsMetadonnees: derniers messages illisibles ($e)');
      return const {};
    }
  }
}
