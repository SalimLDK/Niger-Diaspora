import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_bubble.dart';
import 'package:diaspo_niger/features/polls/domain/entities/poll_entity.dart';
import 'package:diaspo_niger/features/polls/presentation/providers/poll_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// En mode sélection, la bulle entière doit répondre « coche / décoche » —
/// et rien d'autre.
///
/// Le mode enveloppe le message dans un `GestureDetector`, mais le contenu
/// gardait tous ses propres gestes en dessous. Or pour un tap c'est le
/// gestionnaire le PLUS PROFOND qui gagne : toucher un sondage votait au lieu
/// de cocher. La même cause valait pour l'image (visionneuse), l'aperçu de
/// lien (navigateur), l'envoi échoué (relance), le double-appui (réaction) et
/// le glissement (réponse).
///
/// D'où l'`AbsorbPointer` : le contenu ne reçoit plus de pointeur du tout
/// tant que le mode est ouvert, le geste remonte au parent. Le sondage sert
/// de cas type parce que ses options sont de vrais `InkWell` posés au milieu
/// de la bulle — c'est le cas signalé sur appareil.
///
/// ⚠️ Les gestes de ces bancs visent une cible qui, une fois corrigée, ne
/// peut PLUS recevoir de pointeur : `warnIfMissed: false` est donc la
/// condition normale, pas un contournement. Le geste part quand même aux
/// coordonnées trouvées, et c'est le parent qui doit l'attraper.
final _sondage = PollEntity(
  id: 'poll-42',
  contextType: PollContextType.conversation,
  contextId: 'conv-1',
  question: 'Qui vient samedi ?',
  options: const [
    PollOptionEntity(id: 'opt-1', label: 'Je viens'),
    PollOptionEntity(id: 'opt-2', label: 'Je ne peux pas'),
  ],
  createdAt: DateTime(2026, 9, 14),
);

MessageEntity _message({
  MessageType type = MessageType.text,
  String content = 'Qui vient samedi ?',
  String? pollId,
  MessageStatus status = MessageStatus.sent,
}) {
  return MessageEntity(
    id: 'msg-1',
    senderId: 'aicha',
    senderName: 'Aïcha Moussa',
    content: content,
    type: type,
    pollId: pollId,
    status: status,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  );
}

Future<void> _pump(
  WidgetTester tester,
  MessageEntity message, {
  required void Function(MessageEntity) onSelect,
  bool isSelectionMode = true,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pollStreamProvider.overrideWith(
          (ref, pollId) => Stream<PollEntity?>.value(_sondage),
        ),
      ],
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
            isMe: false,
            currentUserId: 'salim',
            conversationId: 'conv-1',
            isSelectionMode: isSelectionMode,
            isSelected: false,
            onSelect: onSelect,
            onReply: (_) {},
            onRetry: onRetry,
            skipAnimation: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
  });

  testWidgets('toucher une option de sondage coche le message, ne vote pas', (
    tester,
  ) async {
    final coches = <String>[];
    await _pump(
      tester,
      _message(type: MessageType.poll, pollId: 'poll-42'),
      onSelect: (m) => coches.add(m.id),
    );

    // L'option est bien rendue : sans elle, le banc passerait pour de
    // mauvaises raisons — rien à toucher, donc rien qui vote.
    expect(find.text('Je viens'), findsOneWidget);

    await tester.tap(find.text('Je viens'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      coches,
      ['msg-1'],
      reason: "le tap descendait jusqu'à l'InkWell de vote",
    );
  });

  testWidgets('toucher un envoi échoué coche au lieu de relancer', (
    tester,
  ) async {
    // Même famille, autre gestionnaire profond : la bulle d'un message en
    // échec porte son propre `onTap` de relance.
    var relances = 0;
    final coches = <String>[];
    await _pump(
      tester,
      _message(status: MessageStatus.failed),
      onSelect: (m) => coches.add(m.id),
      onRetry: () => relances++,
    );

    await tester.tap(find.text('Qui vient samedi ?'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(coches, ['msg-1']);
    expect(relances, 0, reason: "la relance n'a rien à faire en sélection");
  });

  testWidgets("l'appui long coche aussi, il ne rouvre pas le menu", (
    tester,
  ) async {
    final coches = <String>[];
    await _pump(tester, _message(), onSelect: (m) => coches.add(m.id));

    await tester.longPress(
      find.text('Qui vient samedi ?'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(coches, ['msg-1']);
    expect(
      find.text('Répondre'),
      findsNothing,
      reason: "une feuille d'actions par-dessus la barre de sélection",
    );
  });

  testWidgets('hors sélection, le sondage reste votable', (tester) async {
    // La garde symétrique : l'absorption ne doit pas déborder du mode. Le
    // décompte passe par `widgetList` et non `.first` — l'`Overlay` de
    // MaterialApp pose déjà un `AbsorbPointer` inactif au-dessus de tout,
    // qui ferait passer une assertion sur le premier trouvé.
    await _pump(
      tester,
      _message(type: MessageType.poll, pollId: 'poll-42'),
      onSelect: (_) {},
      isSelectionMode: false,
    );

    final option = find.text('Je viens');
    expect(option, findsOneWidget);

    final absorbants = tester.widgetList<AbsorbPointer>(
      find.ancestor(of: option, matching: find.byType(AbsorbPointer)),
    );
    expect(
      absorbants.where((a) => a.absorbing),
      isEmpty,
      reason: 'aucune absorption ne doit couvrir le sondage hors sélection',
    );
    // Et le geste atteint bien sa cible, sans avertissement à taire.
    await tester.tap(option);
    await tester.pumpAndSettle();
  });
}
