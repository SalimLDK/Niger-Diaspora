import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// `MlsMessageRow.toInsert` **n'envoie pas** `created_at` : la colonne a son
/// défaut serveur. L'expéditeur en fabriquait pourtant un de son côté, au
/// moment de chiffrer, et le gardait sans jamais lire ce que le serveur avait
/// retenu — deux valeurs pour la même ligne.
///
/// Ce que ça coûte tient à ce que cet horodatage sert à deux choses :
///
///   - l'échéance d'un message éphémère, que `MlsMessageMapper` compte depuis
///     `row.createdAt` en le décrivant, en commentaire, comme « le seul
///     horodatage que l'expéditeur ne choisit pas » — ce qu'il n'était pas
///     pour ses propres messages. Une horloge de téléphone décalée de
///     quelques minutes décale d'autant la durée de vie réelle de la note ;
///   - l'aperçu de la liste des discussions, qui n'a que lui pour reconnaître
///     dans le cache local le message que le serveur annonce comme dernier.
///
/// **La latence seule ne cassait pas l'aperçu** : la garde tronque à la
/// seconde, donc absorbe l'aller-retour. C'est un décalage d'horloge qui le
/// casse. Ces tests tiennent les deux bords de cette tolérance, pour qu'on ne
/// la resserre ni ne l'élargisse par accident.
///
/// La régression serait silencieuse des deux côtés : un aperçu générique ne
/// ressemble pas à un bug, et une échéance décalée ne se voit pas du tout.
void main() {
  MlsMessageRow ligne({DateTime? quand}) => MlsMessageRow(
    id: 'm1',
    conversationId: 'c1',
    senderId: 'u1',
    senderDeviceId: 'd1',
    epoch: 3,
    kind: 'content',
    contentType: 'text',
    ciphertext: Uint8List.fromList(const [1, 2, 3]),
    replyToId: 'm0',
    editedAt: DateTime.utc(2026, 9, 15, 10),
    createdAt: quand ?? DateTime.utc(2026, 9, 15, 22, 34, 1, 100),
    expiresAt: DateTime.utc(2026, 9, 16),
  );

  group('avecCreatedAt ne touche qu’à l’horodatage', () {
    final serveur = DateTime.utc(2026, 9, 15, 22, 34, 1, 419);
    final avant = ligne();
    final apres = avant.avecCreatedAt(serveur);

    test('la nouvelle valeur est celle du serveur', () {
      expect(apres.createdAt, serveur);
      expect(avant.createdAt, isNot(serveur), reason: 'la source est intacte');
    });

    test('tout le reste est reporté, ciphertext compris', () {
      expect(apres.id, avant.id);
      expect(apres.conversationId, avant.conversationId);
      expect(apres.senderId, avant.senderId);
      expect(apres.senderDeviceId, avant.senderDeviceId);
      expect(apres.epoch, avant.epoch);
      expect(apres.kind, avant.kind);
      expect(apres.contentType, avant.contentType);
      expect(apres.ciphertext, avant.ciphertext);
      expect(apres.replyToId, avant.replyToId);
      expect(apres.isDeleted, avant.isDeleted);
      expect(apres.editedAt, avant.editedAt);
      // `expires_at` est une aide au balayage du serveur, pas une autorité :
      // l'échéance qui fait foi se recalcule depuis le `ttl` du payload. Elle
      // n'a donc pas à suivre la correction.
      expect(apres.expiresAt, avant.expiresAt);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // La tolérance de la garde d'aperçu, des deux côtés
  // ═══════════════════════════════════════════════════════════════════════
  group("l'aperçu se raccroche à l'horodatage du serveur", () {
    final quandServeur = DateTime.utc(2026, 9, 15, 22, 34, 1, 419);

    ConversationEntity conv({DateTime? annonce}) => ConversationEntity(
      id: 'c1',
      type: ConversationType.individual,
      participantIds: const ['u1'],
      createdBy: 'u1',
      createdAt: DateTime.utc(2026, 9),
      // Le serveur n'a jamais le clair d'un message MLS : l'aperçu est vide,
      // et c'est le cache local qui doit le reconstituer.
      lastMessage: '',
      lastMessageAt: annonce ?? quandServeur,
    );

    List<Map<String, dynamic>> cacheA(DateTime quand) => [
      {
        'id': 'm1',
        'createdAt': quand.toIso8601String(),
        'content': 'VERIF-RACCOURCI-2234',
      },
    ];

    test('horodatage du serveur : la note s’affiche', () {
      expect(
        MessageRepositoryImpl.apercuDepuisCache(
          conv(),
          () => cacheA(quandServeur),
        ).lastMessage,
        'VERIF-RACCOURCI-2234',
      );
    });

    test('la latence d’un envoi est absorbée : la garde tronque à la seconde', () {
      // 319 ms d'aller-retour, la même seconde : l'aperçu passe. C'est
      // pourquoi l'écart d'horodatage ne se voyait pas en usage normal.
      expect(
        MessageRepositoryImpl.apercuDepuisCache(
          conv(),
          () => cacheA(quandServeur.subtract(const Duration(milliseconds: 319))),
        ).lastMessage,
        'VERIF-RACCOURCI-2234',
      );
    });

    test('un décalage d’horloge, lui, fait tout perdre', () {
      // Le cas que la correction supprime : le téléphone datait la ligne
      // lui-même, avec son horloge à lui.
      expect(
        MessageRepositoryImpl.apercuDepuisCache(
          conv(),
          () => cacheA(quandServeur.subtract(const Duration(seconds: 90))),
        ).lastMessage,
        isEmpty,
      );
    });

    test('un cache en retard reste écarté — la garde ne s’assouplit pas', () {
      // La correction porte sur la valeur écrite, pas sur la comparaison : un
      // message caché qui n'est PAS le dernier ne doit toujours pas devenir
      // l'aperçu, sinon on afficherait un texte faux sans que rien ne le dise.
      expect(
        MessageRepositoryImpl.apercuDepuisCache(
          conv(),
          () => cacheA(quandServeur.subtract(const Duration(hours: 2))),
        ).lastMessage,
        isEmpty,
      );
    });

    test('liste hors ligne, plus vieille que le cache du fil : rien non plus', () {
      // Ce qui a été pris pour un défaut sur le SM A515F le 2026-09-15 : la
      // liste venait du cache Hive (donc annonçait le message d'AVANT), le
      // cache du fil, lui, portait la note qu'on venait d'écrire. La garde
      // refuse, et elle a raison — elle ne peut pas savoir laquelle des deux
      // sources est en retard.
      expect(
        MessageRepositoryImpl.apercuDepuisCache(
          conv(annonce: quandServeur.subtract(const Duration(minutes: 30))),
          () => cacheA(quandServeur),
        ).lastMessage,
        isEmpty,
      );
    });
  });
}
