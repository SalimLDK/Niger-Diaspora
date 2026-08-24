import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/utils/message_grouping.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_bubble.dart'
    show MessageGroupPosition;

/// La liste de l'écran de discussion est **inversée** : index 0 = le message
/// le plus récent. Les cas ci-dessous se lisent donc de bas en haut.
MessageEntity msg(String expediteur, DateTime quand) => MessageEntity(
  id: '$expediteur-${quand.millisecondsSinceEpoch}',
  senderId: expediteur,
  senderName: expediteur,
  content: 'x',
  type: MessageType.text,
  createdAt: quand,
);

MessageGroupPosition positionA(List<MessageEntity> liste, int index) =>
    positionDansRafale(
      liste,
      index,
      hasDateBreak: false,
      hasNextDateBreak: false,
    );

void main() {
  final base = DateTime(2026, 8, 23, 9, 0);

  group('une rafale = même expéditeur ET moins de 15 minutes', () {
    test('trois messages serrés : seul le plus récent est "last"', () {
      // Inversé : index 0 = 09:04 (le plus récent), index 2 = 09:00.
      final liste = [
        msg('alice', base.add(const Duration(minutes: 4))),
        msg('alice', base.add(const Duration(minutes: 2))),
        msg('alice', base),
      ];

      // "last" = chronologiquement le dernier, celui qui porte l'heure.
      expect(positionA(liste, 0), MessageGroupPosition.last);
      expect(positionA(liste, 1), MessageGroupPosition.middle);
      expect(positionA(liste, 2), MessageGroupPosition.first);
    });

    test('un écart de plus de 15 min coupe la rafale en deux', () {
      // 09:00 puis 18:00 : le message du matin doit redevenir isolé, donc
      // afficher son heure. C'est tout l'objet du seuil.
      final liste = [
        msg('alice', DateTime(2026, 8, 23, 18, 0)),
        msg('alice', base),
      ];

      expect(positionA(liste, 0), MessageGroupPosition.single);
      expect(positionA(liste, 1), MessageGroupPosition.single);
    });

    test('exactement 15 min reste la même rafale, 15 min et 1 s la coupe', () {
      final pile = [
        msg('alice', base.add(kDureeRafale)),
        msg('alice', base),
      ];
      expect(positionA(pile, 0), MessageGroupPosition.last);

      final juste = [
        msg('alice', base.add(kDureeRafale + const Duration(seconds: 1))),
        msg('alice', base),
      ];
      expect(positionA(juste, 0), MessageGroupPosition.single);
    });

    test('deux expéditeurs proches dans le temps ne se groupent pas', () {
      final liste = [
        msg('bob', base.add(const Duration(minutes: 1))),
        msg('alice', base),
      ];

      expect(positionA(liste, 0), MessageGroupPosition.single);
      expect(positionA(liste, 1), MessageGroupPosition.single);
    });
  });

  group('séparateur de date', () {
    test('un message sous un séparateur ouvre une rafale, pas la ferme', () {
      final liste = [
        msg('alice', DateTime(2026, 8, 23, 9, 5)),
        msg('alice', DateTime(2026, 8, 23, 9, 0)),
        msg('alice', DateTime(2026, 8, 22, 20, 0)),
      ];

      // Le plus ancien du jour (index 1) porte le séparateur au-dessus de lui.
      expect(
        positionDansRafale(
          liste,
          1,
          hasDateBreak: true,
          hasNextDateBreak: false,
        ),
        MessageGroupPosition.first,
      );
    });

    test('seul message de sa journée : isolé', () {
      final liste = [
        msg('alice', DateTime(2026, 8, 23, 9, 0)),
        msg('alice', DateTime(2026, 8, 22, 20, 0)),
      ];

      expect(
        positionDansRafale(
          liste,
          0,
          hasDateBreak: true,
          hasNextDateBreak: false,
        ),
        MessageGroupPosition.single,
      );
    });
  });

  test('memeRafale est symétrique dans le temps', () {
    final tot = msg('alice', base);
    final tard = msg('alice', base.add(const Duration(minutes: 5)));
    expect(memeRafale(tot, tard), isTrue);
    expect(memeRafale(tard, tot), isTrue);
  });
}
