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

/// « Modifier un message » : la règle, et le composeur qui la sert.
///
/// Ce que ce banc tient, point par point :
///
/// - la fenêtre est celle de [MessageEntity.fenetreModification] et **rien ne
///   l'impose côté serveur** (`messages_update` n'a aucune contrainte de
///   temps) : ce fichier est le seul endroit qui la vérifie ;
/// - chaque refus porte son **motif**, pour que l'écran puisse le dire au lieu
///   d'annoncer « délai expiré » sur une coupure réseau ;
/// - la saisie se fait dans la barre du bas, et **ne mange pas le brouillon
///   en cours** — c'est le piège de cette refonte : le champ est partagé, et
///   son listener sauvegarde en brouillon tout ce qu'on y écrit.

const _moi = 'moi';
const _autre = 'autre';

MessageEntity _message({
  String senderId = _moi,
  MessageType type = MessageType.text,
  MessageStatus status = MessageStatus.sent,
  bool deletedForEveryone = false,
  Duration age = Duration.zero,
  String content = 'bonjour',
}) {
  return MessageEntity(
    id: 'm1',
    senderId: senderId,
    senderName: 'Salim',
    content: content,
    type: type,
    status: status,
    deletedForEveryone: deletedForEveryone,
    createdAt: DateTime.now().subtract(age),
  );
}

/// Monte le composer seul, localisé en FR, éventuellement en modification.
Future<void> _pump(
  WidgetTester tester, {
  MessageEntity? enModification,
  VoidCallback? onCancelEdit,
  void Function(String)? onSubmitEdit,
  String conversationId = 'conv-modif',
}) async {
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
          conversationId: conversationId,
          onSendText: (_, __) {},
          onSendFile: (File file, MessageType type, {String? caption}) {},
          editingMessage: enModification,
          onCancelEdit: onCancelEdit,
          onSubmitEdit: onSubmitEdit,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Rejoue le même composeur avec un autre `editingMessage`, comme le fait
/// l'écran : c'est `didUpdateWidget` qui entre et sort de la modification, pas
/// un remontage.
Future<void> _rejoue(
  WidgetTester tester, {
  required MessageEntity? enModification,
  String conversationId = 'conv-modif',
}) async {
  await _pump(
    tester,
    enModification: enModification,
    conversationId: conversationId,
  );
  await tester.pump();
}

TextField _champ(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
  });

  group('la règle : qui peut modifier, et jusqu\'à quand', () {
    test('son propre message texte, récent et envoyé, se modifie', () {
      expect(_message().motifModificationImpossible(_moi), isNull);
    });

    test('le message d\'un autre, jamais', () {
      expect(
        _message(senderId: _autre).motifModificationImpossible(_moi),
        MotifModificationImpossible.pasLauteur,
      );
    });

    test('une photo, non : seul le texte se modifie', () {
      expect(
        _message(type: MessageType.image).motifModificationImpossible(_moi),
        MotifModificationImpossible.pasDuTexte,
      );
    });

    test('un message supprimé pour tous, non', () {
      expect(
        _message(deletedForEveryone: true).motifModificationImpossible(_moi),
        MotifModificationImpossible.supprime,
      );
    });

    // Un message encore en vol porte un identifiant `temp_…` : sa ligne
    // n'existe pas côté serveur. Le laisser passer produisait un « Message
    // modifié » sur un geste qui ne touchait rien.
    test('un message encore en vol, non', () {
      expect(
        _message(
          status: MessageStatus.sending,
        ).motifModificationImpossible(_moi),
        MotifModificationImpossible.pasEncoreEnvoye,
      );
    });

    test('un message en échec d\'envoi, non', () {
      expect(
        _message(
          status: MessageStatus.failed,
        ).motifModificationImpossible(_moi),
        MotifModificationImpossible.pasEncoreEnvoye,
      );
    });

    test('passé la fenêtre, le motif est le délai — et lui seul', () {
      expect(
        _message(
          age: MessageEntity.fenetreModification + const Duration(minutes: 1),
        ).motifModificationImpossible(_moi),
        MotifModificationImpossible.delaiExpire,
      );
    });

    // Le garde-fou du changement de fenêtre : à 25 min la modification de la
    // veille — cas le plus courant — était refusée.
    test('un message d\'hier se modifie encore', () {
      expect(
        _message(age: const Duration(hours: 24)).motifModificationImpossible(
          _moi,
        ),
        isNull,
      );
      expect(MessageEntity.fenetreModification, const Duration(hours: 48));
    });

    test('`canEdit` dit la même chose que le motif', () {
      expect(_message().canEdit(_moi), isTrue);
      expect(_message(senderId: _autre).canEdit(_moi), isFalse);
      expect(
        _message(age: const Duration(hours: 72)).canEdit(_moi),
        isFalse,
      );
    });
  });

  group('le composeur en modification', () {
    testWidgets('le bandeau nomme le geste et montre le texte d\'origine', (
      tester,
    ) async {
      await _pump(tester, enModification: _message(content: 'texte d\'avant'));

      expect(find.text('Modifier le message'), findsOneWidget);
      expect(find.text('texte d\'avant'), findsWidgets);
    });

    testWidgets('le champ est pré-rempli avec le message', (tester) async {
      await _pump(tester);
      expect(_champ(tester).controller!.text, isEmpty);

      await _rejoue(tester, enModification: _message(content: 'à corriger'));
      expect(_champ(tester).controller!.text, 'à corriger');
    });

    testWidgets('la croix du bandeau ressort de la modification', (
      tester,
    ) async {
      var annule = false;
      await _pump(
        tester,
        enModification: _message(),
        onCancelEdit: () => annule = true,
      );

      await tester.tap(find.byTooltip('Annuler'));
      await tester.pump();

      expect(annule, isTrue);
    });

    testWidgets('le bouton applique le texte saisi, sans rien envoyer', (
      tester,
    ) async {
      String? applique;
      var envoye = 0;

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
              conversationId: 'conv-modif',
              onSendText: (_, __) => envoye++,
              onSendFile: (File file, MessageType type, {String? caption}) {},
              editingMessage: _message(content: 'avant'),
              onSubmitEdit: (texte) => applique = texte,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'après');
      await tester.pump();
      // Le bouton d'action porte la coche en modification : c'est par elle
      // qu'on le retrouve, et non par une position dans l'arbre.
      await tester.tap(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) => w is AppIcon && w.asset == AppIcon.check,
              ),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pump();

      expect(applique, 'après');
      expect(envoye, 0, reason: 'modifier n\'envoie pas un nouveau message');
    });

    // Pas de pièce jointe à attacher à un message déjà parti : le « + » n'a
    // nulle part où poser son résultat.
    testWidgets('le « + » disparaît pendant la modification', (tester) async {
      await _pump(tester);
      final avant = find.byType(IconButton).evaluate().length;

      await _rejoue(tester, enModification: _message());
      final pendant = find.byType(IconButton).evaluate().length;

      expect(pendant, lessThanOrEqualTo(avant));
      expect(find.text('Modifier le message'), findsOneWidget);
    });
  });

  group('le brouillon survit à la modification', () {
    // LE piège de cette refonte. Le champ sert aux deux, et son listener
    // sauvegarde en brouillon tout ce qu'on y écrit : sans mise de côté,
    // entrer en modification écrasait le brouillon, et en sortir laissait à sa
    // place le texte du message modifié.
    testWidgets('il revient intact quand on ressort', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'brouillon en cours');
      await tester.pump();

      await _rejoue(tester, enModification: _message(content: 'le message'));
      expect(_champ(tester).controller!.text, 'le message');

      await _rejoue(tester, enModification: null);
      expect(_champ(tester).controller!.text, 'brouillon en cours');
    });

    testWidgets('le texte modifié ne part pas dans le brouillon du disque', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'brouillon en cours');
      // Au-delà du debounce de sauvegarde (500 ms).
      await tester.pump(const Duration(seconds: 1));
      expect(
        PreferencesService.instance.getMessageDraft('conv-modif'),
        'brouillon en cours',
      );

      await _rejoue(tester, enModification: _message(content: 'le message'));
      await tester.enterText(find.byType(TextField), 'le message corrigé');
      await tester.pump(const Duration(seconds: 1));

      expect(
        PreferencesService.instance.getMessageDraft('conv-modif'),
        'brouillon en cours',
        reason:
            'le texte d\'une modification n\'est pas un brouillon : il '
            'réapparaîtrait à la réouverture de la conversation',
      );
    });

    testWidgets('quitter l\'écran en pleine modification garde le brouillon', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'pas encore envoyé');
      // Volontairement AVANT le debounce : le brouillon n'est pas encore sur
      // le disque quand la modification s'ouvre et annule le minuteur.
      await tester.pump(const Duration(milliseconds: 100));

      await _rejoue(tester, enModification: _message(content: 'le message'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(
        PreferencesService.instance.getMessageDraft('conv-modif'),
        'pas encore envoyé',
      );
    });
  });
}
