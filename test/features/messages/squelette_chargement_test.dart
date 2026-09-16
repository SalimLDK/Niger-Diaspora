import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/messages/presentation/widgets/messages_skeleton.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Les deux attentes de la messagerie montrent maintenant la forme de ce qui
/// arrive, au lieu d'un tourniquet centré (liste des discussions) et d'un
/// écran entièrement vide (fil d'une discussion).
///
/// Ce que ce fichier verrouille :
/// - la géométrie, parce que c'est toute la raison d'être d'un squelette : si
///   les blocs ne tombent pas là où le contenu tombera, l'écran saute quand
///   même à l'arrivée des données, et le squelette n'aura servi à rien ;
/// - le fait que les deux branches de chargement soient bien câblées, les
///   deux écrans étant trop dépendants de providers pour être montés ici.

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size taille = const Size(360, 640),
  Brightness luminosite = Brightness.light,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      theme: ThemeData(brightness: luminosite),
      home: Scaffold(body: child),
    ),
  );
  // Surtout pas `pumpAndSettle` : le balayage du shimmer est un
  // `repeat()` sans fin, la file d'animations ne se vide jamais.
  await tester.pump(const Duration(milliseconds: 400));
}

/// Les blocs du squelette sont des [Container] décorés ; leurs rectangles
/// suffisent à mesurer la géométrie sans exposer de clés de test.
List<Rect> _blocs(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => tester.getRect(find.byWidget(c)))
    .toList();

void main() {
  group('squelette de la liste des discussions', () {
    testWidgets('autant de lignes que demandé, avatar 50 au rayon du vrai', (
      tester,
    ) async {
      await _pump(tester, const ConversationListSkeleton(itemCount: 5));

      final avatars = _blocs(
        tester,
      ).where((r) => r.width == 50 && r.height == 50).length;
      expect(avatars, 5, reason: 'un avatar par ligne annoncée');
      expect(tester.takeException(), isNull);
    });

    testWidgets('rien ne déborde sur un écran étroit, en clair et en sombre', (
      tester,
    ) async {
      for (final luminosite in Brightness.values) {
        await _pump(
          tester,
          const ConversationListSkeleton(),
          taille: const Size(320, 568),
          luminosite: luminosite,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'débordement en ${luminosite.name}',
        );

        for (final bloc in _blocs(tester)) {
          expect(
            bloc.right,
            lessThanOrEqualTo(320.0),
            reason: 'un bloc sort par la droite en ${luminosite.name}',
          );
        }
      }
    });

    testWidgets('le squelette ne défile pas', (tester) async {
      await _pump(tester, const ConversationListSkeleton());

      final liste = tester.widget<ListView>(find.byType(ListView));
      expect(liste.physics, isA<NeverScrollableScrollPhysics>());
    });
  });

  group('squelette du fil d\'une discussion', () {
    testWidgets('les bulles sont collées en bas, comme la vraie liste', (
      tester,
    ) async {
      await _pump(tester, const ConversationThreadSkeleton());

      final liste = tester.widget<ListView>(find.byType(ListView));
      expect(
        liste.reverse,
        isTrue,
        reason: 'sinon tout remonte d\'un coup à l\'arrivée des messages',
      );

      final bas = _blocs(tester).map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
      expect(
        bas,
        greaterThan(640 - 40),
        reason: 'la bulle la plus récente doit toucher le bas (padding 16)',
      );
    });

    testWidgets('chaque bulle est calée sur une marge de bulle réelle', (
      tester,
    ) async {
      await _pump(tester, const ConversationThreadSkeleton());

      final bulles = _blocs(tester);
      expect(bulles, isNotEmpty);

      var recues = 0;
      var envoyees = 0;
      for (final bulle in bulles) {
        // `MessageBubble` : 16 du côté de l'expéditeur, 64 en face.
        if (bulle.left == 16) {
          recues++;
          expect(bulle.right, lessThanOrEqualTo(360.0 - 64));
        } else {
          envoyees++;
          expect(bulle.right, 360.0 - 16);
          expect(bulle.left, greaterThanOrEqualTo(64.0));
        }
      }
      expect(recues, greaterThan(0));
      expect(envoyees, greaterThan(0));
    });

    testWidgets("en groupe, la colonne d'avatar est réservée à gauche", (
      tester,
    ) async {
      await _pump(tester, const ConversationThreadSkeleton(isGroup: true));

      // `MessageBubble` descend le retrait gauche à 8 et pose un avatar de
      // rayon 14 suivi de 8 de gouttière : la bulle reçue commence à 44.
      // Sans cette colonne, les bulles sauteraient de 28 px à l'arrivée des
      // vrais messages.
      final avatars = _blocs(
        tester,
      ).where((r) => r.width == 28 && r.height == 28).toList();
      expect(avatars, isNotEmpty, reason: "aucune colonne d'avatar");
      for (final avatar in avatars) {
        expect(avatar.left, 8);
      }

      final recues = _blocs(tester).where((r) => r.left == 44);
      expect(recues.length, avatars.length);
    });
  });

  group('les deux branches de chargement sont câblées', () {
    String lire(String chemin) {
      final fichier = File(chemin);
      expect(fichier.existsSync(), isTrue, reason: '$chemin introuvable');
      return fichier.readAsStringSync();
    }

    test('la liste des discussions n\'a plus de tourniquet centré', () {
      final source = lire(
        'lib/features/messages/presentation/screens/messages_screen.dart',
      );
      expect(source, contains('loading: () => const ConversationListSkeleton()'));
    });

    test('le fil ne rend plus un écran vide pendant sa première page', () {
      final source = lire(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      final garde = source.indexOf('if (paginationState.isLoadingInitial) {');
      expect(garde, isNot(-1), reason: 'la garde de premier chargement a disparu');

      // Le `return` lui-même, et pas une simple occurrence du nom : le
      // commentaire juste au-dessus cite `SizedBox.shrink()`, donc chercher
      // son absence dans la branche se tromperait de cible.
      final branche = source.substring(garde, garde + 500);
      expect(
        branche,
        contains('return ConversationThreadSkeleton(isGroup: _isGroup);'),
        reason: 'le fil redeviendrait vide pendant le chargement',
      );
    });
  });
}
