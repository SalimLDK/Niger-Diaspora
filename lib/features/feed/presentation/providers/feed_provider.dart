import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../data/models/post_model.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../data/datasources/feed_remote_datasource.dart';
import '../../data/datasources/feed_supabase_datasource.dart';
import '../../data/repositories/feed_repository_impl.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_draft.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/repositories/feed_repository.dart';
import 'feed_personalization_provider.dart';
import 'feed_scorer.dart';

// ============================================================================
// Infrastructure providers
// ============================================================================

final feedDataSourceProvider = Provider<FeedRemoteDataSource>((ref) {
  return FeedSupabaseDataSource();
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepositoryImpl(ref.watch(feedDataSourceProvider));
});

// ============================================================================
// Feed state
// ============================================================================

class FeedState {
  final List<PostEntity> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int lastOffset;
  final String? error;
  final String? hashtagFilter;
  final FeedMode mode;
  final Set<String> likedPostIds;
  final Set<String> bookmarkedPostIds;
  final Set<String> repostedPostIds;

  /// Posts arrivés en temps réel, pas encore affichés (backe la pill « N nouveaux »).
  final List<PostEntity> pendingPosts;

  /// Nature de l'échec, quand il y en a un. `error` porte le message brut ;
  /// ce champ dit lequel des cas de la maquette 2b afficher.
  final FeedFailure? failure;

  /// Publications dont l'envoi a échoué, conservées pour être relancées.
  final List<PostEntity> failedPosts;

  /// Les posts affichés viennent du cache local, pas du réseau.
  final bool isFromCache;

  /// Quand cette page de cache a été reçue (null si les posts sont frais).
  final DateTime? cachedAt;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastOffset = 0,
    this.error,
    this.hashtagFilter,
    this.mode = FeedMode.forYou,
    this.likedPostIds = const {},
    this.bookmarkedPostIds = const {},
    this.repostedPostIds = const {},
    this.pendingPosts = const [],
    this.failure,
    this.failedPosts = const [],
    this.isFromCache = false,
    this.cachedAt,
  });

  FeedState copyWith({
    List<PostEntity>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? lastOffset,
    String? error,
    String? hashtagFilter,
    FeedMode? mode,
    Set<String>? likedPostIds,
    Set<String>? bookmarkedPostIds,
    Set<String>? repostedPostIds,
    List<PostEntity>? pendingPosts,
    FeedFailure? failure,
    List<PostEntity>? failedPosts,
    bool? isFromCache,
    DateTime? cachedAt,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastOffset: lastOffset ?? this.lastOffset,
      error: error,
      hashtagFilter: hashtagFilter ?? this.hashtagFilter,
      mode: mode ?? this.mode,
      likedPostIds: likedPostIds ?? this.likedPostIds,
      bookmarkedPostIds: bookmarkedPostIds ?? this.bookmarkedPostIds,
      repostedPostIds: repostedPostIds ?? this.repostedPostIds,
      pendingPosts: pendingPosts ?? this.pendingPosts,
      // Même convention que `error` : ces trois champs décrivent le dernier
      // chargement, ils ne doivent pas survivre au suivant.
      failure: failure,
      // Les publications ratées, elles, survivent aux rechargements : c'est
      // du contenu de l'utilisateur, pas un état de requête.
      failedPosts: failedPosts ?? this.failedPosts,
      isFromCache: isFromCache ?? false,
      cachedAt: cachedAt,
    );
  }
}

/// Les quatre échecs de la maquette 2b, distingués parce qu'ils n'appellent
/// pas la même réaction : sans réseau on propose le cache, sur une panne
/// serveur on fait patienter, sur un réseau lent on n'a rien à réparer.
enum FeedFailure {
  /// Aucune connectivité détectée.
  noConnection,

  /// Le serveur a répondu une erreur (5xx, indisponibilité).
  serverDown,

  /// La requête a expiré alors que la connectivité est présente.
  slowNetwork,

  /// Autre erreur non classée.
  unknown,
}

// ============================================================================
// Feed notifier
// ============================================================================

class FeedNotifier extends Notifier<FeedState> {
  static const int _pageSize = 30;

  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  Future<FeedScorer?> get _scorer async {
    try {
      return await ref
          .read(feedScorerProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Personnalisation optionnelle : le feed s'affiche non trie en cas
      // d'echec ou de lenteur (profil/follows indisponibles, timeout...).
      return null;
    }
  }

  @override
  FeedState build() {
    Future.microtask(loadInitial);
    // Temps réel : nouveaux posts (pill) + patch des compteurs des cartes visibles.
    final newSub = _repo.watchNewPosts().listen(_onNewPost);
    final updSub = _repo.watchPostUpdates().listen(_onPostUpdate);
    ref.onDispose(() {
      newSub.cancel();
      updSub.cancel();
    });
    return const FeedState(isLoading: true);
  }

  /// Bufferise un nouveau post arrivé en temps réel (alimente la pill).
  void _onNewPost(PostEntity post) {
    // Realtime seulement sur le feed non filtré et hors mode Following (MVP).
    if (state.hashtagFilter != null || state.mode == FeedMode.following) return;
    final exists = state.posts.any((p) => p.id == post.id) ||
        state.pendingPosts.any((p) => p.id == post.id);
    if (exists) return; // évite le doublon avec l'insert optimiste de createPost
    state = state.copyWith(pendingPosts: [post, ...state.pendingPosts]);
  }

  /// Patch des compteurs autoritaires (like/comment/share) sur une carte visible.
  void _onPostUpdate(PostEntity post) {
    state = state.copyWith(
      posts: state.posts
          .map(
            (p) => p.id == post.id
                ? p.copyWith(
                    likeCount: post.likeCount,
                    commentCount: post.commentCount,
                    shareCount: post.shareCount,
                  )
                : p,
          )
          .toList(),
    );
  }

  /// Affiche les posts bufferisés en tête de feed et vide la pill.
  void showPendingPosts() {
    if (state.pendingPosts.isEmpty) return;
    state = state.copyWith(
      posts: [...state.pendingPosts, ...state.posts],
      pendingPosts: const [],
    );
  }

  Future<void> setMode(FeedMode mode) async {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode, posts: [], lastOffset: 0, hasMore: true);
    await loadInitial();
  }

  Future<void> loadInitial({String? hashtagFilter}) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      hashtagFilter: hashtagFilter ?? state.hashtagFilter,
    );
    final filter = hashtagFilter ?? state.hashtagFilter;

    // Le cache d'abord. L'écran ne montre ses squelettes que tant que `posts`
    // est vide : en le remplissant tout de suite, un utilisateur hors ligne
    // voit son fil immédiatement au lieu d'attendre l'expiration du réseau.
    // La requête continue derrière et remplacera ces posts si elle aboutit.
    if (state.posts.isEmpty) _showCachedIfAny(filter);

    final PaginatedPosts? paginated;
    final String? message;
    try {
      final result = await _repo
          .getFeedPaginated(
            limit: _pageSize,
            hashtagFilter: filter,
            mode: state.mode,
          )
          // Sans borne, un réseau qui *pend* au lieu d'échouer (mode avion,
          // portail captif, TURN injoignable) ne rend jamais la main : le
          // repli sur le cache n'était alors jamais atteint et le fil restait
          // sur ses squelettes indéfiniment.
          .timeout(_networkTimeout);
      // Extraction synchrone : pas de closure async passee a fold (sinon une
      // exception dans le travail async serait avalee et isLoading resterait true).
      paginated = result.fold((_) => null, (p) => p);
      message = result.fold((failure) => failure.message, (_) => null);
    } on TimeoutException {
      await _handleLoadFailure('timeout', filter);
      return;
    }
    if (paginated == null) {
      await _handleLoadFailure(message, filter);
      return;
    }
    try {
      var posts = paginated.posts;
      if (state.mode == FeedMode.forYou) {
        final scorer = await _scorer;
        if (scorer != null) posts = scorer.sorted(posts);
      }
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      Set<String> likedIds = const {};
      Set<String> bookmarkIds = const {};
      Set<String> repostIds = const {};
      if (userId.isNotEmpty && posts.isNotEmpty) {
        final ids = posts.map((p) => p.id).toList();
        // Bornés eux aussi : un de ces appels qui pend retenait le fil en
        // chargement alors que les publications étaient déjà là. En cas
        // d'expiration, le `catch` ci-dessous affiche les posts sans ces états.
        final likedResult =
            await _repo.getLikedPostIds(ids, userId).timeout(_enrichTimeout);
        likedIds = likedResult.fold((_) => const {}, (ids) => ids);
        final bookmarkResult =
            await _repo.getBookmarkedPostIds(userId).timeout(_enrichTimeout);
        bookmarkIds = bookmarkResult.fold((_) => const {}, (ids) => ids);
        final repostResult =
            await _repo.getRepostedPostIds(userId).timeout(_enrichTimeout);
        repostIds = repostResult.fold((_) => const {}, (ids) => ids);
      }
      // `isFromCache` / `cachedAt` se réinitialisent d'eux-mêmes dans copyWith
      // (convention « état du dernier chargement ») : le bandeau « hors ligne »
      // posé par _showCachedIfAny disparaît donc ici.
      state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: paginated.hasMore,
        lastOffset: paginated.lastOffset,
        likedPostIds: likedIds,
        bookmarkedPostIds: bookmarkIds,
        repostedPostIds: repostIds,
        pendingPosts: const [], // la pill « N nouveaux » se réinitialise au refresh
      );
      // On garde la page telle qu'elle a été reçue (avant tri personnalisé,
      // qui dépend d'un profil pas forcément disponible hors ligne).
      unawaited(_cacheFeed(paginated.posts, filter));
    } catch (_) {
      // Garantit que le chargement se termine : on affiche les posts bruts.
      state = state.copyWith(
        posts: paginated.posts,
        isLoading: false,
        hasMore: paginated.hasMore,
        lastOffset: paginated.lastOffset,
      );
    }
  }

  /// Au-delà, on considère le réseau perdu et on bascule sur le cache.
  static const _networkTimeout = Duration(seconds: 10);

  /// Likes, favoris et repartages ne sont qu'un enrichissement : ils ne doivent
  /// jamais retenir l'affichage des publications déjà reçues.
  static const _enrichTimeout = Duration(seconds: 5);

  /// Affiche la dernière page mise en cache, si elle existe. Utilisé avant même
  /// d'interroger le réseau (cf. [loadInitial]) et en cas d'échec.
  ///
  /// Ne touche pas à `isLoading` : la requête réseau est toujours en cours et
  /// c'est elle qui terminera le chargement.
  void _showCachedIfAny(String? filter) {
    final (cached, cachedAt) = _readCache(filter);
    if (cached.isEmpty) return;
    state = state.copyWith(
      posts: cached,
      isFromCache: true,
      cachedAt: cachedAt,
      hasMore: false, // pas de pagination sur du cache
    );
  }

  /// Dernière page mise en cache, ou une liste vide si elle est absente ou
  /// illisible. Le cache est un confort : son échec ne doit rien casser.
  (List<PostEntity>, DateTime?) _readCache(String? filter) {
    try {
      final key = _cacheKey(filter);
      final raw = CacheService.instance.getCachedFeed(key);
      if (raw.isEmpty) return (const [], null);
      return (
        raw.map((j) => PostModel.fromJson(j).toEntity()).toList(),
        CacheService.instance.getFeedCachedAt(key),
      );
    } catch (e) {
      debugPrint('FeedNotifier: lecture du cache impossible: $e');
      return (const [], null);
    }
  }

  String _cacheKey(String? hashtagFilter) =>
      CacheService.feedKey(mode: state.mode.name, hashtagFilter: hashtagFilter);

  Future<void> _cacheFeed(List<PostEntity> posts, String? filter) async {
    try {
      await CacheService.instance.cacheFeed(
        _cacheKey(filter),
        posts.map((p) => PostModel.fromEntity(p).toJson()).toList(),
      );
    } catch (e) {
      // Le cache est un confort : son échec ne doit jamais casser le fil.
      debugPrint('FeedNotifier: mise en cache impossible: $e');
    }
  }

  /// Un chargement raté n'est plus un écran d'erreur unique : on classe la
  /// cause (maquette 2b) et, si une page est en cache, on l'affiche plutôt
  /// que de laisser l'utilisateur devant un fil vide (maquette 2a).
  Future<void> _handleLoadFailure(String? message, String? filter) async {
    final failure = _classifyFailure(message);

    final (cached, cachedAt) = _readCache(filter);

    state = state.copyWith(
      isLoading: false,
      error: message,
      failure: failure,
      posts: cached.isNotEmpty ? cached : state.posts,
      isFromCache: cached.isNotEmpty,
      cachedAt: cached.isNotEmpty ? cachedAt : null,
      // Pas de pagination sur du cache : on n'a que la première page.
      hasMore: cached.isNotEmpty ? false : state.hasMore,
    );
  }

  FeedFailure _classifyFailure(String? message) {
    if (!ref.read(connectivityNotifierProvider)) return FeedFailure.noConnection;
    if (message == null) return FeedFailure.unknown;
    final m = message.toLowerCase();
    if (m.contains('timeout') || m.contains('timed out') ||
        m.contains('deadline')) {
      return FeedFailure.slowNetwork;
    }
    if (m.contains('socket') ||
        m.contains('failed host lookup') ||
        m.contains('network is unreachable')) {
      return FeedFailure.noConnection;
    }
    if (m.contains('50') && m.contains('server') ||
        m.contains('service unavailable') ||
        m.contains('bad gateway') ||
        m.contains('internal server')) {
      return FeedFailure.serverDown;
    }
    return FeedFailure.unknown;
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    final PaginatedPosts? paginated;
    try {
      final result = await _repo
          .getFeedPaginated(
            limit: _pageSize,
            offset: state.lastOffset,
            hashtagFilter: state.hashtagFilter,
            mode: state.mode,
          )
          // Même borne que loadInitial : sans elle, un réseau qui pend laissait
          // le spinner de pagination tourner sans fin.
          .timeout(_networkTimeout);
      // Extraction synchrone : pas de closure async passee a fold.
      paginated = result.fold((_) => null, (p) => p);
    } on TimeoutException {
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    if (paginated == null) {
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    try {
      var newPosts = paginated.posts;
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final mergedLikedIds = Set<String>.from(state.likedPostIds);
      final mergedBookmarkIds = Set<String>.from(state.bookmarkedPostIds);
      if (userId.isNotEmpty && newPosts.isNotEmpty) {
        final likedResult = await _repo
            .getLikedPostIds(newPosts.map((p) => p.id).toList(), userId)
            .timeout(_enrichTimeout);
        likedResult.fold((_) => null, (ids) => mergedLikedIds.addAll(ids));
      }
      if (state.mode == FeedMode.forYou) {
        final scorer = await _scorer;
        if (scorer != null) {
          // Re-sort the combined list so newly fetched posts land in the right position
          newPosts = scorer.sorted([...state.posts, ...newPosts]);
          state = state.copyWith(
            posts: newPosts,
            isLoadingMore: false,
            hasMore: paginated.hasMore,
            lastOffset: paginated.lastOffset,
            likedPostIds: mergedLikedIds,
            bookmarkedPostIds: mergedBookmarkIds,
          );
          return;
        }
      }
      state = state.copyWith(
        posts: [...state.posts, ...paginated.posts],
        isLoadingMore: false,
        hasMore: paginated.hasMore,
        lastOffset: paginated.lastOffset,
        likedPostIds: mergedLikedIds,
        bookmarkedPostIds: mergedBookmarkIds,
      );
    } catch (_) {
      // Garantit la fin du chargement : on ajoute les posts bruts.
      state = state.copyWith(
        posts: [...state.posts, ...paginated.posts],
        isLoadingMore: false,
        hasMore: paginated.hasMore,
        lastOffset: paginated.lastOffset,
      );
    }
  }

  Future<void> refresh() => loadInitial();

  /// Renvoie le post créé (avec son vrai id) ou `null` en cas d'échec.
  /// Nécessaire pour rattacher un sondage/lieu composé avant publication
  /// (`create_post_screen.dart`), dont le contextId n'existe qu'après coup.
  Future<PostEntity?> createPost(PostEntity post) async {
    final result = await _repo.createPost(post);
    return result.fold(
      (failure) {
        // Maquette 2b, cas 4 : la publication ratée ne disparaît plus dans un
        // SnackBar. Elle reste en tête du fil, signalée, avec de quoi la
        // relancer ou l'abandonner — le texte saisi n'est jamais perdu.
        state = state.copyWith(failedPosts: [post, ...state.failedPosts]);
        return null;
      },
      (created) {
        state = state.copyWith(posts: [created, ...state.posts]);
        return created;
      },
    );
  }

  /// Relance une publication échouée. En cas de nouvel échec elle reste dans
  /// la liste (remise en tête par `createPost`).
  Future<bool> retryFailedPost(PostEntity post) async {
    state = state.copyWith(
      failedPosts: state.failedPosts.where((p) => p != post).toList(),
    );
    final created = await createPost(post);
    return created != null;
  }

  /// Abandonne définitivement une publication échouée.
  void discardFailedPost(PostEntity post) {
    state = state.copyWith(
      failedPosts: state.failedPosts.where((p) => p != post).toList(),
    );
  }

  Future<bool> updatePost(PostEntity post) async {
    final result = await _repo.updatePost(post);
    return result.fold(
      (failure) => false,
      (updated) {
        state = state.copyWith(
          posts: state.posts
              .map((p) => p.id == updated.id ? updated : p)
              .toList(),
        );
        // Reflète l'édition dans l'écran de détail s'il est ouvert.
        ref.read(postDetailProvider(updated.id).notifier).setPost(updated);
        return true;
      },
    );
  }

  Future<bool> deletePost(String postId) async {
    final result = await _repo.deletePost(postId);
    return result.fold(
      (failure) => false,
      (_) {
        state = state.copyWith(
          posts: state.posts.where((p) => p.id != postId).toList(),
        );
        return true;
      },
    );
  }

  Future<void> toggleLike(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCurrentlyLiked = state.likedPostIds.contains(postId);
    final newLikedIds = Set<String>.from(state.likedPostIds);
    if (isCurrentlyLiked) {
      newLikedIds.remove(postId);
    } else {
      newLikedIds.add(postId);
    }
    state = state.copyWith(
      likedPostIds: newLikedIds,
      posts: state.posts.map((p) {
        if (p.id != postId) return p;
        final delta = isCurrentlyLiked ? -1 : 1;
        return p.copyWith(likeCount: (p.likeCount + delta).clamp(0, 999999));
      }).toList(),
    );
    await _repo.toggleLike(postId, userId);
    // Notifie l'auteur uniquement sur un nouveau like (jamais sur un dé-like).
    if (!isCurrentlyLiked) {
      final post = _findPost(postId);
      if (post != null) {
        await _notifyPostAuthor(
          post: post,
          type: 'postLiked',
          title: 'Nouveau j\'aime',
          body: '${_actorName()} a aimé votre publication',
        );
      }
    }
  }

  Future<void> toggleBookmark(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    final isCurrentlyBookmarked = state.bookmarkedPostIds.contains(postId);
    final newBookmarkIds = Set<String>.from(state.bookmarkedPostIds);
    if (isCurrentlyBookmarked) {
      newBookmarkIds.remove(postId);
    } else {
      newBookmarkIds.add(postId);
    }
    state = state.copyWith(bookmarkedPostIds: newBookmarkIds);
    await _repo.toggleBookmark(postId, userId);
  }

  /// Repartage simple (toggle) : ajoute ou retire le post de mes repartages.
  Future<void> toggleRepost(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    final isCurrentlyReposted = state.repostedPostIds.contains(postId);
    final newRepostIds = Set<String>.from(state.repostedPostIds);
    if (isCurrentlyReposted) {
      newRepostIds.remove(postId);
    } else {
      newRepostIds.add(postId);
    }
    state = state.copyWith(
      repostedPostIds: newRepostIds,
      posts: state.posts.map((p) {
        if (p.id != postId) return p;
        final delta = isCurrentlyReposted ? -1 : 1;
        return p.copyWith(shareCount: (p.shareCount + delta).clamp(0, 999999));
      }).toList(),
    );
    final result = await _repo.toggleRepost(postId, userId);
    final nowReposted = result.fold((_) => !isCurrentlyReposted, (v) => v);
    if (nowReposted && !isCurrentlyReposted) {
      final post = _findPost(postId);
      if (post != null) {
        await _notifyPostAuthor(
          post: post,
          type: 'postReposted',
          title: 'Nouveau repartage',
          body: '${_actorName()} a repartagé votre publication',
        );
      }
    }
  }

  /// Repartage avec citation : conserve le repartage et y attache un commentaire.
  Future<void> repostWithComment(String postId, String comment) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    final wasReposted = state.repostedPostIds.contains(postId);
    final newRepostIds = Set<String>.from(state.repostedPostIds)..add(postId);
    state = state.copyWith(
      repostedPostIds: newRepostIds,
      posts: state.posts.map((p) {
        if (p.id != postId || wasReposted) return p;
        return p.copyWith(shareCount: (p.shareCount + 1).clamp(0, 999999));
      }).toList(),
    );
    final result = await _repo.repostWithComment(postId, userId, comment);
    final wasNew = result.fold((_) => !wasReposted, (v) => v);
    if (wasNew) {
      final post = _findPost(postId);
      if (post != null) {
        await _notifyPostAuthor(
          post: post,
          type: 'postReposted',
          title: 'Nouveau repartage',
          body: '${_actorName()} a repartagé votre publication',
        );
      }
    }
  }

  /// Partage externe (WhatsApp/Facebook/X/système) : analytics + compteur
  /// dédié, distinct du compteur de repartages. Fire-and-forget : les échecs
  /// ne doivent pas perturber le flux de partage.
  Future<void> trackExternalShare(String postId) async {
    try {
      await AnalyticsService.instance.logSocialAction(
        actionType: SocialActionType.share,
        targetType: 'post',
        targetId: postId,
      );
    } catch (_) {}
    await _repo.trackExternalShare(postId);
  }

  PostEntity? _findPost(String postId) {
    for (final p in state.posts) {
      if (p.id == postId) return p;
    }
    return null;
  }

  String _actorName() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName;
    if (name != null && name.trim().isNotEmpty) return name;
    return 'Quelqu\'un';
  }

  /// Crée une notification d'engagement pour l'auteur d'un post (jamais pour
  /// soi-même). Réutilise le helper Supabase partagé [NotificationService].
  Future<void> _notifyPostAuthor({
    required PostEntity post,
    required String type,
    required String title,
    required String body,
  }) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || post.authorId.isEmpty || post.authorId == me) return;
    await NotificationService().createNotification(
      userId: post.authorId,
      title: title,
      body: body,
      type: type,
      targetId: post.id,
      data: {'postId': post.id, 'senderId': me},
    );
  }
}

final feedNotifierProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

// ============================================================================
// Post detail notifier
// ============================================================================

class PostDetailNotifier extends FamilyNotifier<PostEntity?, String> {
  @override
  PostEntity? build(String postId) {
    _load(postId);
    // Temps réel : reflète les mises à jour (compteurs/édition) du post ouvert.
    final sub = ref
        .read(feedRepositoryProvider)
        .watchPostUpdates(postId: postId)
        .listen((p) => state = p);
    ref.onDispose(sub.cancel);
    return null;
  }

  Future<void> _load(String postId) async {
    final result = await ref.read(feedRepositoryProvider).getPostById(postId);
    result.fold((_) {}, (post) => state = post);
  }

  void refresh(String postId) => _load(postId);

  /// Remplace le post affiché (ex. après une édition) sans re-fetch.
  void setPost(PostEntity post) => state = post;
}

final postDetailProvider =
    NotifierProvider.family<PostDetailNotifier, PostEntity?, String>(
  PostDetailNotifier.new,
);

// ============================================================================
// Comments notifier
// ============================================================================

class CommentsState {
  /// Commentaires racines (chacun porte ses [CommentEntity.replies]).
  final List<CommentEntity> comments;
  final bool isLoading;
  final String? error;
  final Set<String> likedCommentIds;

  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
    this.likedCommentIds = const {},
  });

  CommentsState copyWith({
    List<CommentEntity>? comments,
    bool? isLoading,
    String? error,
    Set<String>? likedCommentIds,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      likedCommentIds: likedCommentIds ?? this.likedCommentIds,
    );
  }
}

class CommentsNotifier extends FamilyNotifier<CommentsState, String> {
  @override
  CommentsState build(String postId) {
    Future.microtask(() => _load(postId));
    // Temps réel : nouveaux commentaires (et réponses) ajoutés en direct.
    final sub = ref
        .read(feedRepositoryProvider)
        .watchNewComments(postId)
        .listen(_onNewComment);
    ref.onDispose(sub.cancel);
    return const CommentsState(isLoading: true);
  }

  void _onNewComment(CommentEntity c) {
    // Dédup vs l'ajout optimiste de l'auteur (racine ou réponse déjà présente).
    final exists = state.comments.any((x) => x.id == c.id) ||
        state.comments.any((x) => x.replies.any((r) => r.id == c.id));
    if (exists) return;
    if (c.parentCommentId != null) {
      final updated = state.comments.map((x) {
        if (x.id != c.parentCommentId) return x;
        final replies = [...x.replies, c];
        return x.copyWith(replies: replies, replyCount: replies.length);
      }).toList();
      state = state.copyWith(comments: updated);
    } else {
      state = state.copyWith(comments: [...state.comments, c]);
    }
  }

  Future<void> _load(String postId) async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(feedRepositoryProvider);
    final result = await repo.getComments(postId, limit: 100);
    await result.fold(
      (f) async => state = state.copyWith(isLoading: false, error: f.message),
      (all) async {
        final tree = _buildTree(all);
        var likedIds = const <String>{};
        final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (userId.isNotEmpty && all.isNotEmpty) {
          final likedResult = await repo.getLikedCommentIds(
            all.map((c) => c.id).toList(),
            userId,
          );
          likedIds = likedResult.fold((_) => const {}, (ids) => ids);
        }
        state = state.copyWith(
          comments: tree,
          isLoading: false,
          likedCommentIds: likedIds,
        );
      },
    );
  }

  /// Construit un arbre à 1 niveau : commentaires racines + leurs réponses.
  List<CommentEntity> _buildTree(List<CommentEntity> all) {
    final byParent = <String, List<CommentEntity>>{};
    for (final c in all.where((c) => c.parentCommentId != null)) {
      byParent.putIfAbsent(c.parentCommentId!, () => []).add(c);
    }
    return all.where((c) => c.parentCommentId == null).map((root) {
      final replies = byParent[root.id] ?? const <CommentEntity>[];
      return root.copyWith(replies: replies, replyCount: replies.length);
    }).toList();
  }

  Future<bool> addComment(String postId, CommentEntity comment) async {
    final result =
        await ref.read(feedRepositoryProvider).addComment(postId, comment);
    return result.fold(
      (_) => false,
      (created) {
        if (created.parentCommentId != null) {
          // Réponse : insérée dans les replies du parent.
          final updated = state.comments.map((c) {
            if (c.id != created.parentCommentId) return c;
            final replies = [...c.replies, created];
            return c.copyWith(replies: replies, replyCount: replies.length);
          }).toList();
          state = state.copyWith(comments: updated);
        } else {
          state = state.copyWith(comments: [...state.comments, created]);
        }
        _notifyOnComment(postId, created);
        return true;
      },
    );
  }

  /// Notifie la bonne personne après un commentaire : l'auteur du commentaire
  /// parent pour une réponse, sinon l'auteur du post. Jamais soi-même.
  void _notifyOnComment(String postId, CommentEntity created) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;
    if (created.parentCommentId != null) {
      CommentEntity? parent;
      for (final c in state.comments) {
        if (c.id == created.parentCommentId) {
          parent = c;
          break;
        }
      }
      final targetUser = parent?.authorId;
      if (targetUser != null && targetUser.isNotEmpty && targetUser != me) {
        NotificationService().createNotification(
          userId: targetUser,
          title: 'Nouvelle réponse',
          body: '${_actorDisplayName()} a répondu à votre commentaire',
          type: 'commentReply',
          targetId: postId,
          data: {'postId': postId, 'senderId': me},
        );
      }
    } else {
      final post = ref.read(postDetailProvider(postId));
      if (post != null && post.authorId.isNotEmpty && post.authorId != me) {
        NotificationService().createNotification(
          userId: post.authorId,
          title: 'Nouveau commentaire',
          body: '${_actorDisplayName()} a commenté votre publication',
          type: 'postCommented',
          targetId: postId,
          data: {'postId': postId, 'senderId': me},
        );
      }
    }
  }

  String _actorDisplayName() {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    if (name != null && name.trim().isNotEmpty) return name;
    return 'Quelqu\'un';
  }

  Future<void> toggleCommentLike(String commentId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    final liked = state.likedCommentIds.contains(commentId);
    final newLiked = Set<String>.from(state.likedCommentIds);
    if (liked) {
      newLiked.remove(commentId);
    } else {
      newLiked.add(commentId);
    }
    final delta = liked ? -1 : 1;
    CommentEntity bump(CommentEntity c) =>
        c.copyWith(likeCount: (c.likeCount + delta).clamp(0, 999999));
    final updated = state.comments.map((c) {
      if (c.id == commentId) return bump(c);
      if (c.replies.any((r) => r.id == commentId)) {
        return c.copyWith(
          replies:
              c.replies.map((r) => r.id == commentId ? bump(r) : r).toList(),
        );
      }
      return c;
    }).toList();
    state = state.copyWith(likedCommentIds: newLiked, comments: updated);
    await ref.read(feedRepositoryProvider).toggleCommentLike(commentId, userId);
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    final result = await ref
        .read(feedRepositoryProvider)
        .deleteComment(postId, commentId);
    return result.fold(
      (_) => false,
      (_) {
        final updated = <CommentEntity>[];
        for (final c in state.comments) {
          if (c.id == commentId) continue; // commentaire racine supprimé
          if (c.replies.any((r) => r.id == commentId)) {
            final replies = c.replies.where((r) => r.id != commentId).toList();
            updated.add(c.copyWith(replies: replies, replyCount: replies.length));
          } else {
            updated.add(c);
          }
        }
        state = state.copyWith(comments: updated);
        return true;
      },
    );
  }
}

final commentsProvider =
    NotifierProvider.family<CommentsNotifier, CommentsState, String>(
  CommentsNotifier.new,
);

// ============================================================================
// Follow provider
// ============================================================================

final isFollowingProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  final result =
      await ref.read(feedRepositoryProvider).isFollowing(targetUserId);
  return result.fold((_) => false, (v) => v);
});

/// IDs des comptes qui suivent [userId] (abonnés), du plus récent au plus ancien.
final followersProvider =
    FutureProvider.family<List<String>, String>((ref, userId) async {
  final result = await ref.read(feedRepositoryProvider).getFollowers(userId);
  return result.fold((_) => const <String>[], (ids) => ids);
});

/// IDs des comptes que [userId] suit (abonnements), du plus récent au plus ancien.
final followingProvider =
    FutureProvider.family<List<String>, String>((ref, userId) async {
  final result = await ref.read(feedRepositoryProvider).getFollowing(userId);
  return result.fold((_) => const <String>[], (ids) => ids);
});

/// Compteur d'abonnés de [userId] (réactif, invalidé avec [followersProvider]).
final followersCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final result = await ref.read(feedRepositoryProvider).getFollowersCount(userId);
  return result.fold((_) => 0, (v) => v);
});

/// Compteur d'abonnements de [userId].
final followingCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final result = await ref.read(feedRepositoryProvider).getFollowingCount(userId);
  return result.fold((_) => 0, (v) => v);
});

// ============================================================================
// Reposts (repartages)
// ============================================================================

/// Posts que l'utilisateur courant a repartagés (écran /profile/reposts).
final myRepostsProvider = FutureProvider<List<PostEntity>>((ref) async {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (userId.isEmpty) return const [];
  final result =
      await ref.read(feedRepositoryProvider).getRepostedPosts(userId);
  return result.fold((_) => const <PostEntity>[], (posts) => posts);
});

/// IDs des comptes ayant repartagé un post donné (écran /feed/:postId/reposts).
final repostersProvider =
    FutureProvider.family<List<String>, String>((ref, postId) async {
  final result = await ref.read(feedRepositoryProvider).getReposterIds(postId);
  return result.fold((_) => const <String>[], (ids) => ids);
});

/// Repartages récents des comptes que l'utilisateur suit, à injecter dans le
/// fil avec le bandeau « X a reposté ». Vide si l'utilisateur ne suit personne.
final feedRepostsProvider = FutureProvider<List<RepostFeedEntry>>((ref) async {
  final followingIds = await ref.watch(followingIdsProvider.future);
  if (followingIds.isEmpty) return const <RepostFeedEntry>[];
  final result = await ref.read(feedRepositoryProvider).getRepostFeedItems(
        reposterIds: followingIds.toList(),
        limit: 20,
      );
  return result.fold((_) => const <RepostFeedEntry>[], (items) => items);
});

// ============================================================================
// Brouillons de publication & hashtags suivis (carte « Mon espace », §5a)
//
// Stockage 100% local (SharedPreferences via PreferencesService) : aucun
// modèle serveur pour ni l'un ni l'autre, et un stockage mono-appareil suffit
// pour l'usage visé.
// ============================================================================

class PostDraftsNotifier extends Notifier<List<PostDraft>> {
  @override
  List<PostDraft> build() => _read();

  List<PostDraft> _read() => PreferencesService.instance.postDrafts
      .map(PostDraft.fromJson)
      .whereType<PostDraft>()
      .toList();

  PostDraft? byId(String id) {
    for (final draft in state) {
      if (draft.id == id) return draft;
    }
    return null;
  }

  /// Crée ou met à jour le brouillon [id] ; un texte vide le supprime.
  Future<void> save(String id, String text) async {
    await PreferencesService.instance.savePostDraft(id, text);
    state = _read();
  }

  Future<void> delete(String id) async {
    await PreferencesService.instance.deletePostDraft(id);
    state = _read();
  }
}

final postDraftsProvider =
    NotifierProvider<PostDraftsNotifier, List<PostDraft>>(
  PostDraftsNotifier.new,
);

class FollowedHashtagsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => PreferencesService.instance.followedHashtags;

  Future<void> toggle(String hashtag) async {
    await PreferencesService.instance.toggleFollowedHashtag(hashtag);
    state = PreferencesService.instance.followedHashtags;
  }

  Future<void> unfollow(String hashtag) async {
    await PreferencesService.instance.unfollowHashtag(hashtag);
    state = PreferencesService.instance.followedHashtags;
  }
}

final followedHashtagsProvider =
    NotifierProvider<FollowedHashtagsNotifier, List<String>>(
  FollowedHashtagsNotifier.new,
);
