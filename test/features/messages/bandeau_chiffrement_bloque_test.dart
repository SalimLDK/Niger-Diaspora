import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_metadonnees.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_providers.dart';
import 'package:diaspo_niger/features/messages/presentation/widgets/bandeau_chiffrement_bloque.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/l10n/app_localizations_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le bandeau « chiffrement bloqué » et son bouton « Réparer ».
///
/// Sans lui, un groupe bloqué ne se voyait que dans `mls_diagnostics` : plus
/// aucun message lisible, et rien à l'écran pour le dire ni pour en sortir.
void main() {
  final fr = AppLocalizationsFr();

  Future<_Passerelle> monter(
    WidgetTester tester, {
    required bool bloque,
    Object? refus,
  }) async {
    final passerelle = _Passerelle(refus: refus);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        groupeMlsBloqueProvider('c1').overrideWith((ref) => Stream.value(bloque)),
        mlsGatewayProvider.overrideWithValue(passerelle),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('fr'),
        home: Scaffold(body: BandeauChiffrementBloque(conversationId: 'c1')),
      ),
    ));
    await tester.pump();
    return passerelle;
  }

  testWidgets('rien de bloqué : rien à l\'écran', (tester) async {
    await monter(tester, bloque: false);
    expect(find.text(fr.chiffrementBloqueTexte), findsNothing);
  });

  testWidgets('bloqué : dit, et « Réparer » répare après confirmation',
      (tester) async {
    final passerelle = await monter(tester, bloque: true);
    expect(find.text(fr.chiffrementBloqueTexte), findsOneWidget);

    await tester.tap(find.text(fr.chiffrementBloqueReparer));
    await tester.pumpAndSettle();
    expect(find.text(fr.chiffrementReparerTitre), findsOneWidget);
    expect(passerelle.reparations, isEmpty, reason: 'pas avant la confirmation');

    await tester.tap(find.widgetWithText(FilledButton, fr.chiffrementBloqueReparer));
    await tester.pumpAndSettle();

    expect(passerelle.reparations, ['c1']);
    expect(find.text(fr.chiffrementReparerOk), findsOneWidget);
  });

  testWidgets('annuler la confirmation ne répare rien', (tester) async {
    final passerelle = await monter(tester, bloque: true);
    await tester.tap(find.text(fr.chiffrementBloqueReparer));
    await tester.pumpAndSettle();
    await tester.tap(find.text(fr.cancel));
    await tester.pumpAndSettle();
    expect(passerelle.reparations, isEmpty);
  });

  testWidgets('refus du serveur : dit pourquoi, dans la langue', (tester) async {
    await monter(
      tester,
      bloque: true,
      refus: StateError('reconstruire_groupe_mls : réservé aux administrateurs du groupe'),
    );
    await tester.tap(find.text(fr.chiffrementBloqueReparer));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, fr.chiffrementBloqueReparer));
    await tester.pumpAndSettle();

    expect(find.text(fr.chiffrementReparerReserveAdmin), findsOneWidget);
  });

  test('les refus du serveur sont reconnus', () {
    expect(
      messageDeRefusReparation(
          Exception('déjà reconstruit il y a moins de 5 minutes'), fr),
      fr.chiffrementReparerTropRecent,
    );
    expect(messageDeRefusReparation(Exception('réseau'), fr),
        fr.chiffrementReparerEchec);
  });
}

class _Transport extends MlsDelivery {
  _Transport() : super(ensureAuth: () async => true);
}

class _Passerelle extends MlsGateway {
  _Passerelle({this.refus})
      : super(
          userId: 'u1',
          actif: () => false,
          service: MlsConversationService(
            userId: 'u1',
            moteur: () => throw StateError('inutile ici'),
            delivery: _Transport(),
            appareil: () => throw StateError('inutile ici'),
          ),
          delivery: _Transport(),
          metadonnees: MlsMetadonnees(userId: 'u1', ensureAuth: () async => true),
        );

  final Object? refus;
  final reparations = <String>[];

  @override
  Future<void> reparer(String conversationId) async {
    final r = refus;
    if (r != null) throw r;
    reparations.add(conversationId);
  }
}
