import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Service pour gérer les liens dynamiques et le partage social
class DeepLinkService {
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._();

  DeepLinkService._();

  // Base URL pour les liens dynamiques
  static const String _baseUrl = 'https://diasponiger.page.link';
  static const String _webFallbackUrl = 'https://diasponiger.com';

  // ==================== Génération de liens ====================

  /// Génère un lien de partage pour un profil utilisateur
  String generateProfileLink(String userId, {String? userName}) {
    final path = '/p/u/$userId';
    return _buildDynamicLink(
      path: path,
      title: userName != null ? 'Profil de $userName' : 'Voir ce profil',
      description: 'Découvrez ce membre de la communauté Diaspo Niger',
      socialMetaTagInfo: SocialMetaTagInfo(
        title: userName ?? 'Membre Diaspo Niger',
        description: 'Rejoignez la communauté nigérienne à travers le monde',
      ),
    );
  }

  /// Génère un lien de partage pour un groupe
  String generateGroupLink(
    String groupId, {
    String? groupName,
    String? imageUrl,
  }) {
    final path = '/groups/$groupId';
    return _buildDynamicLink(
      path: path,
      title: groupName ?? 'Rejoindre ce groupe',
      description: 'Rejoignez ce groupe sur Diaspo Niger',
      imageUrl: imageUrl,
      socialMetaTagInfo: SocialMetaTagInfo(
        title: groupName ?? 'Groupe Diaspo Niger',
        description: 'Rejoignez la communauté',
        imageUrl: imageUrl,
      ),
    );
  }

  /// Génère un lien de partage pour un événement
  String generateEventLink(
    String eventId, {
    String? eventTitle,
    String? imageUrl,
    DateTime? date,
  }) {
    final path = '/events/$eventId';
    final dateStr = date != null
        ? ' - ${date.day}/${date.month}/${date.year}'
        : '';
    return _buildDynamicLink(
      path: path,
      title: eventTitle ?? 'Événement Diaspo Niger',
      description: 'Découvrez cet événement$dateStr',
      imageUrl: imageUrl,
      socialMetaTagInfo: SocialMetaTagInfo(
        title: eventTitle ?? 'Événement',
        description: 'Participez à cet événement de la communauté',
        imageUrl: imageUrl,
      ),
    );
  }

  /// Génère un lien de partage pour une entreprise
  String generateBusinessLink(
    String businessId, {
    String? businessName,
    String? category,
    String? imageUrl,
  }) {
    final path = '/businesses/$businessId';
    return _buildDynamicLink(
      path: path,
      title: businessName ?? 'Entreprise Diaspo Niger',
      description: category != null
          ? 'Découvrez cette entreprise - $category'
          : 'Découvrez cette entreprise de la communauté',
      imageUrl: imageUrl,
      socialMetaTagInfo: SocialMetaTagInfo(
        title: businessName ?? 'Entreprise',
        description: category ?? 'Annuaire des entreprises nigériennes',
        imageUrl: imageUrl,
      ),
    );
  }

  /// Génère un lien de partage pour un produit
  String generateProductLink(
    String productId, {
    String? productName,
    double? price,
    String? imageUrl,
  }) {
    final path = '/marketplace/$productId';
    final priceStr = price != null ? ' - ${price.toStringAsFixed(0)} FCFA' : '';
    return _buildDynamicLink(
      path: path,
      title: productName ?? 'Produit Marketplace',
      description: 'Découvrez ce produit$priceStr',
      imageUrl: imageUrl,
      socialMetaTagInfo: SocialMetaTagInfo(
        title: productName ?? 'Produit',
        description: 'Marketplace Diaspo Niger',
        imageUrl: imageUrl,
      ),
    );
  }

  /// Génère un lien d'invitation à rejoindre l'app
  String generateInviteLink({String? referrerId}) {
    var path = '/invite';
    if (referrerId != null) {
      path += '?ref=$referrerId';
    }
    return _buildDynamicLink(
      path: path,
      title: 'Rejoignez Diaspo Niger',
      description: 'La communauté nigérienne à travers le monde',
      socialMetaTagInfo: SocialMetaTagInfo(
        title: 'Diaspo Niger',
        description: 'Connectez-vous avec la diaspora nigérienne',
      ),
    );
  }

  // ==================== Construction des liens ====================

  String _buildDynamicLink({
    required String path,
    required String title,
    required String description,
    String? imageUrl,
    SocialMetaTagInfo? socialMetaTagInfo,
  }) {
    // Construire l'URL de base avec le path
    final deepLink = '$_webFallbackUrl$path';

    // Encoder les paramètres pour le lien dynamique
    final encodedLink = Uri.encodeComponent(deepLink);
    final encodedTitle = Uri.encodeComponent(socialMetaTagInfo?.title ?? title);
    final encodedDesc = Uri.encodeComponent(socialMetaTagInfo?.description ?? description);

    // Construire le lien Firebase Dynamic Links
    var dynamicLink = '$_baseUrl/?link=$encodedLink';
    dynamicLink += '&apn=com.diasponiger.app'; // Android package name
    dynamicLink += '&ibi=com.diasponiger.app'; // iOS bundle ID
    dynamicLink += '&st=$encodedTitle'; // Social title
    dynamicLink += '&sd=$encodedDesc'; // Social description

    if (imageUrl != null && imageUrl.isNotEmpty) {
      dynamicLink += '&si=${Uri.encodeComponent(imageUrl)}';
    }

    // Fallback vers le web si l'app n'est pas installée
    dynamicLink += '&ofl=$_webFallbackUrl';

    return dynamicLink;
  }

  // ==================== Partage ====================

  /// Partage un lien avec le texte par défaut
  Future<void> shareLink({
    required String link,
    required String title,
    String? text,
  }) async {
    try {
      final shareText = text ?? title;
      await Share.share(
        '$shareText\n\n$link',
        subject: title,
      );
    } catch (e) {
      debugPrint('DeepLinkService: Error sharing link: $e');
    }
  }

  /// Partage un profil
  Future<void> shareProfile({
    required String userId,
    required String userName,
  }) async {
    final link = generateProfileLink(userId, userName: userName);
    await shareLink(
      link: link,
      title: 'Profil de $userName',
      text: 'Découvrez le profil de $userName sur Diaspo Niger',
    );
  }

  /// Partage un groupe
  Future<void> shareGroup({
    required String groupId,
    required String groupName,
    String? imageUrl,
  }) async {
    final link = generateGroupLink(groupId, groupName: groupName, imageUrl: imageUrl);
    await shareLink(
      link: link,
      title: groupName,
      text: 'Rejoignez le groupe "$groupName" sur Diaspo Niger',
    );
  }

  /// Partage un événement
  Future<void> shareEvent({
    required String eventId,
    required String eventTitle,
    DateTime? date,
    String? imageUrl,
  }) async {
    final link = generateEventLink(
      eventId,
      eventTitle: eventTitle,
      date: date,
      imageUrl: imageUrl,
    );
    final dateStr = date != null
        ? ' le ${date.day}/${date.month}/${date.year}'
        : '';
    await shareLink(
      link: link,
      title: eventTitle,
      text: 'Participez à "$eventTitle"$dateStr sur Diaspo Niger',
    );
  }

  /// Partage une entreprise
  Future<void> shareBusiness({
    required String businessId,
    required String businessName,
    String? category,
    String? imageUrl,
  }) async {
    final link = generateBusinessLink(
      businessId,
      businessName: businessName,
      category: category,
      imageUrl: imageUrl,
    );
    await shareLink(
      link: link,
      title: businessName,
      text: 'Découvrez "$businessName" sur Diaspo Niger',
    );
  }

  /// Partage un produit
  Future<void> shareProduct({
    required String productId,
    required String productName,
    double? price,
    String? imageUrl,
  }) async {
    final link = generateProductLink(
      productId,
      productName: productName,
      price: price,
      imageUrl: imageUrl,
    );
    final priceStr = price != null ? ' à ${price.toStringAsFixed(0)} FCFA' : '';
    await shareLink(
      link: link,
      title: productName,
      text: 'Découvrez "$productName"$priceStr sur Diaspo Niger',
    );
  }

  /// Invite un ami à rejoindre l'app
  Future<void> shareInvite({String? referrerId}) async {
    final link = generateInviteLink(referrerId: referrerId);
    await shareLink(
      link: link,
      title: 'Rejoignez Diaspo Niger',
      text: 'Rejoignez-moi sur Diaspo Niger, la communauté nigérienne à travers le monde !',
    );
  }

  // ==================== Parsing des liens ====================

  /// Parse un lien dynamique et retourne les informations de navigation
  DeepLinkInfo? parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      // Vérifier si c'est un lien dynamique
      if (uri.host.contains('diasponiger')) {
        final link = uri.queryParameters['link'];
        if (link != null) {
          return _parseLink(Uri.parse(Uri.decodeComponent(link)));
        }
        return _parseLink(uri);
      }

      return null;
    } catch (e) {
      debugPrint('DeepLinkService: Error parsing deep link: $e');
      return null;
    }
  }

  DeepLinkInfo? _parseLink(Uri uri) {
    final path = uri.path;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) return null;

    switch (segments[0]) {
      case 'p':
        if (segments.length >= 3 && segments[1] == 'u') {
          return DeepLinkInfo(
            type: DeepLinkType.profile,
            id: segments[2],
          );
        }
        break;

      case 'profile':
        if (segments.length >= 2) {
          return DeepLinkInfo(
            type: DeepLinkType.profile,
            id: segments[1],
          );
        }
        break;

      case 'groups':
        if (segments.length >= 2) {
          return DeepLinkInfo(
            type: DeepLinkType.group,
            id: segments[1],
          );
        }
        break;

      case 'events':
        if (segments.length >= 2) {
          return DeepLinkInfo(
            type: DeepLinkType.event,
            id: segments[1],
          );
        }
        break;

      case 'businesses':
        if (segments.length >= 2) {
          return DeepLinkInfo(
            type: DeepLinkType.business,
            id: segments[1],
          );
        }
        break;

      case 'marketplace':
        if (segments.length >= 2) {
          return DeepLinkInfo(
            type: DeepLinkType.product,
            id: segments[1],
          );
        }
        break;

      case 'invite':
        return DeepLinkInfo(
          type: DeepLinkType.invite,
          id: uri.queryParameters['ref'],
        );
    }

    return null;
  }
}

/// Informations sur les meta tags sociaux
class SocialMetaTagInfo {
  final String title;
  final String description;
  final String? imageUrl;

  SocialMetaTagInfo({
    required this.title,
    required this.description,
    this.imageUrl,
  });
}

/// Type de lien profond
enum DeepLinkType {
  profile,
  group,
  event,
  business,
  product,
  invite,
}

/// Informations extraites d'un lien profond
class DeepLinkInfo {
  final DeepLinkType type;
  final String? id;
  final Map<String, String>? additionalParams;

  DeepLinkInfo({
    required this.type,
    this.id,
    this.additionalParams,
  });

  /// Retourne la route GoRouter correspondante
  String get routePath {
    switch (type) {
      case DeepLinkType.profile:
        return '/profile/$id';
      case DeepLinkType.group:
        return '/groups/$id';
      case DeepLinkType.event:
        return '/events/$id';
      case DeepLinkType.business:
        return '/businesses/$id';
      case DeepLinkType.product:
        return '/marketplace/$id';
      case DeepLinkType.invite:
        return '/home';
    }
  }
}
