import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/message_bubble.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Le repère posé à la bascule vers le chiffrement de bout en bout portait
/// son libellé **en dur, en français**, dans `MlsMessageMapper.separateur` :
/// un compte en anglais lisait « Messages d'avant le chiffrement de bout en
/// bout » au milieu d'une interface anglaise, et aucune clé `.arb` ne
/// couvrait cette phrase.
///
/// Le texte est maintenant résolu à l'affichage. Ce fichier verrouille les
/// deux moitiés du correctif : le séparateur ne transporte plus de texte, et
/// la bulle système en affiche un dans la langue courante.
Future<void> _pump(
  WidgetTester tester,
  MessageEntity message, {
  Locale locale = const Locale('fr'),
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
        locale: locale,
        theme: ThemeData.light(),
        home: Scaffold(
          body: MessageBubble(
            message: message,
            isMe: false,
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
  final bascule = DateTime.utc(2026, 9, 15, 12);

  test('le séparateur ne transporte plus de texte', () {
    final separateur = MlsMessageMapper.separateur(bascule);

    expect(
      separateur.content,
      isEmpty,
      reason: 'un texte ici serait figé dans la langue de la fusion',
    );
    expect(separateur.estSeparateurMls, isTrue);
    expect(separateur.isSystem, isTrue);
  });

  test('un message ordinaire n\'est jamais pris pour le séparateur', () {
    final message = MessageEntity(
      id: 'a3f1c2d4-0000-4000-8000-000000000001',
      senderId: 'aicha',
      senderName: 'Aïcha',
      content: 'Salut',
      type: MessageType.text,
      createdAt: bascule,
    );

    expect(message.estSeparateurMls, isFalse);
    expect(MessageEntity.idSeparateurMls.startsWith('__'), isTrue);
  });

  testWidgets('en français, le repère annonce le chiffrement', (tester) async {
    await _pump(tester, MlsMessageMapper.separateur(bascule));

    expect(find.text('Les messages sont chiffrés de bout en bout'), findsOne);
  });

  testWidgets('en anglais, il est en anglais', (tester) async {
    // C'est le défaut d'origine : la phrase française était servie telle
    // quelle, quelle que soit la langue du compte.
    await _pump(
      tester,
      MlsMessageMapper.separateur(bascule),
      locale: const Locale('en'),
    );

    expect(find.text('Messages are end-to-end encrypted'), findsOne);
    expect(find.textContaining('chiffr'), findsNothing);
  });

  testWidgets('les autres messages système gardent leur propre texte', (
    tester,
  ) async {
    await _pump(
      tester,
      MessageEntity(
        id: 'sys-1',
        senderId: 'system',
        senderName: '',
        content: 'Aïcha a rejoint le groupe',
        type: MessageType.system,
        createdAt: bascule,
      ),
    );

    expect(find.text('Aïcha a rejoint le groupe'), findsOne);
  });
}
