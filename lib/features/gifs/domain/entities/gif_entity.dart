import 'package:equatable/equatable.dart';

/// Fournisseur d'origine d'un GIF/sticker distant.
enum GifProvider { tenor, giphy }

/// Un GIF (ou sticker anim├®) servi par un fournisseur externe.
///
/// [url] est le m├®dia ├á envoyer/afficher en grand, [previewUrl] la version
/// l├®g├¿re affich├®e dans la grille du picker (bande passante r├®duite).
class GifEntity extends Equatable {
  final String id;
  final String url;
  final String previewUrl;
  final GifProvider provider;

  /// Ratio largeur/hauteur, utilis├® pour la grille en quinconce.
  final double aspectRatio;

  /// Description textuelle, utilis├®e comme label d'accessibilit├®.
  final String? description;

  const GifEntity({
    required this.id,
    required this.url,
    required this.previewUrl,
    required this.provider,
    this.aspectRatio = 1.0,
    this.description,
  });

  /// Identifiant de ┬½ pack ┬╗ utilis├® lorsque le GIF est envoy├® en message.
  String get packId => provider.name;

  @override
  List<Object?> get props => [id, url, previewUrl, provider];
}
