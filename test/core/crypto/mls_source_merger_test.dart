import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_source_merger.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 2.3, phase 5)
/// ----------------------------------------------------
/// Une conversation qui bascule à MLS garde son historique : celui-ci est
/// gelé, lisible par le serveur, et ne peut pas être ré-encapsulé (produire
/// un ciphertext MLS exigerait des clés que personne ne doit avoir). Les deux
/// sources cohabitent donc dans le même fil, séparées par un repère visible.
///
/// Ce que ces tests empêchent, concrètement : un séparateur affiché sans
/// raison — qui ferait croire à l'utilisateur qu'une partie de ses messages
/// n'est pas chiffrée alors que tout l'est —, et un séparateur compté comme
/// un message par ce qui compte les messages.

MessageEntity _m(String id, DateTime quand, {String contenu = ''}) => MessageEntity(
      id: id,
      senderId: 'u1',
      senderName: 'Amina',
      content: contenu.isEmpty ? id : contenu,
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: quand,
    );

void main() {
  final t0 = DateTime(2026, 9, 1, 10);
  final bascule = DateTime(2026, 9, 15, 12);

  group('fusion des deux sources', () {
    test('legacy puis séparateur puis MLS, dans l’ordre', () {
      final fusion = MlsSourceMerger.fusionner(
        legacy: [_m('vieux1', t0), _m('vieux2', t0.add(const Duration(minutes: 1)))],
        mls: [_m('neuf1', bascule.add(const Duration(minutes: 1)))],
        mlsSince: bascule,
      );
      expect(fusion.map((m) => m.id), [
        'vieux1',
        'vieux2',
        MlsMessageMapper.idSeparateur,
        'neuf1',
      ]);
      // Le séparateur porte la date de bascule : il se range au bon endroit
      // si quelque chose retrie la liste.
      expect(fusion[2].createdAt, bascule);
      expect(fusion[2].type, MessageType.system);
    });

    test('aucun séparateur quand un seul côté a des messages', () {
      // Conversation qui n'a jamais rien reçu en MLS : rien à annoncer.
      expect(
        MlsSourceMerger.fusionner(legacy: [_m('a', t0)], mls: const [], mlsSince: bascule)
            .map((m) => m.id),
        ['a'],
      );
      // Conversation neuve, née après la bascule : tout est chiffré, et dire
      // « messages d'avant » au-dessus du premier message serait un mensonge.
      expect(
        MlsSourceMerger.fusionner(legacy: const [], mls: [_m('b', bascule)], mlsSince: bascule)
            .map((m) => m.id),
        ['b'],
      );
      expect(
        MlsSourceMerger.fusionner(legacy: const [], mls: const [], mlsSince: bascule),
        isEmpty,
      );
    });

    test('sans date de bascule, le séparateur prend celle du premier message MLS', () {
      final quand = bascule.add(const Duration(hours: 3));
      final fusion = MlsSourceMerger.fusionner(
        legacy: [_m('a', t0)],
        mls: [_m('b', quand)],
        mlsSince: null,
      );
      expect(fusion[1].createdAt, quand);
    });
  });

  group('le séparateur n’est pas un message', () {
    test('il se retire de ce qui compte', () {
      final fusion = MlsSourceMerger.fusionner(
        legacy: [_m('a', t0)],
        mls: [_m('b', bascule)],
        mlsSince: bascule,
      );
      expect(fusion, hasLength(3));
      expect(MlsSourceMerger.sansSeparateur(fusion).map((m) => m.id), ['a', 'b']);
    });

    test('son identifiant est réservé et reconnaissable', () {
      expect(MlsMessageMapper.estSeparateur(MlsMessageMapper.separateur(bascule)), isTrue);
      expect(MlsMessageMapper.estSeparateur(_m('a', t0)), isFalse);
      // Un vrai identifiant ne peut pas ressembler à celui-là : les messages
      // portent des uuid ou des identifiants Firestore.
      expect(MlsMessageMapper.idSeparateur.startsWith('__'), isTrue);
    });
  });

  group('câblage — inerte tant que rien ne l’active', () {
    String source(String c) =>
        File(c).readAsStringSync().replaceAll('\r\n', '\n');

    test('sans passerelle injectée, le repository se comporte comme avant', () {
      final repo = source('lib/features/messages/data/repositories/message_repository_impl.dart');
      // Le champ est nullable, et chaque chemin sort tôt quand il est nul :
      // pas un appel réseau de plus tant que rien n'est branché.
      expect(repo, contains('final MlsGateway? mlsGateway;'));
      expect(repo, contains('if (passerelle == null) return legacy;'));
      expect(repo, contains('Future<MlsGateway?> _passerellePour('));
      expect(repo, contains('if (passerelle == null) return null;'));
    });

    test('une conversation basculée n’a pas de repli en clair', () {
      final repo = source('lib/features/messages/data/repositories/message_repository_impl.dart');
      // Le repli n'existe que tant que rien n'est engagé ; après la bascule,
      // l'échec remonte. C'est le repli muet qui a laissé Signal envoyer en
      // clair pendant des semaines.
      expect(repo, contains('if (!await passerelle.repliLegacyPossible(conversationId)) rethrow;'));
    });

    test('la passerelle ne dépend que de l’identifiant utilisateur', () {
      final p = source('lib/core/crypto/mls/mls_providers.dart');
      final debut = p.indexOf('final mlsGatewayProvider');
      final corps = p.substring(debut);
      // `ref.watch` reconstruirait la passerelle à la moindre invalidation
      // d'un autre provider — la panne exacte du chantier Signal. Seul l'uid
      // est observé : lu une fois, il figeait la passerelle à `null` au
      // démarrage à froid (voir `uid_firebase_provider_test.dart`).
      final observes = RegExp(r'ref\.watch\(([^)]*)\)')
          .allMatches(corps)
          .map((m) => m.group(1))
          .toList();
      expect(observes, ['uidFirebaseProvider']);
      expect(corps, contains('ref.read(mlsMessagesActifsProvider)'));
    });

    test('les messages MLS sont mis en cache pour le mode hors ligne', () {
      final repo = source('lib/features/messages/data/repositories/message_repository_impl.dart');
      // Par `jsonPourCacheMls`, qui vide un message supprimé pour tous avant
      // de l'écrire (tenu par `mls_metadonnees_test.dart`).
      expect(repo, contains('jsonPourCacheMls(mls)'));
      expect(repo, contains('jsonPourCacheMls(fil)'));
    });

    test('un média dans une conversation chiffrée l’est forcément', () {
      // Le drapeau des pièces jointes ne décide que des conversations encore
      // en clair : dans une conversation MLS, un média en clair serait refusé
      // par le serveur, et l'envoi échouerait sans cause lisible.
      final repo = source('lib/features/messages/data/repositories/message_repository_impl.dart');
      expect(repo, contains('(mediasChiffresActifs() || conversationChiffree)'));
    });

    test('CHAQUE type de message passe par la passerelle', () {
      // La garde qui compte. Un type oublié partirait vers `messages`, que le
      // serveur refuse pour une conversation basculée : l'envoi échouerait
      // sans que rien n'explique pourquoi, et seulement une fois le drapeau
      // ouvert — c'est-à-dire trop tard.
      final repo = source('lib/features/messages/data/repositories/message_repository_impl.dart');
      const methodes = [
        'sendTextMessage',
        'sendFileMessage',
        'sendAudioMessage',
        'sendLocationMessage',
        'sendPollMessage',
        'sendStickerMessage',
      ];
      for (final methode in methodes) {
        final debut = repo.indexOf('Future<Either<Failure, MessageEntity>> $methode(');
        expect(debut, greaterThan(-1), reason: methode);
        // Fin de la méthode : le début de la suivante, ou la fin du fichier.
        final suivante = repo.indexOf('Future<Either<Failure, MessageEntity>> ', debut + 10);
        final corps = repo.substring(debut, suivante == -1 ? repo.length : suivante);
        // `sendFileMessage` délègue à `_envoyerMediaChiffre`, qui porte le
        // branchement : suivre la délégation plutôt que l'exiger sur place.
        final passeParMls = corps.contains('_passerellePour(conversationId)') ||
            corps.contains('_envoyerMediaChiffre(');
        expect(passeParMls, isTrue, reason: methode);
      }
    });
  });

  group('type de contenu annoncé au serveur', () {
    test('grossier par construction : il est visible du serveur', () {
      expect(MlsMessageMapper.contentType('text'), 'text');
      // Une photo et une vidéo sont indiscernables côté serveur.
      expect(MlsMessageMapper.contentType('image'), 'media');
      expect(MlsMessageMapper.contentType('video'), 'media');
      expect(MlsMessageMapper.contentType('file'), 'media');
      expect(MlsMessageMapper.contentType('voiceNote'), 'voice');
      expect(MlsMessageMapper.contentType('sticker'), 'sticker');
      // Un type inconnu ne fuit pas : il passe pour du texte.
      expect(MlsMessageMapper.contentType('type_futur'), 'text');
    });
  });
}
