
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../src/rust/api/mls.dart';
import 'mls_delivery.dart';
import 'mls_device_registry.dart';
import 'mls_payload_codec.dart';

/// Un message entrant, déchiffré — ou pas, avec le code qui dit pourquoi.
class MlsIncoming {
  final MlsMessageRow row;
  final MlsPayload? payload;
  final String? erreur;

  const MlsIncoming(this.row, {this.payload, this.erreur});

  bool get lisible => payload != null;
}

/// Le groupe n'existe pas encore pour cet appareil, et personne ne l'y a
/// encore ajouté : il attend un Welcome d'un membre en ligne (§ 5.2, 5.4).
class MlsEnAttenteDeWelcome implements Exception {
  final String conversationId;
  const MlsEnAttenteDeWelcome(this.conversationId);

  @override
  String toString() => 'MlsEnAttenteDeWelcome($conversationId)';
}

/// La conversation ne peut pas basculer : au moins un participant n'a aucun
/// appareil MLS actif, donc rien ne pourrait lui être chiffré.
///
/// Levée **avant** que quoi que ce soit soit engagé — `mls_since` est encore
/// nul —, précisément pour que l'envoi puisse retomber en clair.
class MlsParticipantSansAppareil implements Exception {
  final String conversationId;

  /// Les identifiants sans appareil. Jamais affichés tels quels : ils servent
  /// au diagnostic, pas à l'écran.
  final List<String> participants;

  const MlsParticipantSansAppareil(this.conversationId, this.participants);

  @override
  String toString() =>
      'MlsParticipantSansAppareil($conversationId, ${participants.length})';
}

/// Orchestration MLS d'une conversation : le seul service que la couche
/// messages appellera (plan MLS § 7.3).
///
/// Trois règles, tirées du chantier Signal :
/// 1. **Le moteur est demandé à chaque usage** (`moteur()`), jamais retenu :
///    s'il a été détruit et recréé entre deux envois, on rouvre — c'est le
///    rattrapage au point d'usage. Le cas exact qui a tué Signal.
/// 2. **Aucun repli.** `send` lève ; il n'existe pas de chemin « en clair si
///    MLS échoue ».
/// 3. **Le motif s'écrit en base** (`mls_diagnostics`), par le transport.
///
/// Ordre de traitement, non négociable (§ 5.3) : les commits par epoch
/// croissant, AVANT tout message d'un epoch supérieur.
class MlsConversationService {
  MlsConversationService({
    required this.userId,
    required Future<Moteur> Function() moteur,
    required MlsDelivery delivery,
    required Future<MlsDeviceRecord> Function() appareil,
    Future<String?> Function(String cle)? lireMemo,
    Future<void> Function(String cle, String valeur)? ecrireMemo,
  })  : _moteur = moteur,
        _delivery = delivery,
        _appareil = appareil,
        _lireMemo = lireMemo ?? _lirePrefs,
        _ecrireMemo = ecrireMemo ?? _ecrirePrefs;

  final String userId;
  final Future<Moteur> Function() _moteur;
  final MlsDelivery _delivery;
  final Future<MlsDeviceRecord> Function() _appareil;
  final Future<String?> Function(String cle) _lireMemo;
  final Future<void> Function(String cle, String valeur) _ecrireMemo;

  static const _uuid = Uuid();

  static Future<String?> _lirePrefs(String cle) async =>
      (await SharedPreferences.getInstance()).getString(cle);

  static Future<void> _ecrirePrefs(String cle, String valeur) async =>
      (await SharedPreferences.getInstance()).setString(cle, valeur);

  /// Dernier `created_at` traité par conversation, et ids déjà rendus : un
  /// message rendu deux fois ferait deux bulles (le projet a déjà payé ce
  /// bug avec `clientMessageId`).
  ///
  /// **Le curseur survit au redémarrage** (`SharedPreferences`), et ce n'est
  /// pas une optimisation. MLS supprime le secret d'un message applicatif
  /// après usage : redemander au moteur un message déjà déchiffré ne le rend
  /// pas une seconde fois, il **échoue**. Sans mémoire, toute conversation
  /// basculée serait donc relue depuis le début à chaque lancement, et son
  /// historique reviendrait en « 🔐 Message chiffré ». Le clair, lui, est
  /// dans le cache local — c'est `MlsGateway.amorcer` qui l'y reprend.
  final Map<String, DateTime> _curseur = {};
  final Set<String> _vus = {};

  Future<InstantaneDto?> _instantane(String conversationId) async {
    final moteur = await _moteur();
    try {
      return await moteur.instantane(conversationId: conversationId);
    } catch (_) {
      // `group_unknown` : pas d'état local pour cette conversation.
      return null;
    }
  }

  /// Vrai si cet appareil est membre du groupe.
  Future<bool> estMembre(String conversationId) async =>
      await _instantane(conversationId) != null;

  /// Crée le groupe, ou le rejoint depuis un Welcome qui attendait.
  ///
  /// Lève [MlsEnAttenteDeWelcome] quand le groupe existe déjà côté serveur
  /// sans Welcome pour cet appareil : un membre en ligne doit l'ajouter.
  Future<void> ensureGroup(String conversationId) async {
    if (await estMembre(conversationId)) return;
    final moteur = await _moteur();
    final appareil = await _appareil();

    // 1. Un Welcome m'attend ?
    final welcomes = await _delivery.welcomesFor(appareil.id, conversationId: conversationId);
    if (welcomes.isNotEmpty) {
      final w = welcomes.last;
      await moteur.traiterWelcome(conversationId: conversationId, welcome: w.welcome);
      await _delivery.markWelcomeConsumed(w.id);
      return;
    }

    // 2. Le groupe existe déjà. Dans un groupe, je peux m'ajouter moi-même
    //    depuis l'arbre public (§ 5.7) : c'est ce qui rend le groupe officiel
    //    d'une ville praticable, puisqu'on le rejoint automatiquement, souvent
    //    sans qu'aucun membre ne soit en ligne. Pour un 1:1, non — il n'y a
    //    personne à rejoindre sans invitation.
    if (await _delivery.currentEpoch(conversationId) != null) {
      if (await _jointureExternePossible(conversationId)) {
        final arbre = await _delivery.groupInfo(conversationId);
        final epochCourant = await _delivery.currentEpoch(conversationId);
        if (arbre != null && epochCourant != null) {
          final epoch = epochCourant + 1;
          final aad = MlsAad.commit(conversationId: conversationId, epoch: epoch);
          final out = await moteur.rejoindreParCommitExterne(
            conversationId: conversationId,
            groupInfo: arbre,
            aad: aad,
          );
          try {
            await _delivery.publishCommit(
              conversationId: conversationId,
              epoch: epoch,
              senderDeviceId: appareil.id,
              commit: out.commit,
              groupInfo: out.groupInfo,
            );
          } on EpochConflict {
            // Quelqu'un a commité pendant ma jointure : mon arbre est déjà
            // périmé. J'oublie ce groupe et je recommence — le sien
            // m'attendra peut-être avec un Welcome.
            await moteur.oublierGroupe(conversationId: conversationId);
            await _delivery.diagnostic(userId, 'jointure_externe_perdue',
                deviceId: appareil.id, detail: {'epoch': epoch});
            return ensureGroup(conversationId);
          }
          await _delivery.upsertConversationDevice(
              conversationId, appareil.id, 'active', epochAdded: epoch);
          await _publierArbre(conversationId, moteur);
          return;
        }
      }
      throw MlsEnAttenteDeWelcome(conversationId);
    }

    // 3. Le créer — mais PAS avant d'avoir vérifié que tout le monde peut
    //    suivre. Créer le groupe pose `mls_since`, et `mls_since` est
    //    définitif : à partir de là le serveur refuse le clair, et qui n'est
    //    pas dans l'arbre à cet instant ne lira plus jamais rien — le secret
    //    d'un epoch passé ne se redonne pas.
    await refuserSiQuelquUnNePeutPasSuivre(conversationId);
    await moteur.creerGroupe(conversationId: conversationId);
    try {
      await _delivery.publishCommit(
        conversationId: conversationId,
        epoch: 0,
        senderDeviceId: appareil.id,
        commit: Uint8List(0),
      );
    } on EpochConflict {
      await moteur.oublierGroupe(conversationId: conversationId);
      await _delivery.diagnostic(userId, 'creation_perdue', deviceId: appareil.id);
      // Le gagnant m'ajoutera ; peut-être l'a-t-il déjà fait.
      return ensureGroup(conversationId);
    }
    await _delivery.marquerMlsSince(conversationId);
    await _delivery.upsertConversationDevice(conversationId, appareil.id, 'active', epochAdded: 0);
    await _publierArbre(conversationId, moteur);
  }

  /// Refuse la bascule si un participant n'a aucun appareil MLS actif.
  ///
  /// **Le défaut que ça ferme, mesuré en production le 2026-09-15.** Deux
  /// conversations à deux personnes avaient basculé avec **un seul appareil**
  /// dans `conversation_devices` : celui de l'expéditeur. En face, personne
  /// n'avait encore de ligne dans `mls_devices`, donc `reconcileMembership`
  /// ne trouvait personne à ajouter, `aAjouter` était vide, et **rien n'était
  /// journalisé** — l'échec muet dans sa forme la plus pure. Huit messages
  /// sont partis chiffrés pour un groupe d'une personne. L'autre ne les lira
  /// jamais : MLS ne redonne pas le secret d'un epoch passé.
  ///
  /// Le repli est légitime ici, et c'est le seul endroit où il l'est : tant
  /// que `mls_since` est nul, rien n'est engagé et le chemin d'aujourd'hui
  /// reste ouvert (cf. la règle du repli en tête de `MlsGateway`). Lever
  /// suffit donc : l'envoi retombe en clair, et la conversation basculera
  /// d'elle-même quand l'autre aura ouvert l'application une fois.
  @visibleForTesting
  Future<void> refuserSiQuelquUnNePeutPasSuivre(String conversationId) async {
    final conv = await _delivery.conversation(conversationId);
    if (conv == null) return; // conversation inconnue : l'appelant tranchera.
    final participants =
        ((conv['participant_ids'] as List?) ?? const []).cast<String>();

    final orphelins = <String>[];
    for (final p in participants) {
      if (p == userId) continue;
      if ((await _delivery.activeDevicesOf(p)).isEmpty) orphelins.add(p);
    }
    if (orphelins.isEmpty) return;

    await _delivery.diagnostic(userId, 'bascule_refusee_sans_appareil',
        detail: {
          'conversation': conversationId,
          'participants_sans_appareil': orphelins.length,
        });
    throw MlsParticipantSansAppareil(conversationId, orphelins);
  }

  /// Publie l'arbre public de l'epoch courant, pour les arrivants.
  ///
  /// Échoue en silence : un arbre non publié coûte une jointure externe —
  /// l'arrivant attendra un Welcome — mais ne doit jamais faire échouer le
  /// commit qui vient d'aboutir.
  Future<void> _publierArbre(String conversationId, Moteur moteur) async {
    try {
      final arbre = await moteur.exporterGroupInfo(conversationId: conversationId);
      await _delivery.publierGroupInfo(conversationId, arbre);
    } catch (e) {
      await _delivery.diagnostic(userId, 'group_info_non_publie',
          detail: {'code': _code(e)});
    }
  }

  /// La jointure externe n'a de sens que pour une conversation de groupe.
  ///
  /// Dans un 1:1, s'ajouter soi-même à la conversation de quelqu'un d'autre
  /// n'aurait aucune légitimité — et le RLS l'interdirait de toute façon,
  /// puisqu'il faut déjà figurer dans `participant_ids` pour lire l'arbre.
  /// Cette garde est donc une clarté d'intention ; la barrière, elle, est
  /// côté serveur.
  Future<bool> _jointureExternePossible(String conversationId) async {
    final conv = await _delivery.conversation(conversationId);
    return (conv?['type'] as String?) == 'group';
  }

  /// Aligne les membres du groupe sur les appareils actifs des participants
  /// (§ 5.4, 5.5) : ajoute ceux qui manquent, retire ceux qui n'ont plus
  /// d'appareil actif (révoqués, réinstallés). Les appareils sans KeyPackage
  /// restent `pending`, l'envoi part quand même vers les autres.
  Future<void> reconcileMembership(String conversationId, {int tentative = 0}) async {
    await catchUp(conversationId);
    final moteur = await _moteur();
    final appareil = await _appareil();
    final conv = await _delivery.conversation(conversationId);
    if (conv == null) throw StateError('conversation inconnue ou inaccessible');
    final participants = (conv['participant_ids'] as List).cast<String>();

    final actifs = <MlsDeviceRecord>[];
    var muets = 0;
    for (final p in participants) {
      final siens = await _delivery.activeDevicesOf(p);
      if (siens.isEmpty && p != userId) muets++;
      actifs.addAll(siens);
    }
    if (muets > 0) {
      // Le silence qu'il fallait casser. Un participant sans aucun appareil
      // ne produit **rien** ici : `aAjouter` reste vide, aucun KeyPackage
      // n'est réclamé, donc pas même un `appareil_sans_key_package`. La
      // conversation continue de tourner en paraissant saine, et lui ne
      // déchiffrera jamais ce qui s'y dit. Mesuré en production le
      // 2026-09-15 sur deux conversations. La garde de `ensureGroup` empêche
      // désormais d'en arriver là ; cette ligne est pour celles qui y sont
      // déjà, et pour celles qu'on quitterait entre-temps.
      await _delivery.diagnostic(userId, 'participant_sans_appareil',
          deviceId: appareil.id,
          detail: {'conversation': conversationId, 'combien': muets});
    }
    final snap = await moteur.instantane(conversationId: conversationId);
    final membres = {for (final m in snap.membres) m.identity: m.leafIndex};
    final identitesActives = {for (final d in actifs) d.mlsIdentity: d};

    final aAjouter = actifs.where((d) => !membres.containsKey(d.mlsIdentity)).toList();
    final aRetirer = <int>[
      for (final e in membres.entries)
        if (!identitesActives.containsKey(e.key) && e.key != appareil.mlsIdentity) e.value,
    ];
    if (aAjouter.isEmpty && aRetirer.isEmpty) return;

    // Ajouts : un KeyPackage réclamé par appareil ; sans paquet, en attente.
    final paquets = <Uint8List>[];
    final destinataires = <String>[];
    for (final d in aAjouter) {
      final claim = await _delivery.claimKeyPackage(d.id);
      if (claim == null) {
        await _delivery.upsertConversationDevice(conversationId, d.id, 'pending');
        await _delivery.diagnostic(userId, 'appareil_sans_key_package', deviceId: d.id);
        continue;
      }
      paquets.add(claim.keyPackage);
      destinataires.add(d.id);
    }

    try {
      if (paquets.isNotEmpty) {
        final epoch = snap.epoch.toInt() + 1;
        final out = await moteur.ajouterMembres(
          conversationId: conversationId,
          keyPackages: paquets,
          aad: MlsAad.commit(conversationId: conversationId, epoch: epoch),
        );
        await _delivery.publishCommit(
          conversationId: conversationId,
          epoch: epoch,
          senderDeviceId: appareil.id,
          commit: out.commit,
          groupInfo: out.groupInfo,
        );
        await moteur.fusionnerCommitEnAttente(conversationId: conversationId);
        await _delivery.publishWelcomes(
          conversationId: conversationId,
          epoch: epoch,
          parAppareil: {for (final id in destinataires) id: out.welcome!},
        );
        for (final id in destinataires) {
          await _delivery.upsertConversationDevice(conversationId, id, 'active', epochAdded: epoch);
        }
        await _publierArbre(conversationId, moteur);
      }
      if (aRetirer.isNotEmpty) {
        final snap2 = await moteur.instantane(conversationId: conversationId);
        final epoch = snap2.epoch.toInt() + 1;
        final out = await moteur.retirerMembres(
          conversationId: conversationId,
          leafIndices: aRetirer,
          aad: MlsAad.commit(conversationId: conversationId, epoch: epoch),
        );
        await _delivery.publishCommit(
          conversationId: conversationId,
          epoch: epoch,
          senderDeviceId: appareil.id,
          commit: out.commit,
        );
        await moteur.fusionnerCommitEnAttente(conversationId: conversationId);
        // Sans ça, l'arbre public se périme dès qu'un membre part, et plus
        // personne ne peut rejoindre le groupe par commit externe.
        await _publierArbre(conversationId, moteur);
      }
    } on EpochConflict catch (e) {
      // Quelqu'un a commité avant moi : je jette le mien, je traite le sien,
      // et je recommence une fois — il a peut-être fait le même ajout.
      await moteur.jeterCommitEnAttente(conversationId: conversationId);
      await _delivery.diagnostic(userId, 'commit_perdu', deviceId: appareil.id,
          detail: {'epoch': e.epoch});
      if (tentative >= 2) rethrow;
      return reconcileMembership(conversationId, tentative: tentative + 1);
    }
  }

  /// Chiffre et publie. Lève en cas d'échec — jamais de repli en clair.
  Future<MlsMessageRow> send(
    String conversationId,
    MlsPayload payload, {
    String kind = 'content',
    String contentType = 'text',
    DateTime? expiresAt,
  }) async {
    await catchUp(conversationId);
    final moteur = await _moteur();
    final appareil = await _appareil();
    final snap = await moteur.instantane(conversationId: conversationId);
    final id = payload.id.isNotEmpty ? payload.id : _uuid.v4();
    final aad = MlsAad.message(
      conversationId: conversationId,
      messageId: id,
      senderDeviceId: appareil.id,
      kind: kind,
    );
    final Uint8List ciphertext;
    try {
      ciphertext = await moteur.chiffrer(
        conversationId: conversationId,
        clair: payload.encode(),
        aad: aad,
      );
    } catch (e) {
      await _delivery.diagnostic(userId, 'encrypt_failed', deviceId: appareil.id,
          detail: {'code': _code(e)});
      rethrow;
    }
    final row = MlsMessageRow(
      id: id,
      conversationId: conversationId,
      senderId: userId,
      senderDeviceId: appareil.id,
      epoch: snap.epoch.toInt(),
      kind: kind,
      contentType: contentType,
      ciphertext: ciphertext,
      createdAt: DateTime.now().toUtc(),
      expiresAt: expiresAt,
    );
    await _delivery.publishMessage(row);
    _vus.add(id);
    return row;
  }

  /// Rattrapage : commits d'abord (par epoch), puis messages. Rend les
  /// messages **nouveaux** depuis le dernier appel, déchiffrés ou non.
  Future<List<MlsIncoming>> catchUp(String conversationId) async {
    if (!await estMembre(conversationId)) {
      await ensureGroup(conversationId);
    }
    final moteur = await _moteur();
    final appareil = await _appareil();
    await _traiterCommits(conversationId, moteur, appareil);

    final resultats = <MlsIncoming>[];
    final depart = await _curseurDe(conversationId);
    var lignes = await _delivery.messagesAfter(conversationId, depart);
    for (var i = 0; i < lignes.length; i++) {
      final m = lignes[i];
      if (_vus.contains(m.id)) {
        _curseur[conversationId] = m.createdAt;
        continue;
      }
      var snap = await moteur.instantane(conversationId: conversationId);
      if (m.epoch > snap.epoch.toInt()) {
        // Un message d'un epoch que je n'ai pas encore : le commit est en
        // route. Le chercher, puis reprendre.
        await _traiterCommits(conversationId, moteur, appareil);
        snap = await moteur.instantane(conversationId: conversationId);
        if (m.epoch > snap.epoch.toInt()) {
          await _delivery.diagnostic(userId, 'epoch_futur', deviceId: appareil.id,
              detail: {'message_epoch': m.epoch, 'epoch': snap.epoch.toInt()});
          break;
        }
      }
      _vus.add(m.id);
      _curseur[conversationId] = m.createdAt;
      if (m.isDeleted) {
        // Pierre tombale — message expiré, ou supprimé pour tout le monde.
        // Son `ciphertext` a été vidé par la purge : le déchiffrer échouerait
        // à coup sûr et écrirait un `decrypt_failed` de plus à chaque
        // rattrapage, pour un message dont l'affichage est déjà décidé.
        resultats.add(MlsIncoming(m, erreur: 'tombstone'));
        continue;
      }
      if (m.senderDeviceId == appareil.id) {
        // Mon propre message : son clair est dans le cache local, et le
        // cliquet ne sait pas relire ce qu'il a émis.
        continue;
      }
      final aad = MlsAad.message(
        conversationId: conversationId,
        messageId: m.id,
        senderDeviceId: m.senderDeviceId,
        kind: m.kind,
      );
      try {
        final entrant = await moteur.traiterEntrant(
          conversationId: conversationId,
          message: m.ciphertext,
          aadAttendu: aad,
        );
        switch (entrant) {
          case EntrantDto_Application(:final clair):
            resultats.add(MlsIncoming(m, payload: MlsPayload.decode(clair)));
          default:
            resultats.add(MlsIncoming(m, erreur: 'not_application_message'));
        }
      } catch (e) {
        final code = _code(e);
        await _delivery.diagnostic(userId, 'decrypt_failed', deviceId: appareil.id,
            detail: {'code': code, 'epoch': m.epoch});
        resultats.add(MlsIncoming(m, erreur: code));
      }
    }
    await _memoriserCurseur(conversationId, depart);
    return resultats;
  }

  /// Le curseur de cette conversation, repris du disque au premier besoin.
  Future<DateTime?> _curseurDe(String conversationId) async {
    if (_curseur.containsKey(conversationId)) return _curseur[conversationId];
    try {
      final brut = await _lireMemo(_cleCurseur(conversationId));
      final date = brut == null ? null : DateTime.tryParse(brut);
      if (date != null) _curseur[conversationId] = date;
      return date;
    } catch (e) {
      // Sans mémoire, on relit depuis le début : dégradé (des placeholders),
      // jamais faux. Ça ne doit pas empêcher d'ouvrir la discussion.
      debugPrint('MlsConversationService: curseur illisible ($e)');
      return null;
    }
  }

  Future<void> _memoriserCurseur(String conversationId, DateTime? avant) async {
    final apres = _curseur[conversationId];
    if (apres == null || apres == avant) return;
    try {
      await _ecrireMemo(
        _cleCurseur(conversationId),
        apres.toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('MlsConversationService: curseur non mémorisé ($e)');
    }
  }

  /// Par utilisateur : deux comptes sur le même téléphone n'ont ni le même
  /// moteur ni le même avancement.
  String _cleCurseur(String conversationId) =>
      'mls_curseur_${userId}_$conversationId';

  Future<void> _traiterCommits(
    String conversationId,
    Moteur moteur,
    MlsDeviceRecord appareil,
  ) async {
    var snap = await moteur.instantane(conversationId: conversationId);
    final commits = await _delivery.commitsAfter(conversationId, snap.epoch.toInt());
    for (final c in commits) {
      if (c.epoch == 0 || c.senderDeviceId == appareil.id) continue;
      if (c.epoch != snap.epoch.toInt() + 1) {
        // Trou dans la séquence : un commit manque, ne pas sauter.
        await _delivery.diagnostic(userId, 'commit_manquant', deviceId: appareil.id,
            detail: {'attendu': snap.epoch.toInt() + 1, 'recu': c.epoch});
        break;
      }
      try {
        await moteur.traiterEntrant(
          conversationId: conversationId,
          message: c.commit,
          aadAttendu: MlsAad.commit(conversationId: conversationId, epoch: c.epoch),
        );
      } catch (e) {
        await _delivery.diagnostic(userId, 'commit_illisible', deviceId: appareil.id,
            detail: {'code': _code(e), 'epoch': c.epoch});
        break;
      }
      snap = await moteur.instantane(conversationId: conversationId);
    }
  }

  /// Un code, jamais un message libre (qui pourrait citer du contenu).
  static String _code(Object e) {
    final texte = e.toString();
    final m = RegExp(r'[A-Za-z_]+').allMatches(texte).map((x) => x.group(0)!).toList();
    // `AnyhowException(aad_mismatch)` → aad_mismatch
    final utile = m.where((s) => s != 'AnyhowException' && s != 'Exception').toList();
    final code = utile.isEmpty ? 'inconnue' : utile.first;
    return code.length > 40 ? code.substring(0, 40) : code;
  }

  @visibleForTesting
  void oublierCurseur(String conversationId) {
    _curseur.remove(conversationId);
  }

  static void debugTrace(String message) => debugPrint('MlsConversationService: $message');
}
