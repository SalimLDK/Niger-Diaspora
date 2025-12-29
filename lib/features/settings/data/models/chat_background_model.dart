import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/chat_background_entity.dart';

part 'chat_background_model.freezed.dart';
part 'chat_background_model.g.dart';

@freezed
class ChatBackgroundModel with _$ChatBackgroundModel {
  const factory ChatBackgroundModel({
    required String type, // 'default', 'color', 'image'
    String? colorValue, // Hex color string (e.g., '#FF5733')
    String? imageUrl,
  }) = _ChatBackgroundModel;

  factory ChatBackgroundModel.fromJson(Map<String, dynamic> json) =>
      _$ChatBackgroundModelFromJson(json);

  factory ChatBackgroundModel.fromEntity(ChatBackgroundEntity entity) {
    switch (entity.type) {
      case ChatBackgroundType.defaultTheme:
        return const ChatBackgroundModel(type: 'default');
      case ChatBackgroundType.color:
        return ChatBackgroundModel(
          type: 'color',
          colorValue:
              entity.color != null
                  ? '#${entity.color!.toARGB32().toRadixString(16).padLeft(8, '0')}'
                  : null,
        );
      case ChatBackgroundType.image:
        return ChatBackgroundModel(type: 'image', imageUrl: entity.imageUrl);
    }
  }
}

extension ChatBackgroundModelX on ChatBackgroundModel {
  ChatBackgroundEntity toEntity() {
    switch (type) {
      case 'color':
        if (colorValue != null) {
          // Parse hex color string to Color
          final hexColor = colorValue!.replaceFirst('#', '');
          final intValue = int.parse(hexColor, radix: 16);
          return ChatBackgroundEntity.color(Color(intValue));
        }
        return const ChatBackgroundEntity.defaultTheme();
      case 'image':
        return ChatBackgroundEntity.image(imageUrl: imageUrl);
      case 'default':
      default:
        return const ChatBackgroundEntity.defaultTheme();
    }
  }
}
