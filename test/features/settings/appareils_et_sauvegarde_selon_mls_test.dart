import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/core/providers/uid_firebase_provider.dart';
import 'package:diaspo_niger/core/services/e2ee/device_sync_service.dart';
import 'package:diaspo_niger/core/services/e2ee/models/e2ee_models.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/media_dechiffre_provider.dart';
import 'package:diaspo_niger/features/settings/presentation/screens/devices_screen.dart';
import 'package:diaspo_niger/features/settings/presentation/screens/security_backup_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/l10n/app_localizations_fr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// « Appareils enregistrés » et « Sauvegarde des clés » montraient des clés
/// **Signal** à des comptes dont toutes les conversations chiffrées sont en
/// MLS — 0 message Signal sur les deux comptes basculés, mesuré le 2026-09-16.
/// Sur le Samsung : trois « Appareil Android » de juillet-août et un bandeau
/// d'alarme au-dessus de la seule liste qui comptait, et « Cet appareil n'a
/// pas vos clés » sur un téléphone qui lisait tous ses messages chiffrés.
///
/// Les autres comptes chiffrent encore en Signal : pour eux, rien ne change.
void main() {
  final l10n = AppLocalizationsFr();
  const compte = 'compte-a';
  final maintenant = DateTime.now();

  MlsDeviceRecord appareil(
    String id,
    String nom, {
    bool courant = false,
    DateTime? revoque,
  }) =>
      MlsDeviceRecord(
        id: id,
        userId: compte,
        stableId: id,
        name: nom,
        platform: 'android',
        mlsIdentity: '$compte:$id',
        createdAt: maintenant,
        lastSeenAt: maintenant,
        revokedAt: revoque,
        estCetAppareil: courant,
      );

  Future<void> monter(
    WidgetTester tester,
    Widget ecran, {
    required bool mlsActif,
    String? uid = compte,
    List<Override> autres = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mlsMessagesActifsProvider.overrideWithValue(mlsActif),
          uidFirebaseProvider.overrideWithValue(uid),
          ...autres,
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ecran,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('Appareils enregistrés', () {
    testWidgets('compte passé à MLS : le registre MLS seul, sans Signal',
        (tester) async {
      final sync = _FauxSync();
      await monter(
        tester,
        const DevicesScreen(),
        mlsActif: true,
        autres: [
          deviceSyncServiceProvider.overrideWithValue(sync),
          mlsDevicesProvider.overrideWith(
            (ref, _) async => [
              appareil('a', 'Samsung actuel', courant: true),
              appareil('b', 'Ancien Samsung', revoque: maintenant),
              appareil('c', 'Autre ancien', revoque: maintenant),
            ],
          ),
        ],
      );

      expect(find.text('Samsung actuel'), findsOneWidget);
      expect(find.text(l10n.mlsDevicesExplain), findsOneWidget);

      // Rien de Signal : ni compteur « sur 5 », ni limite, ni bandeau.
      expect(find.text(l10n.devicesRegisteredCount(3, 5)), findsNothing);
      expect(find.text(l10n.devicesLimitNotice(5)), findsNothing);
      expect(find.textContaining("n'a pas pu être identifié"), findsNothing);
      expect(sync.lectures, 0,
          reason: 'la liste Signal est masquée : inutile de la lire, et son '
              'échec afficherait une erreur sur un écran qui ne la montre pas');
    });

    testWidgets('les appareils révoqués sont repliés sous une ligne',
        (tester) async {
      await monter(
        tester,
        const DevicesScreen(),
        mlsActif: true,
        autres: [
          deviceSyncServiceProvider.overrideWithValue(_FauxSync()),
          mlsDevicesProvider.overrideWith(
            (ref, _) async => [
              appareil('a', 'Samsung actuel', courant: true),
              appareil('b', 'Ancien Samsung', revoque: maintenant),
              appareil('c', 'Autre ancien', revoque: maintenant),
            ],
          ),
        ],
      );

      expect(find.text(l10n.mlsDevicesRevokedCount(2)), findsOneWidget);
      expect(find.text('Ancien Samsung'), findsNothing,
          reason: 'six fiches barrées s\'empilaient sur le Pixel');

      await tester.tap(find.text(l10n.mlsDevicesRevokedCount(2)));
      await tester.pumpAndSettle();

      expect(find.text('Ancien Samsung'), findsOneWidget);
      expect(find.textContaining('Révoqué le '), findsNWidgets(2),
          reason: 'une fiche révoquée dit désormais quand');
    });

    testWidgets('compte encore en Signal, sans appareil MLS : la liste Signal seule',
        (tester) async {
      final sync = _FauxSync();
      await monter(
        tester,
        const DevicesScreen(),
        mlsActif: false,
        autres: [
          deviceSyncServiceProvider.overrideWithValue(sync),
          mlsDevicesProvider.overrideWith((ref, _) async => const []),
        ],
      );

      expect(sync.lectures, 1);
      expect(find.text(l10n.noDeviceRegistered), findsOneWidget);
      expect(find.text(l10n.mlsDevicesExplain), findsNothing);
      expect(find.text(l10n.mlsDevicesSectionTitle), findsNothing);
    });

    // Avant le 2026-09-22, ce cas ne montrait QUE la liste Signal, et le
    // registre n'était même pas lu. Or un compte hors du drapeau entre dans
    // une conversation chiffrée dès que l'autre bout l'a basculée : sur le
    // Pixel de Salim, deux appareils MLS actifs, aucun code de sécurité à
    // l'écran. Le registre se lit donc, et s'ajoute dès qu'il sert.
    testWidgets('compte hors drapeau déjà en MLS : le registre s\'ajoute',
        (tester) async {
      var registreLu = false;
      final sync = _FauxSync();
      await monter(
        tester,
        const DevicesScreen(),
        mlsActif: false,
        autres: [
          deviceSyncServiceProvider.overrideWithValue(sync),
          mlsDevicesProvider.overrideWith((ref, _) async {
            registreLu = true;
            return [appareil('a', 'Samsung actuel', courant: true)];
          }),
        ],
      );

      expect(registreLu, isTrue);
      expect(sync.lectures, 1, reason: 'la liste Signal reste lue et montrée');
      expect(find.text(l10n.mlsDevicesSectionTitle), findsOneWidget);
      expect(find.text(l10n.mlsDevicesExplain), findsOneWidget);
      expect(find.text('Samsung actuel'), findsOneWidget);
      expect(find.text(l10n.noDeviceRegistered), findsNothing,
          reason: 'une liste Signal vide ne doit pas cacher le registre');
    });
  });

  group('Sauvegarde des clés', () {
    testWidgets('compte passé à MLS : rien à sauvegarder, et pourquoi',
        (tester) async {
      await monter(tester, const SecurityBackupScreen(), mlsActif: true);

      expect(find.text(l10n.e2eeDescription), findsOneWidget);
      expect(find.text(l10n.mlsBackupKeysStay), findsOneWidget);
      expect(find.text(l10n.mlsBackupNewPhone), findsOneWidget);
      expect(find.text(l10n.connectedDevices), findsOneWidget);

      // Les sections Signal : transfert, état des clés, sauvegarde.
      expect(find.text(l10n.keyTransferReceiveAction), findsNothing);
      expect(find.text(l10n.keyTransferSendAction), findsNothing);
      expect(find.text(l10n.keyStateAbsent), findsNothing);
      expect(find.text(l10n.existingBackup), findsNothing);
      expect(find.text(l10n.createBackupButton), findsNothing);
    });

    testWidgets('compte encore en Signal : transfert et sauvegarde restent',
        (tester) async {
      // Sans uid, les lectures Signal sortent tôt : on ne regarde que ce que
      // l'écran choisit d'afficher.
      await monter(
        tester,
        const SecurityBackupScreen(),
        mlsActif: false,
        uid: null,
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is DesignSectionLabel && w.text == l10n.keyTransferSectionTitle,
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.keyTransferReceiveAction), findsOneWidget);
      expect(find.text(l10n.mlsBackupKeysStay), findsNothing);
    });
  });
}

class _FauxSync implements DeviceSyncService {
  int lectures = 0;

  @override
  Future<List<E2EEDeviceInfo>> getMyDevices(String userId) async {
    lectures++;
    return const [];
  }

  @override
  Future<E2EEDeviceInfo?> getCurrentDevice(String userId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
