import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_input.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Non-régression de la mise en page du composer.
///
/// Ces deux points ont déjà été annulés par une session parallèle : la barre
/// doit rester « emoji · champ texte · + », et le bouton d'envoi doit porter
/// le badge cadenas E2EE dès qu'il y a du texte.

/// Monte le composer seul, localisé en FR.
Future<void> _pump(WidgetTester tester) async {
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
      home: Scaffold(
        body: MessageInput(
          conversationId: 'conv-test',
          onSendText: (_, __) {},
          onSendFile: (File file, bool isImage, {String? caption}) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Le cadenas du bouton d'envoi (distinct du verrou d'enregistrement vocal,
/// qui n'existe que pendant un enregistrement).
Finder _lockBadge() =>
    find.byWidgetPredicate((w) => w is AppIcon && w.asset == AppIcon.lock);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
  });

  testWidgets('la barre expose emoji, champ texte, puis le bouton « + »', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Trombone et caméra rapide sont fusionnés dans le « + » : le sheet
    // pièces jointes propose déjà Caméra, donc rien n'est perdu.
    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
  });

  testWidgets('le « + » vient après le champ texte, pas avant', (tester) async {
    await _pump(tester);

    final emojiX = tester.getCenter(find.byIcon(Icons.emoji_emotions_outlined)).dx;
    final fieldX = tester.getCenter(find.byType(TextField)).dx;
    final plusX = tester.getCenter(find.byIcon(Icons.add)).dx;

    expect(emojiX, lessThan(fieldX));
    expect(plusX, greaterThan(fieldX));
  });

  testWidgets('le badge cadenas E2EE apparaît seulement en mode envoi', (
    tester,
  ) async {
    await _pump(tester);

    // Champ vide : bouton micro, pas de cadenas.
    expect(_lockBadge(), findsNothing);

    await tester.enterText(find.byType(TextField), 'Salam');
    // Couvre le morphing (250 ms) et le debounce de sauvegarde du brouillon
    // (500 ms), sinon le timer reste pendant en fin de test.
    await tester.pump(const Duration(milliseconds: 600));

    expect(_lockBadge(), findsOneWidget);
  });
}
