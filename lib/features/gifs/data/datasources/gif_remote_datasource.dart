import '../../domain/entities/gif_entity.dart';

/// Contenu proposé par un fournisseur de GIFs.
enum GifContentType {
  /// GIFs classiques (avec fond).
  gif,

  /// Stickers : médias à fond transparent.
  sticker,
}

/// Interface commune aux fournisseurs de GIFs (Tenor, Giphy).
///
/// Permet de changer de fournisseur, d'en ajouter un, ou de basculer en
/// fallback sans toucher à la couche présentation.
abstract class GifRemoteDataSource {
  GifProvider get provider;

  /// True si une clé API est configurée pour ce fournisseur.
  bool get isConfigured;

  /// Contenus en tendance.
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  });

  /// Recherche par mot-clé.
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  });
}
