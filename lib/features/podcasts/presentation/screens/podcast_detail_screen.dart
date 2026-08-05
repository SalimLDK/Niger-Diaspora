import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/revenue_cat_provider.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/services/revenue_cat_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/podcast_entity.dart';
import '../providers/podcast_provider.dart';
import '../widgets/episode_tile.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Screen displaying podcast details and episodes
/// Ordre d'affichage des épisodes. `autoDispose` : le tri n'a pas à survivre
/// à la sortie de l'écran.
final _newestFirstProvider =
    StateProvider.autoDispose<bool>((ref) => true);

class PodcastDetailScreen extends ConsumerWidget {
  final String podcastId;

  const PodcastDetailScreen({
    super.key,
    required this.podcastId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final podcastAsync = ref.watch(podcastStreamProvider(podcastId));
    final episodesAsync = ref.watch(podcastEpisodesProvider(podcastId));
    final newestFirst = ref.watch(_newestFirstProvider);
    final isSubscribed = ref.watch(isSubscribedProvider(podcastId));
    // Premium access is now managed by RevenueCat entitlements (unified across
    // App Store, Play Store, and RevenueCat Billing / Stripe web).
    final hasPremiumAccess = ref.watch(hasPodcastPremiumProvider);

    return Scaffold(
      body: podcastAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            ErrorHandler.instance.getShortMessage(
              ErrorHandler.instance.handleException(e),
            ),
          ),
        ),
        data: (podcast) {
          if (podcast == null) {
            return Center(child: Text(l10n.podcastsNotFound));
          }

          return CustomScrollView(
            slivers: [
              // App bar with cover
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  IconButton(
                    icon: AppIcon(AppIcon.share, color: context.dn.onSurface2),
                    onPressed: () {
                      DeepLinkService.instance.sharePodcast(
                        podcastId: podcastId,
                        podcastTitle: podcast.title,
                        hostName: podcast.hostName,
                        imageUrl: podcast.coverImageUrl,
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: podcast.coverImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[300],
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child: AppIcon(AppIcon.podcasts, color: context.dn.onSurface2, size: 64),
                        ),
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      // Podcast info
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              podcast.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.podcastsBy(podcast.hostName),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Podcast info section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats row
                      Row(
                        children: [
                          _buildStat(
                            Icons.people,
                            l10n.podcastsSubscribers(podcast.subscriberCount),
                            '',
                          ),
                          const SizedBox(width: 24),
                          _buildStat(
                            Icons.playlist_play,
                            l10n.podcastsEpisodes(podcast.totalEpisodes),
                            '',
                          ),
                          const SizedBox(width: 24),
                          _buildStat(
                            Icons.play_circle,
                            l10n.podcastsPlays(podcast.totalPlayCount),
                            '',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Subscribe button
                      _buildSubscribeButton(
                        context: context,
                        ref: ref,
                        l10n: l10n,
                        podcast: podcast,
                        isSubscribed: isSubscribed,
                        hasPremiumAccess: hasPremiumAccess,
                      ),
                      const SizedBox(height: 16),
                      // Description
                      if (podcast.description != null) ...[
                        Text(
                          l10n.podcastsAbout,
                          style: DNText.serif(size: 17, color: context.dn.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          podcast.description!,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Tags
                      if (podcast.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: podcast.tags.map((tag) {
                            return Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Episodes header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.podcastsEpisodes(podcast.totalEpisodes),
                            style: DNText.serif(size: 20, color: context.dn.onSurface),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Tri (maquette 3b) : l'en-tête ne proposait
                              // que « Ajouter », une action de créateur, à
                              // l'endroit où l'auditeur cherche à s'orienter.
                              TextButton.icon(
                                onPressed: () => ref
                                    .read(_newestFirstProvider.notifier)
                                    .state = !newestFirst,
                                icon: Icon(
                                  newestFirst
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  newestFirst
                                      ? l10n.podcastsSortRecent
                                      : l10n.podcastsSortOldest,
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.podcastsAdd,
                                onPressed: () => context.push(
                                  '/podcasts/$podcastId/record',
                                ),
                                icon: AppIcon(AppIcon.add,
                                    color: context.dn.onSurface2,),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Episodes list
              episodesAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      ErrorHandler.instance.getShortMessage(
                        ErrorHandler.instance.handleException(e),
                      ),
                    ),
                  ),
                ),
                data: (all) {
                  // Tri explicite : l'ordre de la source n'est pas garanti,
                  // et le bouton doit avoir un effet visible.
                  final episodes = [...all]..sort((a, b) {
                      final da = a.publishedAt ?? a.createdAt;
                      final db = b.publishedAt ?? b.createdAt;
                      return newestFirst ? db.compareTo(da) : da.compareTo(db);
                    });
                  if (episodes.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.mic_off,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.podcastsNoEpisodes,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final episode = episodes[index];
                          return EpisodeTile(
                            episode: episode,
                          );
                        },
                        childCount: episodes.length,
                      ),
                    ),
                  );
                },
              ),
              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubscribeButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppLocalizations l10n,
    required PodcastEntity podcast,
    required bool isSubscribed,
    required bool hasPremiumAccess,
  }) {
    // Already subscribed (free follow)
    if (isSubscribed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => ref
              .read(podcastNotifierProvider.notifier)
              .unsubscribe(podcast.id),
          icon: const Icon(Icons.notifications_active),
          label: Text(l10n.podcastsSubscribed),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.black,
          ),
        ),
      );
    }

    // Premium podcast — no entitlement yet → offer RevenueCat purchase
    if (podcast.isPremium && podcast.premiumPrice != null && !hasPremiumAccess) {
      final price = podcast.premiumPrice! / 100;
      final currency = (podcast.premiumCurrency ?? 'EUR').toUpperCase();
      return _PremiumSubscribeButton(
        podcast: podcast,
        priceLabel: '${price.toStringAsFixed(2)} $currency/mois',
      );
    }

    // Free podcast
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => ref
            .read(podcastNotifierProvider.notifier)
            .subscribe(podcast),
        icon: const Icon(Icons.notifications_none),
        label: Text(l10n.podcastsSubscribe),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  /// Builds a stat display with icon and value.
  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

/// Button handling premium podcast subscription.
/// Tries RevenueCat (App Store / Play Store) first, falls back to Stripe.
/// All purchase logic stays in providers — no purchases_flutter import needed here.
class _PremiumSubscribeButton extends ConsumerStatefulWidget {
  final PodcastEntity podcast;
  final String priceLabel;

  const _PremiumSubscribeButton({
    required this.podcast,
    required this.priceLabel,
  });

  @override
  ConsumerState<_PremiumSubscribeButton> createState() =>
      _PremiumSubscribeButtonState();
}

class _PremiumSubscribeButtonState
    extends ConsumerState<_PremiumSubscribeButton> {
  String? _storePrice;
  bool _storeAvailable = false;
  bool _loadingStore = true;

  @override
  void initState() {
    super.initState();
    _loadStorePrice();
  }

  Future<void> _loadStorePrice() async {
    final label = await ref
        .read(purchaseNotifierProvider.notifier)
        .getOfferingPriceLabel(RCOffering.podcastOffering);
    if (mounted) {
      setState(() {
        _storePrice = label;
        _storeAvailable = label != null;
        _loadingStore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseState = ref.watch(purchaseNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main subscribe button
        ElevatedButton.icon(
          onPressed: _loadingStore || purchaseState.isLoading
              ? null
              : () => _handleSubscribe(context),
          icon: _loadingStore || purchaseState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(_storeAvailable ? Icons.star : Icons.credit_card),
          label: Text(
            'S\'abonner • ${_storeAvailable ? _storePrice! : widget.priceLabel}',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
          ),
        ),

        if (purchaseState.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              purchaseState.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

        // Restore purchases (required by App Store guidelines)
        if (_storeAvailable)
          TextButton(
            onPressed: () async {
              final ok = await ref
                  .read(purchaseNotifierProvider.notifier)
                  .restore();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Achats restaurés.' : 'Aucun achat à restaurer.',
                    ),
                  ),
                );
                if (ok) ref.invalidate(customerInfoProvider);
              }
            },
            child: const Text(
              'Restaurer mes achats',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _handleSubscribe(BuildContext context) async {
    if (_storeAvailable) {
      // App Store / Play Store via RevenueCat
      final ok = await ref
          .read(purchaseNotifierProvider.notifier)
          .purchaseOffering(RCOffering.podcastOffering);
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.subscriptionActivated),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh RevenueCat entitlements so the UI updates immediately
        ref.invalidate(customerInfoProvider);
      }
    }
  }
}
