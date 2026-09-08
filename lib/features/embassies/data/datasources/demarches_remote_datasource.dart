import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/demarche_model.dart';

/// Catalogue des démarches servi par Supabase.
///
/// Passe par la RPC `get_demarches_catalogue()` plutôt que par trois SELECT :
/// un seul aller-retour, et surtout une forme de sortie **identique** à celle
/// du fichier `assets/data/demarches_consulaires.json`. Le même
/// [DemarchesCatalogue.fromJson] parse les trois sources — base, cache, asset
/// — sans branche conditionnelle, et une divergence de schéma se voit dès le
/// premier chargement au lieu de se cacher dans un mapping parallèle.
///
/// La RPC est ouverte à `anon` : l'écran doit s'afficher avant toute
/// connexion. Aucun appel à `ensureAuthenticated()` n'est donc nécessaire ici
/// — c'est une lecture publique, pas une écriture.
class DemarchesRemoteDataSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<DemarchesCatalogue> getCatalogue() async {
    try {
      final reponse = await _supabase.rpc<dynamic>('get_demarches_catalogue');

      // La RPC rend NULL tant que `demarches_catalogue_meta` est vide : la
      // migration d'amorce n'a pas encore été poussée sur ce projet.
      if (reponse == null) {
        throw ServerException(
          'Catalogue des démarches absent côté serveur '
          '(migration d\'amorce non appliquée ?)',
        );
      }
      if (reponse is! Map) {
        throw ServerException(
          'Forme inattendue pour le catalogue des démarches : '
          '${reponse.runtimeType}',
        );
      }
      return DemarchesCatalogue.fromJson(Map<String, dynamic>.from(reponse));
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Chargement du catalogue des démarches : $e');
    }
  }
}
