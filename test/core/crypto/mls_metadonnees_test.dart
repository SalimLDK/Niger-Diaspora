import 'dart:io';
import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_metadonnees.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 4, décision J)
/// -----------------------------------------------------
/// Réagir, étoiler, masquer, supprimer, accuser réception : tous ces gestes
/// écrivaient dans `messages`, où un message MLS n'a **aucune ligne**. Rien
/// ne l'aurait dit : un `update … where id = …` sans cible réussit avec zéro
/// ligne, et Supabase ne s'en plaint pas. Le geste aurait simplement paru
/// « ne pas prendre » — la forme muette des refus que ce dépôt connaît bien.
///
/// Deux propriétés valent la peine d'être tenues :
///
/// 1. **L'aiguillage se fait par message, pas par conversation.** Une
///    discussion basculée garde son historique en clair juste au-dessus du
///    séparateur : réagir à l'un de ces anciens messages doit continuer
///    d'écrire dans `messages`.
/// 2. **Le fil recolle ses métadonnées.** Le déchiffrement ne rend que le
///    contenu ; sans le second passage, un fil basculé s'afficherait sans
///    réactions, sans coches et sans favoris — encore muettement.

MlsMessageRow _ligne(String id, {String expediteur = 'u2'}) => MlsMessageRow(
      id: id,
      conversationId: 'c1',
      senderId: expediteur,
      senderDeviceId: 'd1',
      epoch: 1,
      kind: 'content',
      contentType: 'text',
      ciphertext: Uint8List.fromList([1]),
      createdAt: DateTime.utc(2026, 9, 15, 12),
    );

MlsPayload _payload(String id) => MlsPayload(
      id: id,
      type: 'text',
      sentAt: 0,
      body: {'content': 'bonjour'},
    );

/// Le transport, sans réseau.
class _TransportFige extends MlsDelivery {
  _TransportFige(this.mlsSince) : super(ensureAuth: (() async => true));

  final String? mlsSince;

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': const <String>['u1', 'u2'],
        'mls_since': mlsSince,
      };
}

/// Le service, sans moteur : il rend un fil déjà déchiffré.
class _ServiceFige extends MlsConversationService {
  _ServiceFige(this.fil)
      : super(
          userId: 'u1',
          moteur: () => throw StateError('le moteur ne doit pas être demandé'),
          delivery: _TransportFige(null),
          appareil: () => throw StateError('inutile ici'),
        );

  final List<MlsIncoming> fil;
  MlsMessageRow? dernierEnvoi;

  @override
  Future<List<MlsIncoming>> catchUp(String conversationId) async => fil;

  @override
  Future<void> ensureGroup(String conversationId) async {}

  @override
  Future<void> reconcileMembership(String conversationId,
      {int tentative = 0}) async {}

  @override
  Future<MlsMessageRow> send(
    String conversationId,
    MlsPayload payload, {
    String kind = 'content',
    String contentType = 'text',
  }) async =>
      dernierEnvoi = _ligne(payload.id.isEmpty ? 'm-neuf' : payload.id,
          expediteur: 'u1');
}

/// Les tables annexes, sans base : on compte les appels et on rend ce qu'on
/// veut voir recollé.
class _MetaEspion extends MlsMetadonnees {
  _MetaEspion({this.lot = MlsMetadonneesLot.vide, this.presents = const {}})
      : super(userId: 'u1', ensureAuth: (() async => true));

  final MlsMetadonneesLot lot;
  final Set<String> presents;

  int interrogations = 0;
  final List<String> reactionsPosees = [];
  final List<String> reactionsRetirees = [];
  final List<String> masques = [];
  final List<String> supprimes = [];
  final List<String> mentionsPosees = [];
  final List<String> marques = [];
  bool luDemande = false;

  @override
  Future<MlsMetadonneesLot> pour(Iterable<String> messageIds) async => lot;

  @override
  Future<bool> existe(String messageId) async {
    interrogations++;
    return presents.contains(messageId);
  }

  @override
  Future<void> poserReaction(String messageId, String emoji) async =>
      reactionsPosees.add('$messageId:$emoji');

  @override
  Future<void> retirerReaction(String messageId) async =>
      reactionsRetirees.add(messageId);

  @override
  Future<void> masquer(String messageId) async => masques.add(messageId);

  @override
  Future<void> supprimerPourTous(String messageId) async =>
      supprimes.add(messageId);

  @override
  Future<void> poserMentions(String messageId, Iterable<String> userIds) async =>
      mentionsPosees.addAll([for (final u in userIds) '$messageId:$u']);

  @override
  Future<List<String>> messagesDesAutres(String conversationId) async =>
      const ['m1', 'm2'];

  @override
  Future<void> marquer(Iterable<String> messageIds, {required bool lu}) async {
    luDemande = lu;
    marques.addAll(messageIds);
  }
}

MlsGateway _passerelle(
  _ServiceFige service,
  _MetaEspion meta, {
  String? mlsSince = '2026-09-15T00:00:00Z',
  bool actif = true,
}) =>
    MlsGateway(
      userId: 'u1',
      actif: () => actif,
      service: service,
      delivery: _TransportFige(mlsSince),
      metadonnees: meta,
      nomDe: (id) async => 'Nom',
    );

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('Le fil recolle ses métadonnées', () {
    test('réactions, lecteurs, favoris et masquage arrivent sur les bulles',
        () async {
      final service = _ServiceFige([
        MlsIncoming(_ligne('m1'), payload: _payload('m1')),
        MlsIncoming(_ligne('m2'), payload: _payload('m2')),
      ]);
      final meta = _MetaEspion(
        lot: MlsMetadonneesLot(
          reactions: const {
            'm1': {'u1': '👍', 'u2': '❤️'}
          },
          lecteurs: const {
            'm1': ['u1']
          },
          luA: {
            'm1': {'u1': DateTime.utc(2026, 9, 15, 13)}
          },
          etoiles: const {'m2'},
          masques: const {'m2'},
        ),
      );

      final fil = await _passerelle(service, meta).messages('c1');

      expect(fil.first.reactions, {'u1': '👍', 'u2': '❤️'});
      expect(fil.first.readBy, ['u1']);
      expect(fil[1].starredBy, ['u1']);
      // « Supprimer pour moi » n'efface pas la bulle du fil : il la marque, et
      // c'est `isDeletedFor` que l'écran consulte pour la cacher.
      expect(fil[1].isDeletedFor('u1'), isTrue);
      expect(fil.first.isDeletedFor('u1'), isFalse);
    });

    test('un fil sans métadonnées reste affichable', () async {
      final service = _ServiceFige([
        MlsIncoming(_ligne('m1'), payload: _payload('m1')),
      ]);

      final fil = await _passerelle(service, _MetaEspion()).messages('c1');

      expect(fil, hasLength(1));
      expect(fil.first.reactions, isEmpty);
      // L'expéditeur a forcément lu le sien : aucune ligne de reçu ne le dira.
      expect(fil.first.readBy, isEmpty, reason: 'm1 est de u2, pas de u1');
    });
  });

  group("L'aiguillage se fait par message", () {
    test('un message du fil est reconnu sans interroger la base', () async {
      final service = _ServiceFige([
        MlsIncoming(_ligne('m1'), payload: _payload('m1')),
      ]);
      final meta = _MetaEspion();
      final passerelle = _passerelle(service, meta);

      await passerelle.messages('c1');

      expect(await passerelle.estMlsMessage('c1', 'm1'), isTrue);
      expect(meta.interrogations, 0,
          reason: 'un message qu\'on vient de lire ne se redemande pas');
    });

    test('une conversation jamais basculée ne consulte rien', () async {
      final meta = _MetaEspion();
      final passerelle = _passerelle(_ServiceFige(const []), meta,
          mlsSince: null, actif: false);

      expect(await passerelle.estMlsMessage('c1', 'vieux-message'), isFalse);
      expect(meta.interrogations, 0);
    });

    test(
        'un message inconnu dans une conversation basculée est demandé à la base',
        () async {
      final meta = _MetaEspion(presents: const {'m-recu'});
      final passerelle = _passerelle(_ServiceFige(const []), meta);

      expect(await passerelle.estMlsMessage('c1', 'm-recu'), isTrue);
      expect(meta.interrogations, 1);

      // Et la réponse est retenue : deux actions d'affilée sur le même
      // message ne coûtent pas deux allers-retours.
      expect(await passerelle.estMlsMessage('c1', 'm-recu'), isTrue);
      expect(meta.interrogations, 1);
    });

    test('un ancien message en clair d\'une conversation basculée reste legacy',
        () async {
      // Le cas qui justifie l'aiguillage par message : la conversation EST
      // basculée, mais ce message-là est d'avant le séparateur.
      final meta = _MetaEspion(presents: const {});
      final passerelle = _passerelle(_ServiceFige(const []), meta);

      expect(await passerelle.estMlsMessage('c1', 'avant-la-bascule'), isFalse);
    });
  });

  group('Les actions écrivent dans la bonne table', () {
    test('réagir, retirer, masquer, supprimer', () async {
      final meta = _MetaEspion();
      final passerelle = _passerelle(_ServiceFige(const []), meta);

      await passerelle.reagir('m1', '👍');
      await passerelle.retirerReaction('m2');
      await passerelle.supprimerPourMoi('m3');
      await passerelle.supprimerPourTous('m4');

      expect(meta.reactionsPosees, ['m1:👍']);
      expect(meta.reactionsRetirees, ['m2']);
      expect(meta.masques, ['m3']);
      expect(meta.supprimes, ['m4']);
    });

    test('accuser lecture couvre les messages des autres', () async {
      final meta = _MetaEspion();
      final passerelle = _passerelle(_ServiceFige(const []), meta);

      await passerelle.marquerLus('c1');

      expect(meta.marques, ['m1', 'm2']);
      expect(meta.luDemande, isTrue);
    });

    test('les mentions sont posées après l\'envoi, jamais avant', () async {
      final service = _ServiceFige(const []);
      final meta = _MetaEspion();
      final passerelle = _passerelle(service, meta);

      await passerelle.envoyer(
        conversationId: 'c1',
        type: 'text',
        body: const {'content': 'salut @bob'},
        senderName: 'Moi',
        mentions: const ['u2'],
      );

      // Le RLS réserve l'insertion à l'expéditeur du message : la ligne doit
      // exister avant. Une mention posée d'abord serait refusée — en silence.
      expect(meta.mentionsPosees, ['m-neuf:u2']);
      expect(service.dernierEnvoi, isNotNull);
    });

    test('un envoi sans mention n\'écrit aucune ligne', () async {
      final meta = _MetaEspion();
      await _passerelle(_ServiceFige(const []), meta).envoyer(
        conversationId: 'c1',
        type: 'text',
        body: const {'content': 'salut'},
        senderName: 'Moi',
      );

      expect(meta.mentionsPosees, isEmpty);
    });
  });

  group('Aucune mutation de message n\'oublie l\'aiguillage', () {
    // Garde structurelle, pas de comportement : un jour quelqu'un ajoutera
    // une action sur un message (épingler, transférer en place…) et la
    // branchera sur `remoteDataSource` sans y penser. Elle écrirait dans
    // `messages`, sans cible, et réussirait à vide.
    final source =
        _source('lib/features/messages/data/repositories/message_repository_impl.dart');

    /// Le corps d'une méthode, borné à la suivante.
    ///
    /// Une fenêtre de taille fixe ne vaut rien ici : elle déborde sur la
    /// méthode d'après, qui contient le même appel, et le test passe alors
    /// même quand la garde a disparu. Vérifié en retirant l'aiguillage de
    /// `deleteMessageForMe` — la borne au `@override` suivant le voit, la
    /// fenêtre fixe non.
    String corpsDe(String methode) {
      final debut = source.indexOf('> $methode(');
      expect(debut, isNot(-1), reason: '$methode a disparu du repository');
      final suivante = source.indexOf('\n  @override', debut);
      return source.substring(debut, suivante == -1 ? source.length : suivante);
    }

    for (final methode in const [
      'deleteMessageForMe',
      'deleteMessageForEveryone',
      'toggleStarMessage',
      'toggleReaction',
      'editMessage',
    ]) {
      test('$methode consulte la passerelle', () {
        expect(corpsDe(methode), contains('_passerelleMessage'),
            reason: '$methode écrirait dans `messages` pour un message MLS');
      });
    }

    for (final methode in const ['markAsRead', 'markAsDelivered']) {
      test('$methode consulte la passerelle', () {
        expect(corpsDe(methode), contains('_passerellePour'),
            reason: '$methode n\'accuserait rien sur une conversation basculée');
      });
    }
  });
}
