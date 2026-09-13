import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/messages/presentation/widgets/event_message_card.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/post_message_card.dart';

/// Pixel, discussion avec Sim A, 2026-09-12 : dans une bulle envoyée (vert
/// `#009600`), le nom de l'auteur et « Voir la publication → » étaient en
/// sarcelle, l'en-tête et « Voir l'événement → » en violet — illisibles. Et le
/// texte généré par le partage répétait la carte juste en dessous.
void main() {
  const post = {'postId': 'p1', 'authorName': 'Salim L.', 'content': 'In kwana'};
  const event = {
    'eventId': 'e1',
    'title': 'test',
    'startDate': '2026-09-13T22:00:00Z',
    'location': 'CA',
  };

  Future<void> pump(WidgetTester tester, Widget carte) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColoredBox(color: const Color(0xFF009600), child: carte),
          ),
        ),
      );

  Color? couleurDe(WidgetTester tester, String texte) =>
      tester.widget<Text>(find.text(texte)).style?.color;

  testWidgets('post envoyé : auteur et lien en blanc', (tester) async {
    await pump(tester, const PostMessageCard(postData: post, isMe: true));
    expect(couleurDe(tester, 'Salim L.'), Colors.white);
    expect(couleurDe(tester, 'Voir la publication →'), Colors.white);
  });

  testWidgets('événement envoyé : en-tête, titre et lien en blanc', (
    tester,
  ) async {
    await pump(tester, const EventMessageCard(eventData: event, isMe: true));
    expect(couleurDe(tester, 'Événement'), Colors.white);
    expect(couleurDe(tester, 'test'), Colors.white);
    expect(couleurDe(tester, 'Voir l\'événement →'), Colors.white);
  });

  test('le texte généré par le partage est reconnu, pas celui de l\'utilisateur', () {
    expect(PostMessageCard.isDefaultCaption('📌 Post de Salim L.', post), isTrue);
    expect(PostMessageCard.isDefaultCaption('📌 Salim L.', post), isTrue);
    expect(PostMessageCard.isDefaultCaption('Regarde ça !', post), isFalse);
    expect(EventMessageCard.isDefaultCaption('📅 test', event), isTrue);
    expect(EventMessageCard.isDefaultCaption('On y va ?', event), isFalse);
  });
}
