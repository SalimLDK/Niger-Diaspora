import '../../domain/entities/gif_entity.dart';

/// Contenu propos├® par un fournisseur de GIFs.
enum GifContentType {
  /// GIFs classiques (avec fond).
  gif,

  /// Stickers : m├®dias ├á fond transparent.
  sticker,
}

/// Interface commune aux fournisseurs de GIFs (Tenor, Giphy).
///
/// Permet de changer de fournisseur, d'en ajouter un, ou de basculer en
/// fallback sans toucher ├á la couche pr├®sentation.
abstract class GifRemoteDataSource {
  GifProvider get provider;

  /// True si une cl├® API est configur├®e pour ce fournisseur.
  bool get isConfigured;

  /// Contenus en tendance.
  Future<List<GifEntity>> trending({
    GifContentType type = GifContentType.gif,
    int limit = 30,
  });

  /// Recherche par mot-cl├®.
  Future<List<GifEntity>> search(
    String query, {
    GifContentType type = GifContentType.gif,
    int limit = 30,
  });
}
