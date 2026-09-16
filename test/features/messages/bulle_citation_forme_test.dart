import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_bubble.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// La bulle qui porte une citation : sa forme, pas son contenu.
///
/// Une réponse courte à un message court donnait un bloc **plus haut que
/// large** — la citation, le texte et rien d'autre, empilés dans une colonne
/// de la largeur du plus court des trois. La citation s'y lisait comme une
/// étiquette posée à côté du message plutôt que comme le message cité.
///
/// Deux garanties tiennent la forme, et ce fichier les fixe : un plancher de
/// largeur, et une citation étirée sur toute la largeur de la bulle.

const double _largeurEcran = 411;

final _quand = DateTime.now().subtract(const Duration(hours: 2));

MessageEntity _msg(
  String id,
  String contenu, {
  MessageType type = MessageType.text,
}) => MessageEntity(
  id: id,
  senderId: id == 'cite' ? 'sim' : 'salim',
  senderName: id == 'cite' ? 'Sim A' : 'Moi',
  content: contenu,
  type: type,
  createdAt: _quand,
  audioDuration: type == MessageType.voiceNote ? 12 : null,
);

/// Bulle envoyée : l'aplat `#009600` (`_kSentBubbleLight`).
Finder _bulleEnvoyee() => find.byWidgetPredicate((w) {
  if (w is! Container) return false;
  final d = w.decoration;
  return d is BoxDecoration && d.color == const Color(0xFF009600);
});

/// Bloc de citation : le seul `Container` dont la bordure n'a qu'un côté.
Finder _citation() => find.byWidgetPredicate((w) {
  if (w is! Container) return false;
  final d = w.decoration;
  if (d is! BoxDecoration) return false;
  final b = d.border;
  return b is Border && b.left.width == 3 && b.top.style == BorderStyle.none;
});

Future<void> _pump(
  WidgetTester tester, {
  required MessageEntity message,
  MessageEntity? citation,
  bool isMe = true,
}) async {
  tester.view.physicalSize = const Size(_largeurEcran * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        theme: ThemeData.light(),
        home: Scaffold(
          body: MessageBubble(
            message: message,
            isMe: isMe,
            replyToMessage: citation,
            currentUserId: 'salim',
            skipAnimation: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
  });

  testWidgets('une réponse courte ne se replie pas en colonne', (tester) async {
    await _pump(
      tester,
      message: _msg('moi', 'good'),
      citation: _msg('cite', 'Ok'),
    );

    final bulle = tester.getRect(_bulleEnvoyee().first);

    expect(
      bulle.width,
      greaterThan(bulle.height),
      reason: 'la bulle est redevenue plus haute que large',
    );
    // Le plancher : 58 % de l'écran, plafonné à 260 (`_largeurMinCitation`).
    expect(bulle.width, greaterThanOrEqualTo(_largeurEcran * 0.58 - 1));
  });

  testWidgets('la citation s\'étire sur toute la largeur de la bulle', (
    tester,
  ) async {
    await _pump(
      tester,
      message: _msg('moi', 'good'),
      citation: _msg('cite', 'Ok'),
    );

    final bulle = tester.getRect(_bulleEnvoyee().first);
    final citation = tester.getRect(_citation().first);

    // Marges de la citation : 6 px de chaque côté, rien de plus.
    expect(
      bulle.width - citation.width,
      lessThanOrEqualTo(13),
      reason: 'la citation flotte au lieu de tenir toute la largeur',
    );
  });

  testWidgets('une bulle sans citation garde sa largeur d\'origine', (
    tester,
  ) async {
    await _pump(tester, message: _msg('moi', 'Ok'));

    final bulle = tester.getRect(_bulleEnvoyee().first);

    // Le plancher ne vaut QUE pour une citation : sans elle, « Ok » reste une
    // pastille, jamais une barre de 238 px.
    expect(bulle.width, lessThan(_largeurEcran * 0.4));
  });

  testWidgets('une note vocale citée ne passe pas par IntrinsicWidth', (
    tester,
  ) async {
    // `AudioMessageBubble` contient un `LayoutBuilder` : lui demander une
    // dimension intrinsèque **lève**. L'étirement de la citation doit donc
    // rester réservé au texte — si quelqu'un l'étend à tous les types, ce
    // test tombe, et il tombe avec l'exception exacte.
    await _pump(
      tester,
      message: _msg('moi', '', type: MessageType.voiceNote),
      citation: _msg('cite', 'Ok'),
    );

    expect(tester.takeException(), isNull);
  });
}
