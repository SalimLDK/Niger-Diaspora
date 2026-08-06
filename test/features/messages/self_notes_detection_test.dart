import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';

/// Garde-fou sur `ConversationEntity.isSelfNotesFor`.
///
/// Le prédicat ne testait que « un seul participant, et c'est moi ». Or c'est
/// vrai aussi d'un GROUPE qu'on vient de créer et que personne n'a rejoint.
/// Constaté sur appareil le 2026-08-05, avec quatre conséquences :
/// le groupe disparaissait de la liste des messages (retiré comme doublon)
/// tout en alimentant la tuile « Mes notes », il restait pourtant compté dans
/// le « N groupes actifs » de l'en-tête, son en-tête de conversation affichait
/// « Mes notes » à la place du nom, et surtout ses messages partaient chiffrés
/// en note vers soi (AES global) au lieu du chemin de groupe.
///
/// Ces cas sont peu coûteux à vérifier et la régression serait silencieuse —
/// aucune exception, juste une conversation rangée au mauvais endroit.
void main() {
  const moi = 'user-moi';
  const autre = 'user-autre';

  ConversationEntity conv({
    required ConversationType type,
    required List<String> participants,
    String? groupId,
  }) => ConversationEntity(
    id: 'c1',
    type: type,
    groupId: groupId,
    participantIds: participants,
    createdAt: DateTime(2026),
    createdBy: moi,
  );

  group('isSelfNotesFor', () {
    test('vraie conversation avec soi-même : un seul participant, c\'est moi', () {
      final c = conv(
        type: ConversationType.individual,
        participants: [moi],
      );
      expect(c.isSelfNotesFor(moi), isTrue);
    });

    test('GROUPE dont je suis le seul membre : ce n\'est PAS « Mes notes »', () {
      final c = conv(
        type: ConversationType.group,
        participants: [moi],
        groupId: 'g1',
      );
      expect(c.isSelfNotesFor(moi), isFalse);
    });

    test('groupe à un seul membre SANS group_id : toujours pas « Mes notes »', () {
      // Le type suffit : `groupId` peut manquer sur une conversation ancienne.
      final c = conv(
        type: ConversationType.group,
        participants: [moi],
      );
      expect(c.isSelfNotesFor(moi), isFalse);
    });

    test('conversation typée individual mais portant un group_id : exclue', () {
      // Symétrique du cas précédent : le type peut ne pas avoir été posé alors
      // que le group_id, lui, est renseigné.
      final c = conv(
        type: ConversationType.individual,
        participants: [moi],
        groupId: 'g1',
      );
      expect(c.isSelfNotesFor(moi), isFalse);
    });

    test('DM à deux participants : pas « Mes notes »', () {
      final c = conv(
        type: ConversationType.individual,
        participants: [moi, autre],
      );
      expect(c.isSelfNotesFor(moi), isFalse);
    });

    test('conversation à un seul participant qui n\'est pas moi : pas mes notes', () {
      final c = conv(
        type: ConversationType.individual,
        participants: [autre],
      );
      expect(c.isSelfNotesFor(moi), isFalse);
    });
  });
}
