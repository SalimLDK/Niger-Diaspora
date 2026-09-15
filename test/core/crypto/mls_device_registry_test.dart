import 'dart:io';
import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS, phase 2)
/// ---------------------------------------------
/// Le registre d'appareils est l'endroit exact où le chantier Signal s'est
/// arrêté sans bruit : des lignes en base, rien qui les fasse vivre. Trois
/// gardes de structure vérifient que le registre est CÂBLÉ — appelé à la
/// connexion, sans dépendance qui le ferait reconstruire — et deux tests
/// unitaires couvrent la logique pure (réapprovisionnement, encodage bytea).

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('réapprovisionnement des KeyPackages', () {
    test('rien tant que la réserve est suffisante, un lot entier sinon', () {
      expect(MlsDeviceRegistry.aGenerer(50), 0);
      expect(MlsDeviceRegistry.aGenerer(MlsDeviceRegistry.seuilRecharge), 0);
      expect(
        MlsDeviceRegistry.aGenerer(MlsDeviceRegistry.seuilRecharge - 1),
        MlsDeviceRegistry.lotRecharge,
      );
      expect(MlsDeviceRegistry.aGenerer(0), MlsDeviceRegistry.lotRecharge);
    });
  });

  group('bytea', () {
    test('aller-retour hex PostgREST', () {
      final octets = Uint8List.fromList([0, 1, 127, 128, 255]);
      final hex = MlsDeviceRegistry.versBytea(octets);
      expect(hex, r'\x00017f80ff');
      expect(MlsDeviceRegistry.depuisBytea(hex), octets);
      expect(MlsDeviceRegistry.depuisBytea('00017f80ff'), octets);
    });
  });

  group('ligne mls_devices', () {
    test('« cet appareil » se reconnaît au stable_id, révocation lue', () {
      final ligne = MlsDeviceRecord.fromRow({
        'id': 'd1',
        'user_id': 'u1',
        'stable_id': 'abc',
        'name': 'Samsung SM-A515F',
        'platform': 'android',
        'mls_identity': 'u1:abc',
        'created_at': '2026-09-15T00:00:00Z',
        'last_seen_at': '2026-09-15T01:00:00Z',
        'revoked_at': null,
      }, stableIdCourant: 'abc');
      expect(ligne.estCetAppareil, isTrue);
      expect(ligne.estRevoque, isFalse);

      final autre = MlsDeviceRecord.fromRow({
        'id': 'd2',
        'stable_id': 'zzz',
        'revoked_at': '2026-09-15T02:00:00Z',
      }, stableIdCourant: 'abc');
      expect(autre.estCetAppareil, isFalse);
      expect(autre.estRevoque, isTrue);
    });
  });

  group('câblage — ce qui a manqué au chantier Signal', () {
    test('le registre est appelé à la connexion, avec réessais', () {
      final source = _source(
        'lib/features/auth/presentation/providers/auth_provider.dart',
      );
      expect(source, contains('mlsDeviceRegistryProvider'));
      expect(source, contains('ensureRegisteredWithRetry('));
    });

    test('le moteur ne dépend que de l’identifiant utilisateur', () {
      final source = _source('lib/core/crypto/mls/mls_engine_provider.dart');
      // Aucun `ref.watch(` : un moteur qui observe d'autres providers se fait
      // reconstruire et repart « non initialisé » sans que rien ne le rejoue.
      expect(source.contains('ref.watch('), isFalse);
      expect(source.contains('FutureProvider.family<Moteur, String>'), isTrue);
      expect(source.contains('.autoDispose'), isFalse);
    });

    test('le registre lit le moteur par `ref.read`, jamais `ref.watch`', () {
      final source = _source('lib/core/crypto/mls/mls_device_registry.dart');
      final bloc = source.substring(source.indexOf('mlsDeviceRegistryProvider ='));
      final corps = bloc.substring(0, bloc.indexOf('});') + 3);
      expect(corps.contains('ref.watch('), isFalse);
      expect(corps.contains('ref.read(mlsEngineProvider('), isTrue);
    });

    test('toute lecture et écriture passe par ensureAuthenticated', () {
      final source = _source('lib/core/crypto/mls/mls_device_registry.dart');
      for (final methode in ['ensureRegistered(', 'myDevices(', 'revoke(', 'rename(']) {
        final debut = source.indexOf('Future<') + 0;
        expect(debut, greaterThan(-1));
        final i = source.indexOf(methode);
        expect(i, greaterThan(-1), reason: methode);
        final corps = source.substring(i, i + 400);
        expect(corps, contains('_ensureAuth()'), reason: methode);
      }
    });

    test('une identité MLS changée purge les KeyPackages de l’appareil', () {
      // Trouvé par le banc le 2026-09-15 : après une réinstallation, les
      // paquets de l'installation d'avant restaient publiés, le compteur de
      // réapprovisionnement les voyait, et l'ajout du nouvel appareil
      // échouait sur une clé déjà présente dans l'arbre.
      final source = _source('lib/core/crypto/mls/mls_device_registry.dart');
      expect(source, contains("select('id, mls_identity')"),
          reason: 'lire l’identité AVANT de l’écraser');
      expect(source, contains("identiteAvant.isNotEmpty && identiteAvant != identite"));
      expect(source, contains("from('mls_key_packages').delete().eq('device_id'"));
      expect(source, contains("'identite_mls_changee'"));
    });

    test('une révocation refusée par le RLS lève, au lieu de mentir', () {
      // Un `update` que le RLS refuse touche zéro ligne sans erreur : l'écran
      // annonçait « appareil révoqué » alors que rien n'avait bougé.
      final source = _source('lib/core/crypto/mls/mls_device_registry.dart');
      final i = source.indexOf('Future<void> revoke(');
      expect(i, greaterThan(-1));
      final corps = source.substring(i, i + 900);
      expect(corps, contains(".select('id')"));
      expect(corps, contains('throw StateError'));
    });

    test('la migration ne laisse rien à anon et réclame les paquets par RPC', () {
      final sql = _source(
        'supabase/migrations/20260915100000_mls_registre_appareils.sql',
      );
      for (final table in ['mls_devices', 'mls_key_packages', 'mls_diagnostics']) {
        expect(sql, contains('REVOKE ALL ON public.$table FROM anon'), reason: table);
        expect(sql, contains('ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY'));
      }
      expect(sql, contains('FOR UPDATE SKIP LOCKED'));
      expect(sql, isNot(contains('FOR UPDATE TO authenticated\n  USING (EXISTS (\n    SELECT 1 FROM public.mls_devices d')),
          reason: 'pas de policy UPDATE sur mls_key_packages : la consommation passe par claim_key_package');
    });
  });
}
