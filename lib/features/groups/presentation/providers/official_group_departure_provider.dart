import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/official_group_departure_datasource.dart';

final officialGroupDepartureDataSourceProvider =
    Provider<OfficialGroupDepartureDataSource>(
  (ref) => OfficialGroupDepartureDataSource(),
);

/// Le départ à confirmer pour un groupe, `null` s'il n'y en a pas.
///
/// Un échec de lecture vaut « rien à proposer » : la fiche du groupe reste
/// utilisable, et la question se reposera à la prochaine ouverture. On ne
/// sort jamais personne sur la foi d'une lecture ratée — le départ passe
/// uniquement par la réponse explicite.
final pendingOfficialGroupDepartureProvider = FutureProvider.autoDispose
    .family<OfficialGroupDeparture?, String>((ref, groupId) async {
  try {
    return await ref
        .watch(officialGroupDepartureDataSourceProvider)
        .pendingFor(groupId);
  } catch (_) {
    return null;
  }
});
