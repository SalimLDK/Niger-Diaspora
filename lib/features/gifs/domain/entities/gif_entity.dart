import 'package:equatable/equatable.dart';

/// Fournisseur d'origine d'un GIF/sticker distant.
enum GifProvider { tenor, giphy }

/// Un GIF (ou sticker animé) servi par un fournisseur externe.
///
/// [url] est le média à envoyer/afficher en grand, [previewUrl] la version
/// légère affichée dans la grille du picker (bande passante réduite).
class GifEntity extends Equatable {
  final String id;
  final String url;
  final String previewUrl;
  final GifProvider provider;

  /// Ratio largeur/hauteur, utilisé pour la grille en quinconce.
  final double aspectRatio;

  /// Description textuelle, utilisée comme label d'accessibilité.
  final String? description;

  const GifEntity({
    required this.id,
    required this.url,
    required this.previewUrl,
    required this.provider,
    this.aspectRatio = 1.0,
    this.description,
  });

  /// Identifiant de « pack » utilisé lorsque le GIF est envoyé en message.
  String get packId => provider.name;

  @override
  List<Object?> get props => [id, url, previewUrl, provider];
}
