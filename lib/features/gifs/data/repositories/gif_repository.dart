import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/gif_entity.dart';
import '../datasources/gif_remote_datasource.dart';

/// Agrège les fournisseurs de GIFs derrière une seule API.
///
/// Les sources sont interrogées dans l'ordre fourni (Tenor puis Giphy) : la
/// première configurée qui répond gagne. Si elle échoue (réseau, quota, clé
/// invalide), on bascule silencieusement sur la suivante — l'utilisateur voit
/// des GIFs tant qu'au moins un fournisseur répond.
class GifRepository {
  final List<GifRemoteDataSource> _sources;

  GifRepository(this._sources);

  /// True si au moins un fournisseur a une clé API.
  bool get isConfigured => _sources.any((s) => s.isConfigured);

  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    return _firstAvailable(
      (source) => source.trending(type: type, limit: limit),
    );
  }

  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return trending(type: type, limit: limit);
    return _firstAvailable(
      (source) => source.search(trimmed, type: type, limit: limit),
    );
  }

  Future<List<GifEntity>> _firstAvailable(
    Future<List<GifEntity>> Function(GifRemoteDataSource) request,
  ) async {
    final configured = _sources.where((s) => s.isConfigured).toList();
    if (configured.isEmpty) {
      throw ServerException(
        'Aucun fournisseur de GIFs disponible',
      );
    }

    Object? lastError;
    for (final source in configured) {
      try {
        return await request(source);
      } catch (e) {
        lastError = e;
      }
    }
    throw ServerException('Aucun fournisseur de GIFs disponible : $lastError');
  }
}
