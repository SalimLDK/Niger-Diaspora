import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/message_provider.dart';
import 'conversation_picker_sheet.dart';

/// Ce qu'un partage interne dépose dans une discussion : le texte du message,
/// la charge structurée qui décide de la bulle affichée à l'arrivée, et de
/// quoi dessiner l'aperçu avant l'envoi.
///
/// Les charges structurées sont celles que `sendText` sait déjà transporter de
/// bout en bout : `postData` (→ `PostMessageCard`), `eventData`
/// (→ `EventMessageCard`) et `linkPreviewData` (→ `LinkPreviewBubble`). Aucun
/// nouveau champ n'a donc à traverser modèle, sources de données et
/// dépôt pour qu'un groupe ou un profil s'affiche en carte.
class ChatShareContent {
  const ChatShareContent({
    required this.message,
    required this.previewTitle,
    this.previewSubtitle,
    this.previewImageUrl,
    this.previewIcon,
    this.postData,
    this.eventData,
    this.productData,
    this.linkPreviewData,
  });

  /// Texte du message envoyé.
  final String message;

  final String previewTitle;
  final String? previewSubtitle;
  final String? previewImageUrl;
  final IconData? previewIcon;

  final Map<String, dynamic>? postData;
  final Map<String, dynamic>? eventData;
  final Map<String, dynamic>? productData;
  final Map<String, dynamic>? linkPreviewData;

  /// Publication du fil : garde la carte de post existante.
  factory ChatShareContent.post({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
    String? mediaUrl,
    required String message,
  }) {
    final preview =
        content.length > 100 ? '${content.substring(0, 100)}…' : content;
    return ChatShareContent(
      message: message,
      previewTitle: authorName,
      previewSubtitle: preview,
      previewImageUrl: mediaUrl,
      previewIcon: Icons.dynamic_feed_rounded,
      postData: {
        'postId': postId,
        'authorId': authorId,
        'authorName': authorName,
        'content': preview,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
      },
    );
  }

  /// Événement : garde la carte d'événement existante.
  factory ChatShareContent.event({
    required String eventId,
    required String title,
    required DateTime startDate,
    String? location,
    bool isOnline = false,
    String? imageUrl,
    required String message,
  }) {
    return ChatShareContent(
      message: message,
      previewTitle: title,
      previewSubtitle: isOnline ? null : location,
      previewImageUrl: imageUrl,
      previewIcon: Icons.event_rounded,
      eventData: {
        'eventId': eventId,
        'title': title,
        'startDate': startDate.toUtc().toIso8601String(),
        'location': location,
        'isOnline': isOnline,
      },
    );
  }

  /// Annonce de la marketplace : garde la carte produit existante.
  factory ChatShareContent.product({
    required String productId,
    required String title,
    required double price,
    required String currency,
    String? imageUrl,
    String? sellerId,
    String? sellerName,
    required String message,
  }) {
    return ChatShareContent(
      message: message,
      previewTitle: title,
      previewSubtitle: sellerName,
      previewImageUrl: imageUrl,
      previewIcon: Icons.storefront_rounded,
      productData: {
        'id': productId,
        'title': title,
        'price': price,
        'currency': currency,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (sellerId != null) 'sellerId': sellerId,
        if (sellerName != null) 'sellerName': sellerName,
      },
    );
  }

  /// Tout ce qui s'ouvre par un lien profond : groupe, profil, salon audio,
  /// podcast, épisode.
  factory ChatShareContent.link({
    required String url,
    required String title,
    required String message,
    String? description,
    String? imageUrl,
    IconData? icon,
  }) {
    return ChatShareContent(
      message: message,
      previewTitle: title,
      previewSubtitle: description,
      previewImageUrl: imageUrl,
      previewIcon: icon,
      linkPreviewData: {
        'url': url,
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'siteName': 'Diaspo Niger',
      },
    );
  }
}

/// Feuille « Envoyer dans une discussion » : le point d'entrée unique du
/// partage interne, pour les groupes comme pour les 1:1.
class ShareToChatSheet {
  const ShareToChatSheet._();

  /// Ouvre le sélecteur de discussions. Retourne `true` si au moins un envoi
  /// a réussi.
  static Future<bool?> show(
    BuildContext context, {
    required ChatShareContent content,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // Le conteneur est capturé maintenant : l'envoi ne doit dépendre d'aucun
    // `context` encore monté quand la feuille se referme.
    final container = ProviderScope.containerOf(context, listen: false);

    return ConversationPickerSheet.show(
      context,
      title: l10n.shareToChatTitle,
      preview: _ChatSharePreview(content: content),
      leading: Icon(Icons.forum_rounded, color: context.adaptivePrimaryColor),
      onSend: (targets) => _sendToAll(container, targets, content),
    );
  }

  static Future<int> _sendToAll(
    ProviderContainer container,
    List<ConversationEntity> targets,
    ChatShareContent content,
  ) async {
    final notifier = container.read(sendMessageProvider.notifier);

    var successCount = 0;
    for (final target in targets) {
      final sent = await notifier.sendText(
        conversationId: target.id,
        content: content.message,
        postData: content.postData,
        eventData: content.eventData,
        productData: content.productData,
        linkPreviewData: content.linkPreviewData,
      );
      if (sent) successCount++;
    }
    return successCount;
  }
}

/// Aperçu de ce qui part, en tête de la feuille.
class _ChatSharePreview extends StatelessWidget {
  const _ChatSharePreview({required this.content});

  final ChatShareContent content;

  @override
  Widget build(BuildContext context) {
    final imageUrl = content.previewImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final subtitle = content.previewSubtitle;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                hasImage
                    ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _fallbackIcon(context),
                      placeholder: (_, __) => _fallbackIcon(context),
                    )
                    : _fallbackIcon(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content.previewTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      color: context.adaptivePrimaryColor.withValues(alpha: 0.15),
      child: Icon(
        content.previewIcon ?? Icons.link_rounded,
        color: context.adaptivePrimaryColor,
        size: 22,
      ),
    );
  }
}
