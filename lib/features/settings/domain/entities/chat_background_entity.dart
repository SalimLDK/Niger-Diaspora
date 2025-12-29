import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Type of chat background
enum ChatBackgroundType {
  defaultTheme, // Use default app theme background
  color, // Solid color
  image, // Custom image
}

/// Entity representing a chat background customization
class ChatBackgroundEntity extends Equatable {
  final ChatBackgroundType type;
  final Color? color;
  final String? imageUrl; // Firebase Storage URL
  final String? localImagePath; // Local path (temporary)

  const ChatBackgroundEntity({
    required this.type,
    this.color,
    this.imageUrl,
    this.localImagePath,
  });

  /// Default theme background
  const ChatBackgroundEntity.defaultTheme()
    : type = ChatBackgroundType.defaultTheme,
      color = null,
      imageUrl = null,
      localImagePath = null;

  /// Color background
  const ChatBackgroundEntity.color(this.color)
    : type = ChatBackgroundType.color,
      imageUrl = null,
      localImagePath = null;

  /// Image background
  const ChatBackgroundEntity.image({this.imageUrl, this.localImagePath})
    : type = ChatBackgroundType.image,
      color = null;

  bool get isDefault => type == ChatBackgroundType.defaultTheme;
  bool get isColor => type == ChatBackgroundType.color;
  bool get isImage => type == ChatBackgroundType.image;

  @override
  List<Object?> get props => [type, color, imageUrl, localImagePath];
}
