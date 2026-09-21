import 'dart:async';

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

/// Cet appareil est révoqué : il ne doit plus rejoindre un groupe, publier un
/// commit, chiffrer ou déchiffrer.
///
/// **Le trou que ça ferme.** `MlsDeviceRegistry.ensureRegistered` détecte la
/// révocation et écrit `appareil_revoque_au_demarrage` — mais renvoie quand
/// même le `MlsDeviceRecord` (pour ne pas faire échouer un simple
/// rafraîchissement d'écran). Rien, nulle part ailleurs dans la pile MLS, ne
/// relisait `estRevoque` : un appareil révoqué rejoignait des groupes par
/// commit externe, s'inscrivait dans `conversation_devices` comme membre
/// actif, et chiffrait/déchiffrait avec des clés que le serveur ne tenait
/// plus à jour pour lui (le registre saute la republication en cas de
/// révocation, voir `ensureRegistered`) — échec cryptographique systématique
/// (`GroupStateError`/`ValidationError`), à chaque appel, sans qu'aucun
/// message ne le dise. Trouvé le 2026-09-17 sur le Pixel : `stableDeviceId`
/// avait basculé sur une identité déjà révoquée après un changement de
/// certificat de signature (voir `stable_device_id.dart`), et l'appareil a
/// continué à opérer indéfiniment sous cette identité morte.
class MlsAppareilRevoque implements Exception {
  final String deviceId;
  const MlsAppareilRevoque(this.deviceId);

  @override
  String toString() => 'MlsAppareilRevoque($deviceId)';
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

  /// Lève [MlsAppareilRevoque] si [appareil] est révoqué — à appeler à
  /// l'entrée de toute opération qui rejoint un groupe, publie un commit, ou
  /// chiffre/déchiffre. Voir la classe pour ce que ça ferme.
  Future<void> _refuserSiRevoque(MlsDeviceRecord appareil) async {
    if (!appareil.estRevoque) return;
    await _delivery.diagnostic(userId, 'appareil_revoque_refuse', deviceId: appareil.id);
    throw MlsAppareilRevoque(appareil.id);
  }

  /// Jointures en cours, une par conversation.
  final Map<String, Future<void>> _jointures = {};

  /// Crée le groupe, ou le rejoint depuis un Welcome qui attendait.
  ///
  /// Lève [MlsEnAttenteDeWelcome] quand le groupe existe déjà côté serveur
  /// sans Welcome pour cet appareil : un membre en ligne doit l'ajouter.
  ///
  /// **Une seule jointure à la fois par conversation.** L'ouverture du fil et
  /// le rattrapage de fond appellent tous deux `catchUp`, donc ici. Le
  /// 2026-09-16, sur le Samsung, deux jointures externes simultanées ont
  /// publié les epochs 2 et 3 d'un même arbre : la seconde, en conflit, avait
  /// oublié le groupe que la première venait de rejoindre, puis s'était
  /// rejointe depuis un arbre périmé. Deux branches sur le serveur, un état
  /// local qui ne correspondait plus à rien, et `commit_perdu` en boucle —
  /// le message restait « Envoi… ».
  Future<void> ensureGroup(String conversationId) {
    final enCours = _jointures[conversationId];
    if (enCours != null) return enCours;
    final futur = _ensureGroup(conversationId);
    _jointures[conversationId] = futur;
    return futur.whenComplete(() {
      if (identical(_jointures[conversationId], futur)) {
        unawaited(_jointures.remove(conversationId));
      }
    });
  }

  Future<void> _ensureGroup(String conversationId) async {
    if (await estMembre(conversationId)) return;
    final moteur = await _moteur();
    final appareil = await _appareil();
    await _refuserSiRevoque(appareil);

    // 1. Un Welcome m'attend ?
    //
    // Du plus récent au plus ancien, et un Welcome qui ne s'ouvre pas n'est
    // pas une impasse. Après une réinstallation, ceux qui attendaient visent
    // les KeyPackages de l'installation d'AVANT, dont les secrets sont partis
    // avec l'ancienne base : ils ne s'ouvriront jamais. Lever ici, c'était
    // n'atteindre jamais la jointure externe juste en dessous, qui est
    // précisément le chemin d'une réinstallation. Trouvé le 2026-09-21 sur le
    // Pixel : réinstallé le 20/09, deux Welcome du 17/09 en attente, et la
    // discussion avec Sim A muette — ses messages comptés « non lus » mais
    // jamais affichés, sans une ligne dans `mls_diagnostics`.
    //
    // Pas de `markWelcomeConsumed` sur un échec : un échec passager brûlerait
    // une invitation valide, et un 1:1 sans place antérieure n'a pas d'autre
    // porte. Le laisser en attente ne coûte rien — une fois membre, plus
    // personne ne le relit.
    final welcomes = await _delivery.welcomesFor(appareil.id, conversationId: conversationId);
    for (final w in welcomes.reversed) {
      try {
        await moteur.traiterWelcome(conversationId: conversationId, welcome: w.welcome);
      } catch (e) {
        await _delivery.diagnostic(userId, 'welcome_illisible',
            deviceId: appareil.id, detail: {'code': _code(e), 'epoch': w.epoch});
        continue;
      }
      await _delivery.markWelcomeConsumed(w.id);
      return;
    }

    // 2. Le groupe existe déjà. Dans un groupe, je peux m'ajouter moi-même
    //    depuis l'arbre public (§ 5.7) : c'est ce qui rend le groupe officiel
    //    d'une ville praticable, puisqu'on le rejoint automatiquement, souvent
    //    sans qu'aucun membre ne soit en ligne. Pour un 1:1, seulement pour
    //    reprendre sa propre place (voir `_jointureExternePossible`).
    if (await _delivery.currentEpoch(conversationId) != null) {
      if (await _jointureExternePossible(conversationId)) {
        // `conversations.mls_group_info` n'est republié qu'APRÈS le commit :
        // dans l'intervalle, il porte l'arbre de l'epoch d'avant. D'où la
        // garde, et quelques essais le temps que le committeur le republie.
        for (var essai = 1; ; essai++) {
          final arbre = await _delivery.groupInfo(conversationId);
          final epochCourant = await _delivery.currentEpoch(conversationId);
          if (arbre == null || epochCourant == null) break;
          final epoch = epochCourant + 1;
          final aad = MlsAad.commit(conversationId: conversationId, epoch: epoch);
          final out = await moteur.rejoindreParCommitExterne(
            conversationId: conversationId,
            groupInfo: arbre,
            aad: aad,
          );
          // Garde : rejoindre depuis l'arbre d'un epoch passé, puis publier
          // sous le numéro suivant du serveur, c'est ouvrir une branche que
          // personne ne pourra suivre — et le 2026-09-16 c'est arrivé. Ne
          // rien publier.
          final obtenu = (await moteur.instantane(conversationId: conversationId)).epoch.toInt();
          if (obtenu != epoch) {
            await moteur.oublierGroupe(conversationId: conversationId);
            if (essai < 3) {
              await Future<void>.delayed(const Duration(milliseconds: 800));
              continue;
            }
            await _delivery.diagnostic(userId, 'arbre_perime',
                deviceId: appareil.id, detail: {'attendu': epoch, 'obtenu': obtenu});
            break;
          }
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
            return _ensureGroup(conversationId);
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
      // Le gagnant m'ajoutera ; peut-être l'a-t-il déjà fait. `_ensureGroup`
      // et non `ensureGroup`, qui rendrait la jointure en cours — celle-ci :
      // elle s'attendrait elle-même.
      return _ensureGroup(conversationId);
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

  /// Qui peut entrer seul, depuis l'arbre public.
  ///
  /// **Un groupe** : tout participant — c'est ce qui rend le groupe officiel
  /// d'une ville praticable.
  ///
  /// **Un 1:1 (ou « Mes notes »)** : seulement un compte qui **y avait déjà
  /// un appareil**, c'est-à-dire qui reprend sa propre place après une
  /// réinstallation. Quelqu'un qu'on aurait glissé dans `participant_ids`
  /// d'une conversation à deux attend toujours d'y être invité.
  ///
  /// Refuser tout 1:1, comme avant, a coûté le 2026-09-16 : les deux
  /// téléphones de test réinstallés depuis le Play Store, la discussion
  /// chiffrée entre eux ne contenait plus que leurs deux ANCIENS appareils,
  /// effacés. Plus aucun membre vivant pour envoyer le Welcome, le serveur
  /// refusant le clair : la conversation était morte pour de bon, et chaque
  /// envoi finissait en « Non envoyé ». Aucune surface d'attaque de plus :
  /// `reconcileMembership` ajoute déjà d'office tout appareil actif d'un
  /// participant, dès qu'un membre écrit.
  Future<bool> _jointureExternePossible(String conversationId) async {
    final conv = await _delivery.conversation(conversationId);
    if (conv == null) return false;
    if ((conv['type'] as String?) == 'group') return true;
    final participants =
        ((conv['participant_ids'] as List?) ?? const []).cast<String>();
    if (!participants.contains(userId)) return false;
    return _delivery.aEuUnAppareilDans(conversationId, userId);
  }

  /// Aligne les membres du groupe sur les appareils actifs des participants
  /// (§ 5.4, 5.5) : ajoute ceux qui manquent, retire ceux qui n'ont plus
  /// d'appareil actif (révoqués, réinstallés). Les appareils sans KeyPackage
  /// restent `pending`, l'envoi part quand même vers les autres.
  Future<void> reconcileMembership(String conversationId, {int tentative = 0}) async {
    await catchUp(conversationId);
    final moteur = await _moteur();
    final appareil = await _appareil();
    await _refuserSiRevoque(appareil);
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

    final aAjouter = actifs
        .where((d) => !membres.containsKey(d.mlsIdentity))
        .where((d) => !_ajoutsEchoues.contains('$conversationId/${d.id}'))
        .toList();
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
      final epochAjout = snap.epoch.toInt() + 1;
      final out = paquets.isEmpty
          ? null
          : await _commitOuDiagnostic(
              moteur,
              conversationId,
              appareil,
              'ajout_membres_echoue',
              () => moteur.ajouterMembres(
                conversationId: conversationId,
                keyPackages: paquets,
                aad: MlsAad.commit(conversationId: conversationId, epoch: epochAjout),
              ),
              exclure: destinataires,
            );
      if (out != null) {
        final epoch = epochAjout;
        await _publierOuJeter(moteur, conversationId, () => _delivery.publishCommit(
              conversationId: conversationId,
              epoch: epoch,
              senderDeviceId: appareil.id,
              commit: out.commit,
              groupInfo: out.groupInfo,
            ));
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
      final retrait = aRetirer.isEmpty || _retraitsEchoues.contains(conversationId)
          ? null
          : await () async {
              final snap2 = await moteur.instantane(conversationId: conversationId);
              final epoch = snap2.epoch.toInt() + 1;
              final out = await _commitOuDiagnostic(
                moteur,
                conversationId,
                appareil,
                'retrait_membres_echoue',
                () => moteur.retirerMembres(
                  conversationId: conversationId,
                  leafIndices: aRetirer,
                  aad: MlsAad.commit(conversationId: conversationId, epoch: epoch),
                ),
              );
              if (out == null) _retraitsEchoues.add(conversationId);
              return out == null ? null : (out: out, epoch: epoch);
            }();
      if (retrait != null) {
        final (:out, :epoch) = retrait;
        await _publierOuJeter(moteur, conversationId, () => _delivery.publishCommit(
              conversationId: conversationId,
              epoch: epoch,
              senderDeviceId: appareil.id,
              commit: out.commit,
            ));
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

  /// Appareils dont l'ajout a échoué dans le moteur, par conversation
  /// (`conversation/appareil`), et conversations dont le retrait a échoué.
  /// Pour la durée du processus : réessayer à chaque envoi réclamait trois
  /// KeyPackages de plus par minute, pour un échec certain.
  final Set<String> _ajoutsEchoues = {};
  final Set<String> _retraitsEchoues = {};

  /// Fabrique un commit d'appartenance ; en cas d'échec **du moteur**, rend
  /// `null` au lieu de lever.
  ///
  /// L'appartenance est un entretien, pas une condition de l'envoi. Le
  /// 2026-09-16, le Samsung ne parvenait pas à ajouter au 1:1 trois
  /// anciennes installations effacées — et comme l'échec remontait, **aucun**
  /// message ne partait plus, vers personne, sans une ligne de diagnostic :
  /// « Non envoyé », à chaque essai. Désormais le motif s'écrit, le commit
  /// à moitié fait est jeté, et le message part vers les membres en place.
  Future<CommitDto?> _commitOuDiagnostic(
    Moteur moteur,
    String conversationId,
    MlsDeviceRecord appareil,
    String evenement,
    Future<CommitDto> Function() fabriquer, {
    List<String> exclure = const [],
  }) async {
    try {
      return await fabriquer();
    } catch (e) {
      await _jeterSansLever(moteur, conversationId);
      _ajoutsEchoues.addAll([for (final id in exclure) '$conversationId/$id']);
      await _delivery.diagnostic(userId, evenement,
          deviceId: appareil.id,
          detail: {
            'conversation': conversationId,
            'code': _code(e),
            if (exclure.isNotEmpty) 'combien': exclure.length,
          });
      return null;
    }
  }

  /// Publie un commit déjà fabriqué. Un échec autre qu'un conflict d'epoch
  /// (réseau, droits) jette le commit en attente avant de remonter : laissé
  /// en place, il ferait échouer tous les commits suivants de ce groupe.
  Future<void> _publierOuJeter(
    Moteur moteur,
    String conversationId,
    Future<void> Function() publier,
  ) async {
    try {
      await publier();
    } on EpochConflict {
      rethrow;
    } catch (_) {
      await _jeterSansLever(moteur, conversationId);
      rethrow;
    }
  }

  Future<void> _jeterSansLever(Moteur moteur, String conversationId) async {
    try {
      await moteur.jeterCommitEnAttente(conversationId: conversationId);
    } catch (_) {
      // Rien en attente : rien à jeter.
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
    await _refuserSiRevoque(appareil);
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
      // Provisoire, et remplacé trois lignes plus bas : `toInsert` n'envoie
      // pas `created_at`, c'est le serveur qui date la ligne.
      createdAt: DateTime.now().toUtc(),
      expiresAt: expiresAt,
    );
    final quandServeur = await _delivery.publishMessage(row);
    _vus.add(id);
    // L'horodatage du serveur fait foi dès qu'on l'a : l'aperçu de la liste
    // s'y raccroche pour reconnaître le dernier message, et l'échéance des
    // éphémères s'y compte. Le garder local, c'était laisser l'expéditeur
    // choisir les deux.
    return quandServeur == null ? row : row.avecCreatedAt(quandServeur);
  }

  /// Rattrapage : commits d'abord (par epoch), puis messages. Rend les
  /// messages **nouveaux** depuis le dernier appel, déchiffrés ou non.
  Future<List<MlsIncoming>> catchUp(String conversationId) async {
    if (!await estMembre(conversationId)) {
      // **Lire ne crée jamais le groupe.** Créer pose `mls_since`, qui est
      // définitif : le serveur refuse le clair ensuite, et rien ne revient en
      // arrière. Laisser la lecture créer revenait à geler une discussion en
      // l'ouvrant, sans que personne n'ait rien écrit.
      //
      // Ce n'est pas une crainte : en production, les trois premières
      // conversations basculées l'ont été **avant** leur premier message
      // chiffré — de 12, 88 et 126 secondes. C'est l'ouverture qui les a
      // gelées, pas un envoi.
      //
      // Sans groupe côté serveur, il n'y a de toute façon rien à lire : aucun
      // message MLS ne peut exister. On rend la main, et le fil s'affiche
      // depuis le legacy seul.
      if (await _delivery.currentEpoch(conversationId) == null) {
        return const [];
      }
      // Le groupe existe : le rejoindre est légitime en lecture — c'est
      // justement ce qu'il faut pour déchiffrer ce qu'on nous a envoyé.
      await ensureGroup(conversationId);
    }
    final moteur = await _moteur();
    final appareil = await _appareil();
    await _refuserSiRevoque(appareil);
    await _rattraperCommits(conversationId, moteur, appareil);

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
        await _rattraperCommits(conversationId, moteur, appareil);
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

  /// Rejoue les commits en attente ; si l'un d'eux échoue alors qu'un Welcome
  /// m'attend, oublie l'état local corrompu et rejoint proprement par ce
  /// Welcome avant de reprendre.
  ///
  /// **Ce que ça ferme.** `_traiterCommits` seul, à l'échec d'un commit, ne
  /// fait que journaliser et abandonner — pour toujours : au rattrapage
  /// suivant, `estMembre` répond encore vrai sur un état que plus personne
  /// en face ne reconnaît, donc `_ensureGroup` (le seul endroit qui regarde
  /// `welcomesFor`) n'est jamais appelé. Un pair qui m'a retiré puis
  /// réinvité (arbre divergé réparé par un vrai retrait + réinvitation)
  /// publie pourtant un Welcome tout neuf, qui reste invisible. Trouvé le
  /// 2026-09-17 sur le Pixel : retrait et réinvitation réussis côté
  /// serveur, jamais consommés côté appareil, le commit suivant rejouant le
  /// même `GroupStateError` à l'infini.
  Future<void> _rattraperCommits(
    String conversationId,
    Moteur moteur,
    MlsDeviceRecord appareil,
  ) async {
    await _traiterCommits(conversationId, moteur, appareil);
    if (await estMembre(conversationId)) return;
    await ensureGroup(conversationId);
    await _traiterCommits(conversationId, moteur, appareil);
  }

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
        final code = _code(e);
        final welcomes = await _delivery.welcomesFor(appareil.id, conversationId: conversationId);
        if (welcomes.isNotEmpty) {
          // Rejouer ce commit-là échouera toujours : l'arbre d'en face est
          // reparti d'un état que le mien ne peut plus suivre. Le Welcome,
          // lui, encode l'état complet au bon epoch — oublier le mien le
          // laisse faire foi au prochain `ensureGroup`.
          await moteur.oublierGroupe(conversationId: conversationId);
          await _delivery.diagnostic(userId, 'groupe_oublie_pour_welcome',
              deviceId: appareil.id, detail: {'code': code, 'epoch': c.epoch});
        } else {
          await _delivery.diagnostic(userId, 'commit_illisible', deviceId: appareil.id,
              detail: {'code': code, 'epoch': c.epoch});
        }
        break;
      }
      snap = await moteur.instantane(conversationId: conversationId);
    }
  }

  /// Un code, jamais un message libre (qui pourrait citer du contenu).
  static String _code(Object e) {
    final texte = e.toString();
    // `openmls:CreateCommitError` reste d'un bloc : coupé au deux-points, le
    // diagnostic ne disait que « openmls » — c'est ce que le Samsung a écrit
    // le 2026-09-16 pour un ajout de membres impossible, sans rien de plus.
    final m = RegExp(r'[A-Za-z_]+(?::[A-Za-z_]+)?')
        .allMatches(texte)
        .map((x) => x.group(0)!)
        .toList();
    // `AnyhowException(aad_mismatch)` → aad_mismatch
    final utile = m.where((s) => s != 'AnyhowException' && s != 'Exception').toList();
    final code = utile.isEmpty ? 'inconnue' : utile.first;
    return code.length > 60 ? code.substring(0, 60) : code;
  }

  @visibleForTesting
  static String codeDiagnostic(Object e) => _code(e);

  @visibleForTesting
  void oublierCurseur(String conversationId) {
    _curseur.remove(conversationId);
  }

  static void debugTrace(String message) => debugPrint('MlsConversationService: $message');
}
