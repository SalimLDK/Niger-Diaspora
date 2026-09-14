import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/features/messages/presentation/widgets/reaction_picker.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Double tap sur un message : il posait d'office un cœur. Demande du
/// 2026-09-12 — les cinq réactions de la feuille d'actions, plus un « + » vers
/// le sélecteur complet.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<String?>> pump(WidgetTester tester, {String? selected}) async {
    final resultats = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  resultats.add(
                    await showReactionBar(
                      context,
                      anchor: const Rect.fromLTWH(40, 400, 200, 60),
                      selected: selected,
                    ),
                  );
                },
                child: const Text('bulle'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('bulle'));
    await tester.pumpAndSettle();
    return resultats;
  }

  testWidgets('les cinq réactions de la feuille, puis le +', (tester) async {
    await pump(tester);

    expect(kQuickReactions, hasLength(5));
    for (final emoji in kQuickReactions) {
      expect(find.text(emoji), findsOneWidget, reason: emoji);
    }
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('choisir un emoji le renvoie et ferme la barre', (tester) async {
    final resultats = await pump(tester);

    await tester.tap(find.text('\u{1F602}'));
    await tester.pumpAndSettle();

    expect(resultats, ['\u{1F602}']);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('toucher à côté ferme sans réagir', (tester) async {
    final resultats = await pump(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(resultats, [null]);
  });

  testWidgets('le + ouvre le sélecteur complet', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(emoji_picker.EmojiPicker), findsOneWidget);
  });

  testWidgets('la barre reste dans l\'écran même collée au bord', (
    tester,
  ) async {
    await pump(tester);

    final barre = tester.getRect(find.byType(QuickReactionRow));
    final ecran = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(barre.left, greaterThanOrEqualTo(0));
    expect(barre.right, lessThanOrEqualTo(ecran.width));
    // Au-dessus de l'ancre (y = 400).
    expect(barre.bottom, lessThanOrEqualTo(400));
  });
}
