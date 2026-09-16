import '../../domain/entities/gif_entity.dart';
import '../datasources/gif_remote_datasource.dart';

/// Façade des GIFs distants pour la couche présentation.
///
/// Le repli d'un fournisseur sur l'autre **n'est plus ici** : il a lieu dans
/// l'Edge Function `gif-proxy`, seule à savoir quelles clés existent. Un repli
/// côté client obligeait à interroger un fournisseur pour apprendre qu'il n'est
/// pas configuré — un aller-retour perdu par requête, à chaque fois.
class GifRepository {
  final GifRemoteDataSource _source;

  GifRepository(this._source);

  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _source.trending(type: type, limit: limit);
  }

  /// Recherche par mot-clé ; une requête vide retombe sur les tendances.
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return trending(type: type, limit: limit);
    return _source.search(trimmed, type: type, limit: limit);
  }
}
