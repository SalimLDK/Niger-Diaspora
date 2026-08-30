import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_input.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Non-régression de la mise en page du composer flottant.
///
/// Layout actuel (fiche 26b) : quatre commandes en ligne — « + » hors de la
/// pilule à gauche · champ texte · emoji en pastille propre · bouton
/// micro/envoi. Rien ne vit plus **dans** la pilule à part le texte. Le bouton
/// d'envoi porte le badge cadenas E2EE dès qu'il y a du texte.

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
          onSendFile: (File file, MessageType type, {String? caption}) {},
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

  testWidgets('la barre expose le « + », le champ texte et l\'emoji', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);

    // Trombone et caméra rapide sont fusionnés dans le « + » : le sheet
    // pièces jointes propose déjà Caméra, donc rien n'est perdu.
    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
  });

  testWidgets('le « + », le champ et l\'emoji sont trois blocs distincts', (
    tester,
  ) async {
    await _pump(tester);

    final plus = tester.getRect(find.byIcon(Icons.add_rounded));
    final champ = tester.getRect(find.byType(TextField));
    final emoji = tester.getRect(find.byIcon(Icons.emoji_emotions_outlined));

    // Ordre de gauche à droite : « + », champ, emoji.
    expect(plus.center.dx, lessThan(champ.center.dx));
    expect(emoji.center.dx, greaterThan(champ.center.dx));

    // Fiche 26b : l'emoji n'empiète plus sur le champ, il est entièrement à sa
    // droite. C'est ce qui distingue « pastille propre » de « suffixIcon ».
    expect(
      emoji.left,
      greaterThanOrEqualTo(champ.right),
      reason: 'l\'emoji est retourné à l\'intérieur de la pilule',
    );
    expect(plus.right, lessThanOrEqualTo(champ.left));
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

  testWidgets('un brouillon restauré affiche le bouton d\'envoi sans frappe', (
    tester,
  ) async {
    // Brouillon laissé lors d'une session précédente sur cette conversation.
    await PreferencesService.instance.saveMessageDraft(
      'conv-test',
      'Message pas encore envoyé',
    );

    await _pump(tester);

    // Le texte est bien restauré...
    expect(find.text('Message pas encore envoyé'), findsOneWidget);
    // ...et le composer est en mode envoi d'emblée, sans toucher au champ :
    // sinon l'utilisateur croit ne pas pouvoir envoyer son brouillon.
    expect(_lockBadge(), findsOneWidget);
  });

  testWidgets('la barre grandit avec le texte puis se stabilise à 6 lignes', (
    tester,
  ) async {
    await _pump(tester);

    final uneLigne = tester.getSize(find.byType(TextField)).height;

    await tester.enterText(find.byType(TextField), 'a\nb\nc');
    await tester.pump(const Duration(milliseconds: 600));
    final troisLignes = tester.getSize(find.byType(TextField)).height;

    // Le champ suit le texte au lieu de le faire défiler horizontalement.
    expect(troisLignes, greaterThan(uneLigne));

    await tester.enterText(
      find.byType(TextField),
      List.generate(12, (i) => 'ligne $i').join('\n'),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final douzeLignes = tester.getSize(find.byType(TextField)).height;

    // Passé 6 lignes, c'est le champ qui défile : la barre ne mange plus
    // l'écran.
    expect(douzeLignes, lessThan(troisLignes * 2.5));
  });

  testWidgets('le compteur apparaît au seuil de 200 caractères', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'a' * 199);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('/ 2000'), findsNothing);

    await tester.enterText(find.byType(TextField), 'a' * 201);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('201 / 2000'), findsOneWidget);
  });

  testWidgets('quitter avant la fin du debounce ne perd pas le brouillon', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'Brouillon in extremis');
    // On démonte AVANT les 500 ms de debounce : sans le flush du dispose, la
    // sauvegarde programmée serait simplement annulée.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      PreferencesService.instance.getMessageDraft('conv-test'),
      'Brouillon in extremis',
    );
  });

  testWidgets('ouvrir le panneau clavier levé ne fait pas déborder la colonne', (
    tester,
  ) async {
    // Reproduit l'appareil : A51 (393×873 dp), police à 1.1, conversation
    // chargée (bandeau épinglé + chips + bandeau de clés ≈ 240 dp de chrome).
    // Le « + » baisse le clavier et insère le panneau dans la foulée : pendant
    // les ~250 ms de repli, l'inset du clavier est encore là. Sans le créneau
    // clavier, la colonne débordait de 85 px.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2.75);
    addTearDown(tester.view.reset);

    Widget app() => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(
        appBar: AppBar(title: const Text('Salim L.')),
        body: Column(
          children: [
            const SizedBox(height: 240), // chrome fixe de la conversation
            const Expanded(child: SizedBox.expand()),
            MessageInput(
              conversationId: 'conv-overflow',
              onSendText: (_, __) {},
              onSendFile: (File file, MessageType type, {String? caption}) {},
              onSendAudio: (_, __, ___) {},
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.enterText(
      find.byType(TextField),
      List.generate(6, (i) => 'ligne $i').join('\n'),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final sansPanneau = tester.getSize(find.byType(MessageInput)).height;

    // Clavier encore levé : le panneau ne doit rien ajouter à la colonne.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MessageInput)).height, sansPanneau);

    // Clavier parti : le panneau prend sa place, toujours sans déborder.
    // ⚠ On ne reconstruit PAS l'arbre ici : seul le changement de métriques
    // doit suffire à révéler le panneau. Sans l'observateur `didChangeMetrics`,
    // la lecture de `View.of(context).viewInsets` ne crée aucune dépendance et
    // le panneau reste invisible — c'est le défaut vu sur l'appareil.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(MessageInput)).height,
      greaterThan(sansPanneau),
    );
    expect(find.text('Caméra'), findsOneWidget);
  });
}
