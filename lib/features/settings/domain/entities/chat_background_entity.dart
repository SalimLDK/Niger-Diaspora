import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Type of chat background
enum ChatBackgroundType {
  defaultTheme, // Use default app theme background
  color, // Solid color
  image, // Custom image
  pattern, // Named procedural wallpaper (Sahel, Tissage, Nuit) — §21c
}

/// Entity representing a chat background customization
class ChatBackgroundEntity extends Equatable {
  final ChatBackgroundType type;
  final Color? color;
  final String? imageUrl; // Firebase Storage URL
  final String? localImagePath; // Local path (temporary)
  final String? patternId; // Id du motif nommé (cf. ChatWallpaper)

  const ChatBackgroundEntity({
    required this.type,
    this.color,
    this.imageUrl,
    this.localImagePath,
    this.patternId,
  });

  /// Default theme background
  const ChatBackgroundEntity.defaultTheme()
    : type = ChatBackgroundType.defaultTheme,
      color = null,
      imageUrl = null,
      localImagePath = null,
      patternId = null;

  /// Color background
  const ChatBackgroundEntity.color(this.color)
    : type = ChatBackgroundType.color,
      imageUrl = null,
      localImagePath = null,
      patternId = null;

  /// Image background
  const ChatBackgroundEntity.image({this.imageUrl, this.localImagePath})
    : type = ChatBackgroundType.image,
      color = null,
      patternId = null;

  /// Named procedural wallpaper (rendu par CustomPainter, aucun asset).
  const ChatBackgroundEntity.pattern(this.patternId)
    : type = ChatBackgroundType.pattern,
      color = null,
      imageUrl = null,
      localImagePath = null;

  bool get isDefault => type == ChatBackgroundType.defaultTheme;
  bool get isColor => type == ChatBackgroundType.color;
  bool get isImage => type == ChatBackgroundType.image;
  bool get isPattern => type == ChatBackgroundType.pattern;

  @override
  List<Object?> get props => [type, color, imageUrl, localImagePath, patternId];
}
