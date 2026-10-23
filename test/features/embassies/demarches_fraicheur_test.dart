import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/features/embassies/data/datasources/demarches_local_datasource.dart';
import 'package:diaspo_niger/features/embassies/data/datasources/demarches_remote_datasource.dart';
import 'package:diaspo_niger/features/embassies/data/models/demarche_model.dart';
import 'package:diaspo_niger/features/embassies/data/repositories/demarches_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une démarche dépubliée reste lisible hors ligne jusqu'à la prochaine
/// synchronisation : l'usager doit au moins voir de quand date sa liste, et
/// la date de vérification de chaque démarche doit survivre au cache.

DemarchesCatalogue _catalogue({int version = 2}) => DemarchesCatalogue.fromJson({
      'version': version,
      'source': {'editeur': 'Ministère', 'url': 'https://exemple.ne', 'consulteLe': '2026-09-07'},
      'rubriques': [
        {'id': 'etat_civil', 'titre': 'État civil', 'ordre': 1},
      ],
      'demarches': [
        {
          'id': 'declaration_naissance',
          'titre': 'Déclaration de naissance',
          'rubrique': 'etat_civil',
          'requestType': 'birthCertificate',
          'cout': {'statut': 'inconnu'},
          'sourceUrl': 'https://exemple.ne/naissance',
          'verifieLe': '2026-10-01T00:00:00.000Z',
        },
      ],
    });

class _Hors implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

class _Local extends DemarchesLocalDataSource {
  _Local({this.cache, this.date, this.embarque});
  final DemarchesCatalogue? cache;
  final DateTime? date;
  final DemarchesCatalogue? embarque;

  @override
  Future<DemarchesCatalogue> getCachedCatalogue() async =>
      cache ?? (throw CacheException('vide'));

  @override
  Future<DateTime?> getCacheDate() async => date;

  @override
  Future<DemarchesCatalogue> getBundledCatalogue() async =>
      embarque ?? (throw CacheException('absent'));
}

void main() {
  test('la source et la date de vérification d\'une démarche sont lues', () {
    final d = _catalogue().demarches.single;
    expect(d.sourceUrl, 'https://exemple.ne/naissance');
    expect(d.verifieLe, DateTime.utc(2026, 10, 1));
  });

  test('une copie sans ces champs (embarquée d\'origine) reste lisible', () {
    final c = DemarchesCatalogue.fromJson({
      'version': 1,
      'source': {'editeur': 'M', 'url': 'https://x.ne', 'consulteLe': '2026-09-07'},
      'rubriques': [],
      'demarches': [
        {
          'id': 'a',
          'titre': 'A',
          'rubrique': 'r',
          'requestType': 'other',
          'cout': {'statut': 'inconnu'},
        },
      ],
    });
    expect(c.demarches.single.verifieLe, isNull);
    expect(c.demarches.single.sourceUrl, isNull);
  });

  test('hors ligne, le cache rend sa date de chargement', () async {
    final date = DateTime(2026, 10, 10, 9);
    final repo = DemarchesRepositoryImpl(
      remoteDataSource: DemarchesRemoteDataSource(),
      localDataSource: _Local(cache: _catalogue(), date: date),
      networkInfo: _Hors(),
    );
    final charge = await repo.getCatalogue();
    expect(charge.origine, OrigineCatalogue.cache);
    expect(charge.synchroniseLe, date);
  });

  test('la copie embarquée plus récente que le cache n\'affiche pas de date de cache', () async {
    final repo = DemarchesRepositoryImpl(
      remoteDataSource: DemarchesRemoteDataSource(),
      localDataSource: _Local(
        cache: _catalogue(version: 1),
        date: DateTime(2026, 9, 1),
        embarque: _catalogue(version: 3),
      ),
      networkInfo: _Hors(),
    );
    final charge = await repo.getCatalogue();
    expect(charge.origine, OrigineCatalogue.embarque);
    expect(charge.synchroniseLe, isNull);
  });
}
