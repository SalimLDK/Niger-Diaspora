import 'package:diaspo_niger/features/messages/presentation/widgets/link_preview_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La carte d'aperçu d'un lien est écrite par l'expéditeur.
///
/// `linkPreviewData` voyage dans le message : un client modifié y met ce
/// qu'il veut. Une carte « Banque X » menait vers un autre site que le lien
/// lisible dans le texte, acceptait n'importe quel schéma, et s'ouvrait au
/// premier appui — sans la confirmation que les liens du texte demandent.
void main() {
  group('urlFiable', () {
    test('la carte d\'un lien du texte est montrée', () {
      expect(
        LinkPreviewBubble.urlFiable(
          {'url': 'https://exemple.ne/article'},
          'Regarde https://exemple.ne/article',
        ),
        'https://exemple.ne/article',
      );
    });

    test('un lien sans schéma dans le texte : la forme normalisée de l\'envoi',
        () {
      expect(
        LinkPreviewBubble.urlFiable(
          {'url': 'https://www.exemple.ne'},
          'va sur www.exemple.ne',
        ),
        'https://www.exemple.ne',
      );
    });

    test('une carte qui mène ailleurs que le texte n\'est pas montrée', () {
      expect(
        LinkPreviewBubble.urlFiable(
          {'url': 'https://hameconnage.example', 'title': 'Banque X'},
          'Ta banque : https://banque-x.ne',
        ),
        isNull,
      );
      // Sans aucun lien dans le texte non plus.
      expect(
        LinkPreviewBubble.urlFiable(
          {'url': 'https://hameconnage.example'},
          'bonjour',
        ),
        isNull,
      );
    });

    test('ni intent:, ni file:, ni javascript:', () {
      for (final url in [
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///data/data/x',
        'javascript:alert(1)',
        'tel:+22790000000',
      ]) {
        expect(LinkPreviewBubble.urlFiable({'url': url}, url), isNull,
            reason: url);
      }
    });

    test('carte absente ou mal formée', () {
      expect(LinkPreviewBubble.urlFiable(null, 'https://a.ne'), isNull);
      expect(LinkPreviewBubble.urlFiable({'url': 42}, 'https://a.ne'), isNull);
      expect(LinkPreviewBubble.urlFiable({'url': ''}, ''), isNull);
    });

    test('l\'hôte affiché vient de l\'URL, sans www.', () {
      expect(LinkPreviewBubble.hote('https://www.exemple.ne/a?b=c'),
          'exemple.ne');
      expect(LinkPreviewBubble.hote('https://hameconnage.example'),
          'hameconnage.example');
    });
  });

  group('la carte à l\'écran', () {
    Future<List<String>> monterEtToucher(
      WidgetTester tester,
      Map<String, dynamic> data, {
      bool reponse = false,
    }) async {
      final demandes = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LinkPreviewBubble.fromMap(
            data,
            isMe: false,
            confirmerOuverture: (url) async {
              demandes.add(url);
              return reponse;
            },
          ),
        ),
      ));
      await tester.tap(find.byType(LinkPreviewBubble));
      await tester.pump();
      return demandes;
    }

    testWidgets('un lien externe demande confirmation avant de s\'ouvrir',
        (tester) async {
      final demandes = await monterEtToucher(tester, {
        'url': 'https://exemple.ne/article',
        'title': 'Titre',
      });
      expect(demandes, ['https://exemple.ne/article']);
    });

    testWidgets('l\'hôte réel remplace le siteName fourni', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LinkPreviewBubble.fromMap(const {
            'url': 'https://hameconnage.example/connexion',
            'title': 'Banque X',
            'siteName': 'banque-x.ne',
          }, isMe: false),
        ),
      ));
      expect(find.text('hameconnage.example'), findsOneWidget);
      expect(find.text('banque-x.ne'), findsNothing);
    });

    testWidgets('un schéma non web ne va même pas jusqu\'à la confirmation',
        (tester) async {
      final demandes = await monterEtToucher(tester, {
        'url': 'intent://scan/#Intent;end',
        'title': 'Titre',
      });
      expect(demandes, isEmpty);
    });
  });
}
