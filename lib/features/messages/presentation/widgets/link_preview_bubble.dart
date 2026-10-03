import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/link_preview_service.dart';
import '../../../../core/services/qr_code_parser.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Carte d'aperçu d'un lien.
///
/// **Tout ce qu'elle porte est écrit par l'expéditeur** : `linkPreviewData`
/// voyage dans le message, et rien n'oblige un client modifié à le remplir
/// depuis la vraie page. Une carte « Banque X » pouvait donc mener ailleurs
/// que le lien visible dans le texte, vers n'importe quel schéma (`intent:`,
/// `file:`…), et s'ouvrait au premier appui, sans la confirmation que les
/// liens du texte demandent. D'où trois règles :
///
///  * la carte n'est montrée que si son URL est un lien du texte lui-même
///    ([urlFiable]) — le lien qu'on lit est celui qu'on ouvre ;
///  * la ligne « où ça mène » affiche l'hôte calculé depuis l'URL, jamais le
///    `siteName` fourni ;
///  * un lien externe passe par [confirmerOuverture], la même boîte que les
///    liens du texte.
class LinkPreviewBubble extends StatelessWidget {
  final String? url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final bool isMe;

  /// Demandée avant d'ouvrir un lien hors de l'app. `true` pour ouvrir.
  final Future<bool?> Function(String url)? confirmerOuverture;

  const LinkPreviewBubble({
    super.key,
    this.url,
    this.title,
    this.description,
    this.imageUrl,
    required this.isMe,
    this.confirmerOuverture,
  });

  factory LinkPreviewBubble.fromMap(
    Map<String, dynamic> data, {
    required bool isMe,
    Future<bool?> Function(String url)? confirmerOuverture,
  }) {
    return LinkPreviewBubble(
      url: data['url'] as String?,
      title: data['title'] as String?,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      isMe: isMe,
      confirmerOuverture: confirmerOuverture,
    );
  }

  /// L'URL de la carte, si elle peut être montrée sous ce [texte] : un lien
  /// `http(s)` qui est l'un des liens du texte, sous la forme que l'envoi lui
  /// donne (`https://` ajouté quand le texte n'a pas de schéma). Sinon `null`,
  /// et la carte ne s'affiche pas — le texte, lui, reste.
  static String? urlFiable(Map<String, dynamic>? data, String texte) {
    final url = data?['url'];
    if (url is! String || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return null;
    }
    for (final lien in LinkPreviewService.extractAllUrls(texte)) {
      final normalise =
          lien.startsWith('http://') || lien.startsWith('https://')
              ? lien
              : 'https://$lien';
      if (normalise == url) return url;
    }
    return null;
  }

  /// L'hôte affiché sous la carte, sans `www.`.
  static String hote(String url) {
    final h = Uri.tryParse(url)?.host ?? '';
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();

    final cardBgColor = isMe
        ? Colors.black.withValues(alpha: 0.20)
        : context.isDarkMode
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.08);

    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.15)
        : context.isDarkMode
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.10);

    return GestureDetector(
      onTap: () => _open(context, url!),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview image with gradient overlay
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11.5),
                        topRight: Radius.circular(11.5),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 120,
                          color: isMe
                              ? Colors.black.withValues(alpha: 0.1)
                              : context.surfaceVariantColor,
                          child: Center(
                            child: AppIcon(AppIcon.image,
                              size: 32,
                              color: isMe
                                  ? AppColors.white.withValues(alpha: 0.4)
                                  : context.textTertiaryColor,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 80,
                          color: isMe
                              ? Colors.black.withValues(alpha: 0.1)
                              : context.surfaceVariantColor,
                          child: Center(
                            child: Icon(
                              Icons.link_off,
                              size: 28,
                              color: isMe
                                  ? AppColors.white.withValues(alpha: 0.4)
                                  : context.textTertiaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay at the bottom of the image
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              cardBgColor.withValues(alpha: 0),
                              cardBgColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Divider between image and text
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: borderColor,
              ),

            // Text content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  if (title != null && title!.isNotEmpty)
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isMe
                            ? AppColors.white
                            : context.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isMe
                            ? AppColors.white.withValues(alpha: 0.8)
                            : context.textSecondaryColor,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Où mène le lien : l'hôte réel, jamais le `siteName`
                  // fourni par l'expéditeur.
                  if (hote(url!).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link,
                          size: 14,
                          color: isMe
                              ? AppColors.white.withValues(alpha: 0.6)
                              : context.textTertiaryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            hote(url!),
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe
                                  ? AppColors.white.withValues(alpha: 0.6)
                                  : context.textTertiaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Un lien Diaspo Niger partagé dans une discussion (groupe, profil,
  /// événement…) doit ouvrir l'écran correspondant, pas le navigateur : le
  /// site web ne rend pas ces pages, l'utilisateur y tombait sur un 404.
  ///
  /// Même lecture que le scanner QR (`QrCodeParser`) : l'ancien parseur de
  /// `DeepLinkService` ignorait `/feed/`, `/embassies/`, `www.` et le schéma
  /// `diasponiger://`, qui repartaient donc vers Android.
  Future<void> _open(BuildContext context, String url) async {
    final route = QrCodeParser.routeInterne(url);
    if (route != null) {
      unawaited(context.push(route));
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return;
    }
    final confirmer = confirmerOuverture;
    if (confirmer != null && await confirmer(url) != true) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
