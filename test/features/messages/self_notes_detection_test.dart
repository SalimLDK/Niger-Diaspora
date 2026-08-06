import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';

/// « Mes notes » se reconnaît à son unique participant. Un groupe dont on est
/// le seul membre — tout groupe fraîchement créé — a la même signature, et
/// passait pour une conversation avec soi-même : compté dans « N groupes
/// actifs » en en-tête, mais retiré de la liste, dont il devenait invisible.
void main() {
  ConversationEntity build({
    required ConversationType type,
    required List<String> participantIds,
  }) => ConversationEntity(
    id: 'c1',
    type: type,
    participantIds: participantIds,
    createdAt: DateTime(2026, 1, 1),
    createdBy: participantIds.first,
  );

  group('isSelfNotesFor', () {
    test('reconnaît la conversation avec soi-même', () {
      final conv = build(
        type: ConversationType.individual,
        participantIds: const ['moi'],
      );
      expect(conv.isSelfNotesFor('moi'), isTrue);
    });

    test('un groupe dont je suis le seul membre n\'est pas « Mes notes »', () {
      final conv = build(
        type: ConversationType.group,
        participantIds: const ['moi'],
      );
      expect(conv.isSelfNotesFor('moi'), isFalse);
    });

    test('une conversation à deux n\'est pas « Mes notes »', () {
      final conv = build(
        type: ConversationType.individual,
        participantIds: const ['moi', 'autre'],
      );
      expect(conv.isSelfNotesFor('moi'), isFalse);
    });

    test('la conversation d\'un tiers avec lui-même ne m\'appartient pas', () {
      final conv = build(
        type: ConversationType.individual,
        participantIds: const ['autre'],
      );
      expect(conv.isSelfNotesFor('moi'), isFalse);
    });
  });
}
