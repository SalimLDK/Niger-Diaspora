import 'dart:async';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/features/embassies/data/datasources/embassies_local_datasource.dart';
import 'package:diaspo_niger/features/embassies/data/datasources/embassies_supabase_datasource.dart';
import 'package:diaspo_niger/features/embassies/data/models/embassy_model.dart';
import 'package:diaspo_niger/features/embassies/data/repositories/embassies_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'annuaire ne doit jamais faire attendre sans fin.
///
/// Défaut vu sur SM A515F le 2026-09-08, mode avion : spinner encore présent
/// après 85 s, sans message ni bouton. Deux causes cumulées —
/// `networkInfo.isConnected` rendait `true` (un VPN persistant suffit à le
/// tromper), et la requête partie pour de bon n'en revenait jamais, le client
/// Supabase attendant lui-même le rafraîchissement du jeton.
void main() {
  const posteEnCache = EmbassyModel(
    id: 'cache-1',
    name: 'Ambassade du Niger en Allemagne',
    country: 'Allemagne',
    city: 'Berlin',
    address: 'Machnower Strasse 24',
    type: 'embassy',
  );

  test(
    'une requête qui ne revient jamais laisse place à la copie locale',
    () async {
      final depot = EmbassiesRepositoryImpl(
        // Se dit joignable — c'est précisément le mensonge du VPN.
        networkInfo: _ReseauDit(true),
        // Ne rend jamais la main, comme la vraie requête hors ligne.
        remoteDataSource: _DistantQuiNeRepondJamais(),
        localDataSource: _CacheAvec([posteEnCache]),
      );

      final postes = await depot.getEmbassies().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError(
          "le dépôt n'a pas rendu la main : le délai ne joue pas",
        ),
      );

      expect(postes, hasLength(1));
      expect(postes.single.name, 'Ambassade du Niger en Allemagne');
    },
    // Le délai du dépôt est de 10 s : le cas doit pouvoir l'attendre.
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'sans copie locale, on rend une liste vide — jamais une attente sans fin',
    () async {
      final depot = EmbassiesRepositoryImpl(
        networkInfo: _ReseauDit(true),
        remoteDataSource: _DistantQuiNeRepondJamais(),
        localDataSource: _CacheVide(),
      );

      expect(await depot.getEmbassies(), isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test('quand le distant répond, le délai ne gêne pas', () async {
    final depot = EmbassiesRepositoryImpl(
      networkInfo: _ReseauDit(true),
      remoteDataSource: _DistantQuiRepond([posteEnCache]),
      localDataSource: _CacheVide(),
    );

    expect(await depot.getEmbassies(), hasLength(1));
  });
}

class _ReseauDit implements NetworkInfo {
  _ReseauDit(this._connecte);
  final bool _connecte;
  @override
  Future<bool> get isConnected async => _connecte;
}

class _DistantQuiNeRepondJamais implements EmbassiesDataSource {
  @override
  Future<List<EmbassyModel>> getEmbassies() => Completer<List<EmbassyModel>>()
      .future; // jamais complété

  @override
  Future<EmbassyModel?> getEmbassyById(String id) async => null;
  @override
  Future<String> createEmbassy(EmbassyModel embassy) async => '';
  @override
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  }) async {}
}

class _DistantQuiRepond implements EmbassiesDataSource {
  _DistantQuiRepond(this._postes);
  final List<EmbassyModel> _postes;
  @override
  Future<List<EmbassyModel>> getEmbassies() async => _postes;
  @override
  Future<EmbassyModel?> getEmbassyById(String id) async => null;
  @override
  Future<String> createEmbassy(EmbassyModel embassy) async => '';
  @override
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  }) async {}
}

class _CacheAvec extends EmbassiesLocalDataSource {
  _CacheAvec(this._postes);
  final List<EmbassyModel> _postes;
  @override
  Future<List<EmbassyModel>> getLastEmbassies() async => _postes;
  @override
  Future<void> cacheEmbassies(List<EmbassyModel> embassies) async {}
  @override
  Future<DateTime?> cachedAt() async => DateTime(2026, 9, 8);
  @override
  Future<void> clear() async {}
}

class _CacheVide extends EmbassiesLocalDataSource {
  @override
  Future<List<EmbassyModel>> getLastEmbassies() async =>
      throw CacheException('vide');
  @override
  Future<void> cacheEmbassies(List<EmbassyModel> embassies) async {}
  @override
  Future<DateTime?> cachedAt() async => null;
  @override
  Future<void> clear() async {}
}
