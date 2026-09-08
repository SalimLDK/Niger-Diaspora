import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_info.dart';
import '../../data/datasources/demarches_local_datasource.dart';
import '../../data/datasources/demarches_remote_datasource.dart';
import '../../data/repositories/demarches_repository_impl.dart';

part 'demarches_provider.g.dart';

@riverpod
DemarchesLocalDataSource demarchesLocalDataSource(Ref ref) {
  return DemarchesLocalDataSource();
}

@riverpod
DemarchesRemoteDataSource demarchesRemoteDataSource(Ref ref) {
  return DemarchesRemoteDataSource();
}

@riverpod
DemarchesRepositoryImpl demarchesRepository(Ref ref) {
  return DemarchesRepositoryImpl(
    remoteDataSource: ref.watch(demarchesRemoteDataSourceProvider),
    localDataSource: ref.watch(demarchesLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
}

/// Catalogue des démarches consulaires, avec son origine.
///
/// `keepAlive` volontaire. Un `autoDispose` se recycle entre le moment où
/// l'écran est construit et le premier geste de l'utilisateur ; un
/// `read(...).valueOrNull` rend alors `null` au premier tap et le bouton
/// paraît mort, sans rien dans logcat. Le catalogue est par ailleurs un objet
/// unique et figé pour la session : le garder coûte moins que le recharger.
@Riverpod(keepAlive: true)
Future<CatalogueCharge> demarchesCatalogue(Ref ref) async {
  return ref.watch(demarchesRepositoryProvider).getCatalogue();
}
