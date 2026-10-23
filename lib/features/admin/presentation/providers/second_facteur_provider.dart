import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/second_facteur.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Les facteurs enrôlés sur le compte courant, relus à chaque montage.
///
/// `autoDispose` : la liste change au cours de la session (l'enrôlement
/// l'allonge) et rien ne la met à jour tout seul. Gardé en vie, le provider
/// aurait servi « aucun facteur » après l'enrôlement, et la garde de
/// `/dashboard` aurait renvoyé l'admin sur l'écran qu'il venait de quitter.
/// L'écran d'enrôlement l'invalide en plus, pour le cas où une garde est
/// encore montée.
///
/// Un `Left` **lève** : la garde le traite comme un jeton illisible (écran
/// de connexion), jamais comme « aucun facteur », qui ouvrirait l'enrôlement
/// sur une session morte.
final facteursEnrolesProvider =
    FutureProvider.autoDispose<List<FacteurEnrole>>((ref) async {
  final resultat = await ref.watch(authRepositoryProvider).facteursEnroles();
  return resultat.fold(
    (echec) => throw StateError(echec.message),
    (facteurs) => facteurs,
  );
});
