import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../domain/entities/post_draft.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/feed_empty_state.dart';
import '../widgets/my_post_card.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';

// Provider for user's own posts
final myPostsProvider =
    FutureProvider.autoDispose<List<PostEntity>>((ref) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return const [];
  final repo = ref.read(feedRepositoryProvider);
  final result = await repo.getUserPosts(currentUserId);
  return result.fold((_) => const [], (posts) => posts);
});

final userPostsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return 0;
  final repo = ref.read(feedRepositoryProvider);
  final result = await repo.getUserPosts(currentUserId);
  return result.fold((_) => 0, (posts) => posts.length);
});

class MyPostsScreen extends ConsumerStatefulWidget {
  /// Onglet ouvert à l'arrivée : 0 = Publications, 1 = Repartages. « Mes
  /// repartages » de Mon espace (5a) pointe directement sur le second.
  final int initialTab;

  const MyPostsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends ConsumerState<MyPostsScreen> {
  late int _tab = widget.initialTab;

  /// Recherche de l'en-tête : filtre local sur la liste déjà chargée (la
  /// fiche 5b ne maquette que l'icône, sans écran de résultats dédié).
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    final postsAsync = ref.watch(myPostsProvider);
    final repostsAsync = ref.watch(myRepostsProvider);
    final drafts = ref.watch(postDraftsProvider);
    final postsCount = postsAsync.valueOrNull?.length ?? 0;
    final repostsCount = repostsAsync.valueOrNull?.length ?? 0;

    // Rien nulle part : pas de loupe, il n'y a rien à filtrer.
    final isBlank = postsCount == 0 && repostsCount == 0 && drafts.isEmpty;
    // Le FAB accompagne l'invitation de §5g, donc exactement quand elle est
    // affichée — y compris si l'onglet Repartages, lui, n'est pas vide.
    final showFab =
        _tab == 0 &&
        postsCount == 0 &&
        drafts.isEmpty &&
        _query.isEmpty &&
        postsAsync.hasValue;

    return Scaffold(
      backgroundColor: tokens.bg,
      floatingActionButton:
          showFab
              ? FloatingActionButton(
                onPressed: () => context.push('/feed/create'),
                backgroundColor: tokens.fabBg,
                foregroundColor: tokens.fabFg,
                elevation: 0,
                shape:
                    tokens.fabBorder != null
                        ? CircleBorder(
                          side: BorderSide(color: tokens.fabBorder!, width: 1.5),
                        )
                        : const CircleBorder(),
                child: const Icon(Icons.edit_rounded, size: 26),
              )
              : null,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              tokens: tokens,
              showSearch: !isBlank,
              searchOpen: _searchOpen,
              controller: _searchController,
              onToggleSearch: () {
                setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) {
                    _searchController.clear();
                    _query = '';
                  }
                });
              },
              onQueryChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _Tabs(
                tokens: tokens,
                selected: _tab,
                labels: [
                  'Publications · $postsCount',
                  'Repartages · $repostsCount',
                ],
                onChanged: (v) => setState(() => _tab = v),
              ),
            ),
            Expanded(
              child:
                  _tab == 0
                      ? _buildPostsTab(l10n, postsAsync, drafts)
                      : _buildRepostsTab(l10n, repostsAsync),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Onglet Publications : les posts publiés, puis les brouillons locaux
  // -------------------------------------------------------------------------

  Widget _buildPostsTab(
    AppLocalizations l10n,
    AsyncValue<List<PostEntity>> async,
    List<PostDraft> drafts,
  ) {
    return async.when(
      loading: () => const PostCardListSkeleton(),
      error:
          (_, __) => FeedEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.feedError,
            body: l10n.myPostsEmptyBody,
            ctaLabel: l10n.retry,
            ctaIcon: Icons.refresh_rounded,
            onCta: () => ref.invalidate(myPostsProvider),
          ),
      data: (posts) {
        final visiblePosts = posts.where((p) => _matches(p.content)).toList();
        final visibleDrafts = drafts.where((d) => _matches(d.text)).toList();

        if (visiblePosts.isEmpty && visibleDrafts.isEmpty) {
          // Une recherche infructueuse n'est pas un compte vide : garder
          // l'invitation à publier de §5g ici serait un contresens.
          return _query.isNotEmpty
              ? FeedEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Aucun résultat',
                body: 'Aucune publication ne contient « $_query ».',
                ctaLabel: 'Effacer la recherche',
                ctaIcon: Icons.close_rounded,
                onCta: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              )
              : const _FirstPostInvitation();
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPostsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: visiblePosts.length + visibleDrafts.length,
            itemBuilder: (context, index) {
              if (index < visiblePosts.length) {
                final post = visiblePosts[index];
                return MyPostCard(
                  post: post,
                  onEdit: () => context.push('/feed/${post.id}/edit', extra: post),
                  onMore: () => _showPostMenu(post),
                );
              }
              final draft = visibleDrafts[index - visiblePosts.length];
              return MyDraftCard(
                draft: draft,
                onResume: () => context.push('/feed/create?draft=${draft.id}'),
                onDelete: () => _confirmDeleteDraft(draft),
              );
            },
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Onglet Repartages : des posts d'autrui — la carte du fil, pas la carte
  // « à soi » (ni « Modifier » ni suppression n'auraient de sens ici).
  // -------------------------------------------------------------------------

  Widget _buildRepostsTab(
    AppLocalizations l10n,
    AsyncValue<List<PostEntity>> async,
  ) {
    return async.when(
      loading: () => const PostCardListSkeleton(),
      error:
          (_, __) => FeedEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.repostsError,
            body: l10n.repostsEmptyBody,
            ctaLabel: l10n.retry,
            ctaIcon: Icons.refresh_rounded,
            onCta: () => ref.invalidate(myRepostsProvider),
          ),
      data: (posts) {
        final visible = posts.where((p) => _matches(p.content)).toList();
        if (visible.isEmpty) {
          return FeedEmptyState(
            icon: Icons.repeat_rounded,
            title: _query.isNotEmpty ? 'Aucun résultat' : l10n.repostsEmptyTitle,
            body:
                _query.isNotEmpty
                    ? 'Aucun repartage ne contient « $_query ».'
                    : l10n.repostsEmptyBody,
            ctaLabel: l10n.exploreFeed,
            ctaIcon: Icons.explore_outlined,
            onCta: () => context.push('/feed'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myRepostsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visible.length,
            itemBuilder: (context, index) => PostCard(post: visible[index]),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Menus et confirmations
  // -------------------------------------------------------------------------

  /// Menu « ⋯ » d'une publication. La fiche évoque « épingler » et « changer
  /// l'audience » : ni l'un ni l'autre n'existe au modèle, le menu se limite
  /// donc à ce qui est réellement branché.
  Future<void> _showPostMenu(PostEntity post) async {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    final isBookmarked = ref
        .read(feedNotifierProvider)
        .bookmarkedPostIds
        .contains(post.id);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    color: isBookmarked ? tokens.accent : tokens.text,
                  ),
                  title: Text(
                    isBookmarked ? 'Retirer le signet' : 'Enregistrer',
                    style: FeedText.body(tokens, size: 15),
                  ),
                  onTap: () => Navigator.pop(ctx, 'bookmark'),
                ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: tokens.text),
                  title: Text(
                    l10n.editPost,
                    style: FeedText.body(tokens, size: 15),
                  ),
                  onTap: () => Navigator.pop(ctx, 'edit'),
                ),
                ListTile(
                  leading: const AppIcon(AppIcon.delete, color: Colors.red),
                  title: Text(
                    l10n.deletePost,
                    style: FeedText.body(
                      tokens,
                      size: 15,
                    ).copyWith(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              ],
            ),
          ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'bookmark':
        ref.read(feedNotifierProvider.notifier).toggleBookmark(post.id);
      case 'edit':
        context.push('/feed/${post.id}/edit', extra: post);
      case 'delete':
        await _confirmDeletePost(post, l10n);
    }
  }

  Future<void> _confirmDeletePost(
    PostEntity post,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deletePost),
            content: Text(l10n.confirmDeletePost),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(feedNotifierProvider.notifier).deletePost(post.id);
    if (mounted) ref.invalidate(myPostsProvider);
  }

  /// La maquette supprime le brouillon sans confirmation ; la fiche note
  /// elle-même qu'il en manque une. Un brouillon n'est nulle part ailleurs.
  Future<void> _confirmDeleteDraft(PostDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer le brouillon ?'),
            content: const Text(
              'Ce texte n\'a jamais été publié et ne pourra pas être récupéré.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(postDraftsProvider.notifier).delete(draft.id);
  }
}

// ---------------------------------------------------------------------------
// État vide « Votre première publication » (fiche 5g)
// ---------------------------------------------------------------------------

class _FirstPostInvitation extends StatelessWidget {
  const _FirstPostInvitation();

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    final pill = BorderRadius.circular(tokens.isDark ? tokens.radiusMd : 14);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.surface,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.edit_note_rounded,
              size: 44,
              color: tokens.accent,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Votre première publication',
            textAlign: TextAlign.center,
            style: FeedText.heading(tokens, size: 21).copyWith(height: 1.25),
          ),
          const SizedBox(height: 10),
          Text(
            'Une photo du pays, une question pratique, une annonce pour la '
            'communauté — commencez simplement.',
            textAlign: TextAlign.center,
            style: FeedText.body(
              tokens,
              size: 14.5,
              color: tokens.actionLabel,
            ).copyWith(height: 1.6),
          ),
          const SizedBox(height: 20),
          _Starter(
            tokens: tokens,
            radius: pill,
            icon: AppIcon.image,
            iconColor: tokens.accent,
            label: 'Partager une photo',
            onTap: () => context.push('/feed/create?compose=photo'),
          ),
          const SizedBox(height: 8),
          _Starter(
            tokens: tokens,
            radius: pill,
            icon: AppIcon.poll,
            iconColor: tokens.accent2,
            label: 'Lancer un sondage',
            onTap: () => context.push('/feed/create?compose=poll'),
          ),
          const SizedBox(height: 22),
          Material(
            color: tokens.accent,
            borderRadius: pill,
            child: InkWell(
              borderRadius: pill,
              onTap: () => context.push('/feed/create'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
                child: Text(
                  'Écrire une publication',
                  style: FeedText.body(
                    tokens,
                    size: 14,
                    weight: FontWeight.w600,
                    color: tokens.onAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Starter extends StatelessWidget {
  final FeedTokens tokens;
  final BorderRadius radius;
  final String icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _Starter({
    required this.tokens,
    required this.radius,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              AppIcon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: FeedText.body(
                    tokens,
                    size: 13.5,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: tokens.actionMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// En-tête et onglets (fiche 5b)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final FeedTokens tokens;
  final bool showSearch;
  final bool searchOpen;
  final TextEditingController controller;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onQueryChanged;

  const _Header({
    required this.tokens,
    required this.showSearch,
    required this.searchOpen,
    required this.controller,
    required this.onToggleSearch,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  () =>
                      context.canPop() ? context.pop() : context.go('/feed/space'),
              child: SizedBox(
                height: 52,
                width: 24,
                child: Center(
                  child: AppIcon(
                    AppIcon.arrowBack,
                    size: 24,
                    color: tokens.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child:
                  searchOpen
                      ? TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: onQueryChanged,
                        style: FeedText.body(tokens, size: 15),
                        cursorColor: tokens.accent,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Rechercher dans mes publications',
                          hintStyle: FeedText.body(
                            tokens,
                            size: 15,
                            color: tokens.mutedText,
                          ),
                        ),
                      )
                      : Text(
                        'Mes publications',
                        style: FeedText.heading(tokens, size: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
            ),
            if (showSearch) ...[
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleSearch,
                child: SizedBox(
                  height: 52,
                  width: 24,
                  child: Center(
                    child:
                        searchOpen
                            ? Icon(Icons.close, size: 22, color: tokens.text)
                            : AppIcon(
                              AppIcon.search,
                              size: 22,
                              color: tokens.text,
                            ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Onglets pleins de la fiche 5b : deux pastilles de largeur égale, l'active
/// remplie à l'accent. Distinct de [FeedSegmentedControl] (pilule à contour
/// avec icônes) que le reste du fil utilise.
class _Tabs extends StatelessWidget {
  final FeedTokens tokens;
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Tabs({
    required this.tokens,
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tokens.isDark ? tokens.radiusMd : 13);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Material(
              color: selected == i ? tokens.segmentActiveBg : tokens.surface,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border:
                        selected == i && tokens.segmentActiveBorder != null
                            ? Border.all(color: tokens.segmentActiveBorder!)
                            : null,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FeedText.body(
                      tokens,
                      size: 13,
                      weight:
                          selected == i ? FontWeight.w600 : FontWeight.w500,
                      color:
                          selected == i
                              ? tokens.segmentActiveFg
                              : tokens.actionLabel,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
