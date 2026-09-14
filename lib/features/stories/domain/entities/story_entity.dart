import 'package:equatable/equatable.dart';

enum StoryMediaType { image, video }

/// Qui peut voir une story (`stories.audience`). C'est la base qui tranche
/// (`peut_voir_story`, migration 20260912230000) ; la liste « masqué »
/// ([StoryListKind.hidden]) et les blocages priment sur l'audience.
enum StoryAudience {
  /// Tout le monde.
  everyone('public'),

  /// Les personnes qui me suivent, et mes amis.
  followers('followers'),

  /// Mes amis seulement.
  friends('friends'),

  /// La liste restreinte ([StoryListKind.close]) seulement.
  closeList('close');

  const StoryAudience(this.dbValue);

  final String dbValue;

  static StoryAudience fromDb(String? value) => StoryAudience.values
      .firstWhere((a) => a.dbValue == value, orElse: () => StoryAudience.everyone);

  String get label => switch (this) {
        StoryAudience.everyone => 'Tout le monde',
        StoryAudience.followers => 'Abonnés et amis',
        StoryAudience.friends => 'Amis',
        StoryAudience.closeList => 'Liste restreinte',
      };
}

/// Les deux listes qu'un auteur tient sur ses stories.
enum StoryListKind {
  /// « Liste restreinte » : les seules personnes qui voient une story publiée
  /// pour [StoryAudience.closeList].
  close('close'),

  /// « Masquer ma story à » : ces personnes ne voient aucune story, quelle que
  /// soit l'audience — même « Tout le monde ».
  hidden('hidden');

  const StoryListKind(this.dbValue);

  final String dbValue;

  static StoryListKind? fromDb(String? value) {
    for (final k in StoryListKind.values) {
      if (k.dbValue == value) return k;
    }
    return null;
  }
}

/// Une personne rangée dans l'une des listes de l'auteur. Une personne est
/// dans une liste au plus (clé `(owner_id, member_id)` en base).
class StoryListMember extends Equatable {
  final String memberId;
  final StoryListKind kind;

  const StoryListMember({required this.memberId, required this.kind});

  @override
  List<Object?> get props => [memberId, kind];
}

/// Une story individuelle (§4, rail « À la une ») : un média, visible 24 h.
class StoryEntity extends Equatable {
  /// Durée de vie d'une story. La base applique la même borne
  /// (`stories_select`) ; l'app la réapplique pour qu'une story expire à
  /// l'écran sans attendre le prochain chargement.
  static const Duration lifetime = Duration(hours: 24);

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final int? videoDurationSeconds;
  final DateTime createdAt;
  final int viewCount;
  final bool isViewedByMe;
  final StoryAudience audience;

  const StoryEntity({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.mediaUrl,
    required this.mediaType,
    this.videoDurationSeconds,
    required this.createdAt,
    this.viewCount = 0,
    this.isViewedByMe = false,
    this.audience = StoryAudience.everyone,
  });

  DateTime get expiresAt => createdAt.add(lifetime);

  bool get isExpired => !DateTime.now().isBefore(expiresAt);

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        authorPhotoUrl,
        mediaUrl,
        mediaType,
        videoDurationSeconds,
        createdAt,
        viewCount,
        isViewedByMe,
        audience,
      ];
}

/// Un spectateur d'une story (§4 — liste « qui a vu », visible par l'auteur
/// uniquement, RLS déjà posée en ce sens sur `story_views`).
class StoryViewerEntity extends Equatable {
  final String viewerId;
  final DateTime viewedAt;

  const StoryViewerEntity({required this.viewerId, required this.viewedAt});

  @override
  List<Object?> get props => [viewerId, viewedAt];
}

/// Une réaction (emoji) sur une story (§4) — une par utilisateur et par
/// story, upsert au nouveau tap.
class StoryReactionEntity extends Equatable {
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const StoryReactionEntity({
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [userId, emoji, createdAt];
}

/// Stories actives d'un même auteur, groupées pour le rail et le viewer.
class AuthorStories extends Equatable {
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final List<StoryEntity> stories;

  const AuthorStories({
    required this.authorId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.stories,
  });

  bool get hasUnviewed => stories.any((s) => !s.isViewedByMe);

  @override
  List<Object?> get props => [authorId, authorName, authorPhotoUrl, stories];
}
