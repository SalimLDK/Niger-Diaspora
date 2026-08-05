import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_bubble.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Fiches 4a/6b : l'heure et l'accusé de réception vivent **sous** la bulle,
/// jamais dedans, et c'est la même ligne pour tous les types de message.
///
/// Avant cette règle, chaque famille de bulle réaffichait son heure de son
/// côté (incrustée sur l'image et la vidéo, en fin de ligne dans le texte, et
/// pas du tout sur les notes vocales). Si quelqu'un remet un horodatage dans
/// une bulle, ce fichier doit casser.

/// Deux heures dans le passé : `_formatTime` renvoie « À l'instant » sous la
/// minute, ce qui rendrait l'assertion sur l'heure illisible.
final _sentAt = DateTime.now().subtract(const Duration(hours: 2));
final _hhmm = DateFormat.Hm().format(_sentAt);

MessageEntity _message({
  required MessageType type,
  String content = 'Salut ! Tu as reçu les papiers du consulat ?',
  List<String> reactions = const [],
  List<String> readBy = const [],
  List<String> deliveredTo = const [],
}) {
  return MessageEntity(
    id: 'msg-1',
    senderId: 'aicha',
    senderName: 'Aïcha Moussa',
    content: content,
    type: type,
    createdAt: _sentAt,
    reactions: reactions,
    readBy: readBy,
    deliveredTo: deliveredTo,
    audioDuration: type == MessageType.voiceNote ? 34 : null,
  );
}

Future<void> _pump(
  WidgetTester tester,
  MessageEntity message, {
  bool isMe = false,
  String? groupId,
}) async {
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
            groupId: groupId,
            currentUserId: 'salim',
            skipAnimation: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// La bulle reçue en thème clair : aplat blanc opaque (`_kRecvBubbleLight`).
Finder _bubble() => find.byWidgetPredicate((w) {
  if (w is! Container) return false;
  final d = w.decoration;
  return d is BoxDecoration && d.color == const Color(0xFFFFFFFF);
});

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
  });

  testWidgets('l\'heure d\'un message texte est hors de la bulle', (
    tester,
  ) async {
    await _pump(tester, _message(type: MessageType.text));

    expect(find.text(_hhmm), findsOneWidget);
    expect(_bubble(), findsWidgets, reason: 'la bulle doit exister');

    // La règle : l'heure n'est plus un descendant de la bulle.
    expect(
      find.descendant(of: _bubble().first, matching: find.text(_hhmm)),
      findsNothing,
      reason: 'l\'horodatage est reparti à l\'intérieur de la bulle',
    );
  });

  testWidgets('l\'heure est posée sous le texte, plus à sa droite', (
    tester,
  ) async {
    const contenu = 'Salut ! Tu as reçu les papiers du consulat ?';
    await _pump(tester, _message(type: MessageType.text, content: contenu));

    final texte = tester.getRect(find.text(contenu));
    final heure = tester.getRect(find.text(_hhmm));

    expect(
      heure.top,
      greaterThanOrEqualTo(texte.bottom),
      reason: 'l\'heure doit être sous le texte, pas sur la même ligne',
    );
  });

  testWidgets('la réaction partage la ligne de l\'heure', (tester) async {
    await _pump(
      tester,
      _message(type: MessageType.text, reactions: const ['👍']),
    );

    final heure = tester.getRect(find.text(_hhmm));
    final reaction = tester.getRect(find.text('👍'));

    // Fiche 6b : « 09:12  👍 1 » — même ligne, réaction à droite de l'heure.
    expect(reaction.left, greaterThan(heure.right - 1));
    expect((reaction.center.dy - heure.center.dy).abs(), lessThan(12));
  });

  testWidgets('une note vocale porte enfin son heure', (tester) async {
    // Elle n'en affichait aucune : AudioMessageBubble ne rendait pas de
    // timestamp et personne ne le faisait à sa place.
    await _pump(tester, _message(type: MessageType.voiceNote, content: ''));

    expect(find.text(_hhmm), findsOneWidget);
  });

  // ── L'accusé de réception se lit (fiche 26b : « 09:24 · Envoyé ») ──────────
  //
  // Il y avait trois coches à distinguer — simple, double, double bleue —
  // dans un cercle de 18 px. Si quelqu'un les remet, ces trois cas cassent.

  testWidgets('« Envoyé » : ni remis, ni lu', (tester) async {
    await _pump(tester, _message(type: MessageType.text), isMe: true);

    expect(find.text(' · Envoyé'), findsOneWidget);
    expect(find.text(' · Reçu'), findsNothing);
    expect(find.text(' · Lu'), findsNothing);
  });

  testWidgets('« Reçu » dès qu\'un destinataire l\'a reçu', (tester) async {
    await _pump(
      tester,
      _message(type: MessageType.text, deliveredTo: const ['salim']),
      isMe: true,
    );

    expect(find.text(' · Reçu'), findsOneWidget);
    expect(find.text(' · Envoyé'), findsNothing);
  });

  testWidgets('« Lu » en tête-à-tête, « Vu par N » en groupe', (tester) async {
    await _pump(
      tester,
      _message(
        type: MessageType.text,
        readBy: const ['salim'],
        deliveredTo: const ['salim'],
      ),
      isMe: true,
    );
    expect(find.text(' · Lu'), findsOneWidget);

    await _pump(
      tester,
      _message(
        type: MessageType.text,
        readBy: const ['salim', 'fatou'],
        deliveredTo: const ['salim', 'fatou'],
      ),
      isMe: true,
      groupId: 'groupe-1',
    );
    expect(find.text(' · Vu par 2'), findsOneWidget);
    expect(find.text(' · Lu'), findsNothing);
  });

  testWidgets('aucun accusé sur un message reçu', (tester) async {
    await _pump(tester, _message(type: MessageType.text));

    expect(find.textContaining('Envoyé'), findsNothing);
    expect(find.textContaining('Lu'), findsNothing);
  });
}
