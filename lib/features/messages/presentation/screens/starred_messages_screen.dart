import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class StarredMessagesScreen extends ConsumerWidget {
  final String conversationId;

  const StarredMessagesScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final starredAsync = ref.watch(starredMessagesProvider(conversationId));

    return Scaffold(
      backgroundColor: context.surfaceColor,
      // §24b : écran crème ordinaire. La barre terracotta à texte blanc
      // faisait de la liste des favoris un écran « spécial » alors que
      // c'est une consultation comme une autre.
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
        ),
        // Le titre prend le Playfair du thème : pas de style en dur.
        title: Text(AppLocalizations.of(context)!.starredMessages),
      ),
      body: starredAsync.when(
        loading:
            () => Center(
              child: CircularProgressIndicator(
                color: context.adaptivePrimaryColor,
              ),
            ),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(AppIcon.error,
                    size: 48,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.adminLoadingError,
                    style: TextStyle(color: context.textSecondaryColor),
                  ),
                ],
              ),
            ),
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    AppIcon.starBorder,
                    size: 64,
                    color: context.textTertiaryColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noStarredMessages,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maintenez un message pour\nl\'ajouter aux favoris',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length,
            separatorBuilder:
                (_, __) =>
                    Divider(height: 1, indent: 72, color: context.dividerColor),
            itemBuilder: (context, index) {
              final message = messages[index];
              return _StarredMessageTile(
                message: message,
                onTap: () => Navigator.pop(context, message.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _StarredMessageTile extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback? onTap;

  const _StarredMessageTile({required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: context.adaptivePrimaryColor.withValues(alpha: 0.15),
        child: Text(
          _getInitials(message.senderName),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.adaptivePrimaryColor,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              message.senderName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDate(context, message.createdAt),
            style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildExcerpt(context)),
                const SizedBox(width: 8),
                const AppIcon(AppIcon.star, size: 14, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 6),
            // Affordance explicite : le tap remonte au message dans la conv.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Aller au message',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: context.adaptivePrimaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Extrait typé : bloc « note vocale » distinct pour l'audio, sinon icône
  /// de type + texte tronqué (§14).
  Widget _buildExcerpt(BuildContext context) {
    final isVoice = message.type == MessageType.voiceNote ||
        message.type == MessageType.audio;
    if (isVoice) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.surfaceVariantColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcon.mic, size: 14, color: context.adaptivePrimaryColor),
              const SizedBox(width: 6),
              Text(
                'Note vocale · ${message.audioDurationFormatted}',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        if (message.type != MessageType.text) ...[
          _getTypeIcon(message.type, size: 14, color: context.textTertiaryColor),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            _getPreview(message),
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat.Hm().format(date);
    } else if (diff.inDays == 1) {
      return AppLocalizations.of(context)!.yesterday('');
    } else if (diff.inDays < 7) {
      return DateFormat.E(LocaleHelper.getDateFormatLocale(context)).format(date);
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }

  Widget _getTypeIcon(MessageType type, {double size = 24, Color? color}) {
    switch (type) {
      case MessageType.image:
        return AppIcon(AppIcon.image, size: size, color: color);
      case MessageType.video:
        return AppIcon(AppIcon.video, size: size, color: color);
      case MessageType.voiceNote:
        return AppIcon(AppIcon.mic, size: size, color: color);
      case MessageType.audio:
        return Icon(Icons.audiotrack, size: size, color: color);
      case MessageType.file:
        return Icon(Icons.insert_drive_file, size: size, color: color);
      default:
        return AppIcon(AppIcon.chatBubble, size: size, color: color);
    }
  }

  String _getPreview(MessageEntity message) {
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return 'Photo';
      case MessageType.video:
        return 'Vidéo';
      case MessageType.voiceNote:
        return 'Message vocal';
      case MessageType.audio:
        return 'Audio';
      case MessageType.file:
        return message.fileName ?? 'Document';
      case MessageType.system:
        return message.content;
      case MessageType.call:
        return 'Appel';
      case MessageType.location:
        return '📍 ${message.locationAddress ?? 'Position'}';
      case MessageType.sticker:
        return '🎭 Sticker';
    }
  }
}
