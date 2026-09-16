import '../../domain/entities/gif_entity.dart';

/// Contenu proposé par un fournisseur de GIFs.
enum GifContentType {
  /// GIFs classiques (avec fond).
  gif,

  /// Stickers : médias à fond transparent.
  sticker,
}

/// Levée quand **aucun** fournisseur n'a de clé posée côté serveur.
///
/// Distincte d'une [ServerException] : c'est un état durable de la
/// configuration, pas une panne passagère. L'écran le dit autrement (« pas
/// encore configurés » plutôt que « impossible de charger »), et surtout ne
/// propose pas de réessayer — réessayer n'y changera rien.
class GifProvidersUnavailableException implements Exception {
  final String message;

  GifProvidersUnavailableException(this.message);

  @override
  String toString() => 'GifProvidersUnavailableException: $message';
}

/// Source des GIFs distants.
///
/// Un seul implémenteur en production ([GifProxyDataSource]) : le choix du
/// fournisseur appartient au serveur, qui est le seul à savoir quelles clés
/// existent. L'abstraction reste le point d'injection des tests.
abstract class GifRemoteDataSource {
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
