import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_providers.dart';
import 'package:diaspo_niger/core/providers/uid_firebase_provider.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/media_dechiffre_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// La panne du 2026-09-16 (build 1.2.1+19, Play Store) : au démarrage à froid,
/// la passerelle MLS était construite avant que Firebase ne rende
/// l'utilisateur, gardait `null` pour tout le processus, et chaque envoi dans
/// une conversation chiffrée partait en clair — refusé par le serveur.
void main() {
  /// Un uid qu'on fait arriver APRÈS la construction, comme au démarrage.
  final uid = StateProvider<String?>((ref) => null);

  ProviderContainer conteneur() {
    final c = ProviderContainer(overrides: [
      uidFirebaseProvider.overrideWith((ref) => ref.watch(uid)),
      featureFlagsProvider.overrideWith(
        (ref) => const FeatureFlagsEntity(
          mlsMessagesComptes: ['compte-a'],
          multiAppareilComptes: ['compte-a'],
        ),
      ),
      mlsDeliveryProvider.overrideWith(
        (ref) => MlsDelivery(ensureAuth: () async => true),
      ),
      mlsDeviceRegistryProvider.overrideWith(
        (ref) => MlsDeviceRegistry(
          moteur: (_) => throw UnimplementedError(),
          ensureAuth: () async => true,
        ),
      ),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('un uid arrivé après coup', () {
    test('fait apparaître la passerelle MLS', () {
      final c = conteneur();
      // Construite sans session : nulle, comme avant.
      expect(c.read(mlsGatewayProvider), isNull);

      c.read(uid.notifier).state = 'compte-a';

      final passerelle = c.read(mlsGatewayProvider);
      expect(passerelle, isNotNull,
          reason: 'la passerelle restait nulle pour tout le processus');
      expect(passerelle!.userId, 'compte-a');
    });

    test('ouvre le drapeau MLS du compte', () {
      final c = conteneur();
      expect(c.read(mlsMessagesActifsProvider), isFalse);
      c.read(uid.notifier).state = 'compte-a';
      expect(c.read(mlsMessagesActifsProvider), isTrue);
    });

    test('ouvre le multi-appareil du compte', () {
      final c = conteneur();
      expect(c.read(multiAppareilAutoriseProvider), isFalse);
      c.read(uid.notifier).state = 'compte-a';
      expect(c.read(multiAppareilAutoriseProvider), isTrue);
    });
  });

  test('changer de compte change de passerelle', () {
    // Sans ça, la passerelle du compte précédent survivait à la reconnexion
    // et signait ses envois d'un `sender_id` qui n'est plus le sien.
    final c = conteneur();
    c.read(uid.notifier).state = 'compte-a';
    final a = c.read(mlsGatewayProvider);
    c.read(uid.notifier).state = 'compte-b';
    final b = c.read(mlsGatewayProvider);
    expect(b?.userId, 'compte-b');
    expect(identical(a, b), isFalse);

    c.read(uid.notifier).state = null;
    expect(c.read(mlsGatewayProvider), isNull);
  });

  test('le même uid ne reconstruit pas la passerelle', () {
    // La règle tirée de la panne Signal tient toujours : un service
    // reconstruit sans raison repart « non initialisé ».
    final c = conteneur();
    c.read(uid.notifier).state = 'compte-a';
    final avant = c.read(mlsGatewayProvider);
    c.read(uid.notifier).state = 'compte-a';
    expect(identical(c.read(mlsGatewayProvider), avant), isTrue);
  });

  test('aucun provider dépendant du compte ne lit plus l’uid à la construction', () {
    String source(String chemin) =>
        File(chemin).readAsStringSync().replaceAll('\r\n', '\n');
    for (final chemin in [
      'lib/core/crypto/mls/mls_providers.dart',
      'lib/features/messages/presentation/providers/media_dechiffre_provider.dart',
    ]) {
      expect(source(chemin), isNot(contains('FirebaseAuth.instance.currentUser')),
          reason: '$chemin : observer uidFirebaseProvider, ne pas lire currentUser');
    }
  });
}
