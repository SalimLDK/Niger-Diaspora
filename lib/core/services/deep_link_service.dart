import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_config.dart';

/// Service pour gérer les liens dynamiques et le partage social
class DeepLinkService {
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._();

  DeepLinkService._();

  // Base URL pour les liens (utilise Firebase Hosting)
  // Note: Firebase Dynamic Links est déprécié depuis août 2025
  static String get _baseUrl => AppConfig.deepLinkBaseUrl;

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

  /// Génère un lien de partage pour une publication du feed
  String generatePostLink(String postId, {String? authorName}) {
    final path = '/feed/$postId';
    return _buildDynamicLink(
      path: path,
      title: authorName != null
          ? 'Publication de $authorName'
          : 'Publication Diaspo Niger',
      description: 'Découvrez cette publication sur Diaspo Niger',
      socialMetaTagInfo: SocialMetaTagInfo(
        title: authorName ?? 'Diaspo Niger',
        description: 'Découvrez cette publication de la communauté',
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

  /// Genere un lien de partage pour un salon audio
  String generateAudioRoomLink(
    String roomId, {
    String? roomTitle,
    String? hostName,
    bool isLive = false,
  }) {
    final path = '/audio-rooms/$roomId';
    final statusText = isLive ? '🔴 EN DIRECT' : 'Salon audio';
    return _buildDynamicLink(
      path: path,
      title: roomTitle ?? 'Salon Audio Diaspo Niger',
      description: hostName != null
          ? '$statusText - Anime par $hostName'
          : statusText,
      socialMetaTagInfo: SocialMetaTagInfo(
        title: roomTitle ?? 'Salon Audio',
        description: 'Rejoignez ce salon audio sur Diaspo Niger',
      ),
    );
  }

  /// Génère un lien de partage pour un podcast
  String generatePodcastLink(
    String podcastId, {
    String? podcastTitle,
    String? hostName,
    String? imageUrl,
  }) {
    final path = '/podcasts/$podcastId';
    return _buildDynamicLink(
      path: path,
      title: podcastTitle ?? 'Podcast Diaspo Niger',
      description: hostName != null
          ? 'Podcast par $hostName'
          : 'Découvrez ce podcast sur Diaspo Niger',
      imageUrl: imageUrl,
      socialMetaTagInfo: SocialMetaTagInfo(
        title: podcastTitle ?? 'Podcast',
        description: 'Écoutez ce podcast sur Diaspo Niger',
        imageUrl: imageUrl,
      ),
    );
  }

  /// Génère un lien de partage pour un épisode de podcast
  String generateEpisodeLink(
    String episodeId, {
    String? episodeTitle,
    String? podcastTitle,
    String? imageUrl,
    Duration? duration,
  }) {
    final path = '/podcasts/episodes/$episodeId';
    final durationStr = duration != null
        ? ' - ${duration.inMinutes} min'
        : '';
    return _buildDynamicLink(
      path: path,
      title: episodeTitle ?? 'Épisode Diaspo Niger',
      description: podcastTitle != null
          ? '$podcastTitle$durationStr'
          : 'Écoutez cet épisode$durationStr',
      imageUrl: imageUrl,
      socialMetaTagInfo: SocialMetaTagInfo(
        title: episodeTitle ?? 'Épisode',
        description: podcastTitle ?? 'Podcast Diaspo Niger',
        imageUrl: imageUrl,
      ),
    );
  }

  /// Génère un lien de partage pour un appel (rejoindre un appel de groupe)
  String generateCallLink(
    String callId, {
    String? callerName,
    bool isVideo = false,
  }) {
    final path = '/calls/$callId';
    final callType = isVideo ? 'Appel vidéo' : 'Appel audio';
    return _buildDynamicLink(
      path: path,
      title: callerName != null ? '$callType avec $callerName' : callType,
      description: 'Rejoignez cet appel sur Diaspo Niger',
      socialMetaTagInfo: SocialMetaTagInfo(
        title: callType,
        description: 'Rejoignez cet appel',
      ),
    );
  }

  /// Génère un lien d'invitation à rejoindre l'app.
  ///
  /// Pointe la page de téléchargement du site, et non un chemin d'app, parce
  /// que ce lien cible par définition quelqu'un qui **n'a pas** encore
  /// l'application : un lien profond ne lui sert à rien. L'ancien `/invite`
  /// n'avait d'ailleurs aucune route côté GoRouter — mesuré le 2026-09-09,
  /// il atterrissait sur l'accueil et le `ref` était perdu en silence.
  ///
  /// `/telecharger` est réécrit vers `telecharger.html` par `firebase.json`,
  /// sur les deux sites. Sur un téléphone qui a déjà l'app, App Links
  /// revendique tout l'hôte : le lien ouvre donc l'app, que la route
  /// `/telecharger` renvoie sur l'accueil — le bon résultat pour quelqu'un
  /// qui l'a déjà.
  ///
  /// `?ref=` est conservé tel quel : rien ne le lit encore, mais il traverse
  /// le web comme l'app et attend un backend de parrainage.
  String generateInviteLink({String? referrerId}) {
    var path = '/telecharger';
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
    // Construire directement l'URL avec le path
    // Note: Firebase Dynamic Links est déprécié, on utilise des liens directs
    // L'app gère ces liens via App Links (Android) / Universal Links (iOS)
    return '$_baseUrl$path';
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
      await SharePlus.instance.share(
        ShareParams(
          text: '$shareText\n\n$link',
          subject: title,
        ),
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

  /// Partage un salon audio
  Future<void> shareAudioRoom({
    required String roomId,
    required String roomTitle,
    String? hostName,
    bool isLive = false,
  }) async {
    final link = generateAudioRoomLink(
      roomId,
      roomTitle: roomTitle,
      hostName: hostName,
      isLive: isLive,
    );
    final statusText = isLive ? '🔴 EN DIRECT: ' : '';
    await shareLink(
      link: link,
      title: roomTitle,
      text: '$statusText"$roomTitle" sur Diaspo Niger',
    );
  }

  /// Partage un podcast
  Future<void> sharePodcast({
    required String podcastId,
    required String podcastTitle,
    String? hostName,
    String? imageUrl,
  }) async {
    final link = generatePodcastLink(
      podcastId,
      podcastTitle: podcastTitle,
      hostName: hostName,
      imageUrl: imageUrl,
    );
    await shareLink(
      link: link,
      title: podcastTitle,
      text: 'Écoutez "$podcastTitle" sur Diaspo Niger',
    );
  }

  /// Partage un épisode de podcast
  Future<void> shareEpisode({
    required String episodeId,
    required String episodeTitle,
    String? podcastTitle,
    String? imageUrl,
    Duration? duration,
  }) async {
    final link = generateEpisodeLink(
      episodeId,
      episodeTitle: episodeTitle,
      podcastTitle: podcastTitle,
      imageUrl: imageUrl,
      duration: duration,
    );
    final podcastText = podcastTitle != null ? ' du podcast "$podcastTitle"' : '';
    await shareLink(
      link: link,
      title: episodeTitle,
      text: 'Écoutez "$episodeTitle"$podcastText sur Diaspo Niger',
    );
  }

  /// Partage un lien d'appel
  Future<void> shareCall({
    required String callId,
    String? callerName,
    bool isVideo = false,
  }) async {
    final link = generateCallLink(
      callId,
      callerName: callerName,
      isVideo: isVideo,
    );
    final callType = isVideo ? 'appel vidéo' : 'appel audio';
    await shareLink(
      link: link,
      title: 'Rejoindre l\'appel',
      text: 'Rejoignez cet $callType sur Diaspo Niger',
    );
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
