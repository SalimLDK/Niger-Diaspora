/// Lecture des QR fabriqués par le projet.
///
/// L'app affiche trois QR — profil (`share_profile_modal`), groupe
/// (`share_group_modal`) et rendez-vous de transfert de clés E2EE
/// (`key_transfer_send_screen`) — et son site partage les mêmes liens profonds
/// pour tout le reste (fil, événement, entreprise, produit, ambassade, salon,
/// podcast, épisode, appel). Le scanner de l'accueil doit tous les reconnaître.
///
/// Fichier volontairement sans dépendance Flutter : il est testable tel quel.
library;

/// Nature du QR lu.
enum QrCodeKind {
  /// Lien de profil complet : `/p/u/<userId>` ou `/profile/<userId>`.
  profile,

  /// Lien de profil raccourci : `/p/<code>`. L'identifiant doit être résolu
  /// côté serveur avant de pouvoir naviguer.
  profileShortCode,
  group,
  event,
  business,
  product,
  post,
  embassy,
  audioRoom,
  podcast,
  episode,
  call,

  /// Rendez-vous de transfert de clés E2EE (`dn-e2ee-transfer:…`), qui n'est
  /// pas une URL et se consomme sur l'écran de réception dédié.
  keyTransfer,
}

/// Ce qu'un QR du projet désigne, une fois lu.
class QrCodeTarget {
  const QrCodeTarget({required this.kind, this.routePath, this.shortCode});

  final QrCodeKind kind;

  /// Route GoRouter à ouvrir. `null` pour [QrCodeKind.profileShortCode] (il
  /// faut d'abord résoudre le code) et pour [QrCodeKind.keyTransfer].
  final String? routePath;

  /// Code court à résoudre, renseigné pour [QrCodeKind.profileShortCode].
  final String? shortCode;

  @override
  String toString() =>
      'QrCodeTarget($kind, routePath: $routePath, shortCode: $shortCode)';
}

/// Traduit le contenu brut d'un QR en cible applicative.
abstract final class QrCodeParser {
  /// Préfixe du rendez-vous de transfert de clés — voir `KeyTransferInvite`.
  /// Reconnu ici sans être décodé : le décodage et la revendication restent
  /// l'affaire de l'écran de réception.
  static const String keyTransferPrefix = 'dn-e2ee-transfer:';

  /// Hôtes reconnus comme étant ceux du projet.
  ///
  /// Comparaison **exacte** : un `contains` laisserait passer
  /// `diasponiger.com.exemple-piege.fr`. Toute nouvelle valeur de
  /// `DEEP_LINK_BASE_URL` (app_config.dart) doit être ajoutée ici, sinon le QR
  /// fabriqué par l'app ne sera pas reconnu par son propre scanner.
  static const Set<String> allowedHosts = {
    'diasponiger.web.app',
    'diaspo-niger.web.app',
    'diasponiger.com',
    'www.diasponiger.com',
  };

  /// Schéma propre à l'app, déclaré dans AndroidManifest.xml
  /// (`diasponiger://groups/<id>`).
  static const String appScheme = 'diasponiger';

  /// Rend `null` sur tout ce qui n'appartient pas au projet : QR d'un autre
  /// service, texte libre, lien vers un site tiers.
  static QrCodeTarget? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    if (value.startsWith(keyTransferPrefix)) {
      return const QrCodeTarget(kind: QrCodeKind.keyTransfer);
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final segments = _projectSegments(uri);
    if (segments == null || segments.isEmpty) return null;

    return _targetFor(segments);
  }

  /// Segments du chemin, uniquement si l'URI est bien celle du projet.
  ///
  /// Le schéma maison porte le premier segment dans l'hôte
  /// (`diasponiger://groups/<id>` → host `groups`), d'où la remise à plat.
  static List<String>? _projectSegments(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme == appScheme) {
      return [
        if (uri.host.isNotEmpty) uri.host,
        ...uri.pathSegments,
      ].where((s) => s.isNotEmpty).toList();
    }

    if (scheme != 'https' && scheme != 'http') return null;
    if (!allowedHosts.contains(uri.host.toLowerCase())) return null;

    return uri.pathSegments.where((s) => s.isNotEmpty).toList();
  }

  static QrCodeTarget? _targetFor(List<String> segments) {
    switch (segments[0]) {
      // `/p/u/<userId>` (lien long) contre `/p/<code>` (lien court) : le `u`
      // est ce qui les distingue, l'ordre du test compte donc.
      case 'p':
        if (segments.length >= 2 && segments[1] == 'u') {
          return _route(QrCodeKind.profile, '/profile', _idAt(segments, 2));
        }
        if (segments.length >= 2 && _isValidId(segments[1])) {
          return QrCodeTarget(
            kind: QrCodeKind.profileShortCode,
            shortCode: segments[1],
          );
        }
        return null;

      case 'profile':
        return _route(QrCodeKind.profile, '/profile', _idAt(segments, 1));

      // `/g/<id>` : raccourci historique vers un groupe.
      case 'groups':
      case 'g':
        return _route(QrCodeKind.group, '/groups', _idAt(segments, 1));

      case 'events':
        return _route(QrCodeKind.event, '/events', _idAt(segments, 1));

      case 'businesses':
        return _route(QrCodeKind.business, '/businesses', _idAt(segments, 1));

      case 'marketplace':
        return _route(QrCodeKind.product, '/marketplace', _idAt(segments, 1));

      case 'feed':
        return _route(QrCodeKind.post, '/feed', _idAt(segments, 1));

      case 'embassies':
        return _route(QrCodeKind.embassy, '/embassies', _idAt(segments, 1));

      case 'audio-rooms':
        return _route(QrCodeKind.audioRoom, '/audio-rooms', _idAt(segments, 1));

      case 'podcasts':
        // `/podcasts/episodes/<id>` avant `/podcasts/<id>`, sinon l'épisode
        // serait lu comme un podcast nommé « episodes ».
        if (segments.length >= 3 && segments[1] == 'episodes') {
          return _route(
            QrCodeKind.episode,
            '/podcasts/episodes',
            segments[2],
          );
        }
        return _route(QrCodeKind.podcast, '/podcasts', _idAt(segments, 1));

      case 'calls':
        return _route(QrCodeKind.call, '/calls', _idAt(segments, 1));
    }

    return null;
  }

  static String? _idAt(List<String> segments, int index) =>
      segments.length > index ? segments[index] : null;

  static QrCodeTarget? _route(QrCodeKind kind, String prefix, String? id) {
    if (id == null || !_isValidId(id)) return null;
    return QrCodeTarget(kind: kind, routePath: '$prefix/$id');
  }

  /// Identifiants acceptés : uuid Supabase, id Firestore hérité (20
  /// caractères), code court de partage. Le filtre écarte surtout les
  /// injections de chemin et les charges absurdes — un segment d'URI ne peut
  /// déjà pas contenir de `/`.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._~-]{1,128}$');

  static bool _isValidId(String id) => _idPattern.hasMatch(id);
}
