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

/// « Sélectionner » doit être visible au premier écran du menu d'appui long,
/// à côté de Répondre et Copier.
///
/// L'entrée existait déjà, mais dans `_secondaryOptionRows` — c'est-à-dire
/// derrière « Autres actions », qu'il faut d'abord déplier. Or c'est le SEUL
/// chemin vers la sélection multiple : un simple appui sur une bulle ne coche
/// rien tant que le mode n'est pas entré. La conversation sait pourtant déjà
/// tout faire une fois dedans (barre de compte, tout cocher, copier /
/// transférer / supprimer la sélection) — la fonction était donc complète
/// mais sans porte d'entrée trouvable.
///
/// Le sondage est testé à part parce que sa bulle est un widget à elle
/// (`PollMessageBubble`, qui relit `post_polls`) : il fallait vérifier que
/// l'appui long traverse bien jusqu'au menu commun au lieu d'être avalé par
/// la carte de vote.
MessageEntity _message({
  MessageType type = MessageType.text,
  String content = 'Qui vient samedi ?',
  String? pollId,
}) {
  return MessageEntity(
    id: 'msg-1',
    senderId: 'aicha',
    senderName: 'Aïcha Moussa',
    content: content,
    type: type,
    pollId: pollId,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  );
}

Future<void> _pump(
  WidgetTester tester,
  MessageEntity message, {
  void Function(MessageEntity)? onSelect,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Le sondage n'est jamais chargé ici : la bulle retombe sur la
        // question envoyée. Sans cette surcharge, le dépôt réel partirait
        // chercher Supabase.
        pollStreamProvider.overrideWith(
          (ref, pollId) => const Stream<PollEntity?>.empty(),
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
            onReply: (_) {},
            onSelect: onSelect,
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

  testWidgets('un message texte : Sélectionner est dans la liste visible', (
    tester,
  ) async {
    await _pump(tester, _message(), onSelect: (_) {});

    await tester.longPress(find.text('Qui vient samedi ?'));
    await tester.pumpAndSettle();

    // Le repère : « Autres actions » est encore replié. Tout ce qui est
    // trouvé ci-dessous l'est donc au premier écran.
    expect(find.text('Autres actions'), findsOneWidget);

    expect(find.text('Répondre'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
    expect(
      find.text('Sélectionner'),
      findsOneWidget,
      reason: 'l\'entrée était rangée derrière « Autres actions », '
          'où elle ne se trouvait pas',
    );
    // `findsOneWidget` vaut aussi garde anti-doublon : l'entrée ne doit pas
    // rester en double dans les actions secondaires.
  });

  testWidgets('un sondage : l\'appui long traverse la carte de vote', (
    tester,
  ) async {
    await _pump(
      tester,
      _message(type: MessageType.poll, pollId: 'poll-42'),
      onSelect: (_) {},
    );

    await tester.longPress(find.text('Qui vient samedi ?'));
    await tester.pumpAndSettle();

    expect(find.text('Sélectionner'), findsOneWidget);
  });

  testWidgets('toucher Sélectionner ferme la feuille et remonte le message', (
    tester,
  ) async {
    MessageEntity? selectionne;
    await _pump(tester, _message(), onSelect: (m) => selectionne = m);

    await tester.longPress(find.text('Qui vient samedi ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sélectionner'));
    await tester.pumpAndSettle();

    expect(selectionne?.id, 'msg-1');
    expect(find.text('Répondre'), findsNothing, reason: 'la feuille se ferme');
  });

  testWidgets('sans mode sélection, aucune entrée morte', (tester) async {
    // Les écrans qui affichent une bulle hors conversation (messages
    // favoris, recherche) ne passent pas `onSelect` : l'entrée doit
    // disparaître plutôt que de ne rien faire.
    await _pump(tester, _message());

    await tester.longPress(find.text('Qui vient samedi ?'));
    await tester.pumpAndSettle();

    expect(find.text('Répondre'), findsOneWidget);
    expect(find.text('Sélectionner'), findsNothing);
  });
}
