import 'package:diaspo_niger/core/utils/mention_handle.dart';
import 'package:diaspo_niger/core/utils/rich_text_parser.dart';
import 'package:diaspo_niger/features/feed/presentation/widgets/hashtag_highlighting_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le pseudo de mention supprimait les lettres accentuées : « Ibrahim Yacouba
/// Maïdaoua » devenait `@IbrahimYacoubaMadaoua`. Ces tests fixent la nouvelle
/// règle ET le repli sur l'ancienne, dont dépendent toutes les publications
/// déjà en base.
void main() {
  group('mentionHandle', () {
    test('conserve les lettres accentuées', () {
      expect(
        mentionHandle('Ibrahim Yacouba Maïdaoua'),
        'IbrahimYacoubaMaïdaoua',
      );
      expect(mentionHandle('Aïcha'), 'Aïcha');
      expect(mentionHandle('Boubé'), 'Boubé');
    });

    test('conserve les alphabets non latins', () {
      expect(mentionHandle('李明'), '李明');
      expect(mentionHandle('Здравствуй'), 'Здравствуй');
    });

    test('supprime espaces et ponctuation, comme avant', () {
      expect(mentionHandle("Aïcha N'Diaye"), 'AïchaNDiaye');
      expect(mentionHandle('Diaspora Niger — Canada'), 'DiasporaNigerCanada');
      expect(mentionHandle('Jean-Pierre'), 'JeanPierre');
    });

    test('garde chiffres et tiret bas', () {
      expect(mentionHandle('user_42'), 'user_42');
    });
  });

  group('legacyMentionHandle', () {
    test("reproduit l'ancien comportement, accents supprimés", () {
      expect(
        legacyMentionHandle('Ibrahim Yacouba Maïdaoua'),
        'IbrahimYacoubaMadaoua',
      );
      expect(legacyMentionHandle('Aïcha'), 'Acha');
    });

    test('se réduit au vide pour un nom sans lettre ASCII', () {
      expect(legacyMentionHandle('李明'), '');
    });
  });

  group('mentionHandleMatches', () {
    test('égalité stricte', () {
      expect(mentionHandleMatches('Maïdaoua', 'Maïdaoua'), isTrue);
    });

    test('mention enregistrée avant le correctif, texte récent', () {
      // En base : `Madaoua`. Dans un texte écrit depuis : `Maïdaoua`.
      expect(mentionHandleMatches('Madaoua', 'Maïdaoua'), isTrue);
    });

    test('mention récente, texte ancien — le repli marche dans les deux sens', () {
      expect(mentionHandleMatches('Maïdaoua', 'Madaoua'), isTrue);
    });

    test('deux personnes différentes ne se confondent pas', () {
      expect(mentionHandleMatches('Aïcha', 'Boubé'), isFalse);
      expect(mentionHandleMatches('Madaoua', 'Madaouaou'), isFalse);
    });

    test('deux noms non latins ne se confondent pas par leur vide ASCII', () {
      // Sans la garde, `legacyMentionHandle` rendant '' des deux côtés, tous
      // les noms non latins se vaudraient.
      expect(mentionHandleMatches('李明', 'Здравствуй'), isFalse);
      expect(mentionHandleMatches('李明', '李明'), isTrue);
    });
  });

  group('motifs', () {
    test('mentionTypingPattern capture la saisie en cours, accents compris', () {
      expect(
        mentionTypingPattern.firstMatch('bonjour @Maïda')?.group(1),
        'Maïda',
      );
      // Un `@` seul (aucun caractère derrière) doit être reconnu : c'est ce qui
      // déclenche la liste de suggestions.
      expect(mentionTypingPattern.firstMatch('bonjour @')?.group(1), '');
      // Pas de mention en cours si une espace suit.
      expect(mentionTypingPattern.hasMatch('bonjour @Aïcha '), isFalse);
    });

    test('mentionTokenPattern trouve la mention au milieu du texte', () {
      expect(
        mentionTokenPattern.firstMatch('salut @Maïdaoua, ça va ?')?.group(0),
        '@Maïdaoua',
      );
    });
  });

  group('HashtagHighlightingController', () {
    // Son motif est un `static final` : une RegExp invalide ne se verrait qu'à
    // la première frappe dans le champ « nouvelle publication ». Ce test la
    // construit et la fait tourner.
    testWidgets('colore la mention accentuée entière', (tester) async {
      final controller = HashtagHighlightingController()
        ..highlightColor = Colors.orange
        ..text = 'salut @Maïdaoua et #tag';

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TextField(controller: controller))),
      );

      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(),
        withComposing: false,
      );
      final colored = <String>[];
      span.visitChildren((s) {
        if (s is TextSpan && s.style?.color == Colors.orange) {
          colored.add(s.text ?? '');
        }
        return true;
      });
      expect(colored, ['@Maïdaoua', '#tag']);
    });
  });

  group('RichTextParser', () {
    test('capture la mention accentuée en entier', () {
      // Le motif s'arrêtait au premier caractère non ASCII : la mention
      // n'était colorée que jusqu'au `ï`, et le tap ne résolvait aucun profil.
      final segments = RichTextParser.parse('salut @Maïdaoua ça va');
      final mention = segments.firstWhere(
        (s) => s.type == TextSegmentType.mention,
      );
      expect(mention.text, '@Maïdaoua');
      expect(mention.mentionUserId, 'Maïdaoua');
    });

    test('les autres formats restent reconnus (motif passé en mode unicode)', () {
      // `unicode: true` durcit la validation des échappements : ce test échoue
      // à la construction de la RegExp si un motif du lot devient invalide.
      final segments = RichTextParser.parse(
        'a **gras** et *ital* et ~~barre~~ et `code` et https://x.dev et #tag',
      );
      final types = segments.map((s) => s.type).toSet();
      expect(types, contains(TextSegmentType.bold));
      expect(types, contains(TextSegmentType.italic));
      expect(types, contains(TextSegmentType.strikethrough));
      expect(types, contains(TextSegmentType.code));
      expect(types, contains(TextSegmentType.link));
      expect(types, contains(TextSegmentType.hashtag));
    });
  });
}
