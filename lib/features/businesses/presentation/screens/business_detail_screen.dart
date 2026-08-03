import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_post_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/business_provider.dart';
import '../providers/review_provider.dart';
import '../widgets/review_card.dart';
import '../widgets/review_form_modal.dart';
import '../widgets/star_rating_input.dart';

class BusinessDetailScreen extends ConsumerStatefulWidget {
  final String businessId;
  final BusinessEntity? initialBusiness;

  const BusinessDetailScreen({
    super.key,
    required this.businessId,
    this.initialBusiness,
  });

  @override
  ConsumerState<BusinessDetailScreen> createState() =>
      _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends ConsumerState<BusinessDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(businessDetailNotifierProvider.notifier)
          .loadBusiness(widget.businessId);
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(businessDetailNotifierProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final theme = Theme.of(context);

    // Use initial business if available while loading
    final business = businessAsync.valueOrNull ?? widget.initialBusiness;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          if (context.mounted) {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        body: businessAsync.when(
          data:
              (loadedBusiness) => _buildContent(
                context,
                loadedBusiness ?? widget.initialBusiness!,
                currentUser?.id,
              ),
          loading:
              () =>
                  business != null
                      ? _buildContent(context, business, currentUser?.id)
                      : const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(
                      AppIcon.error,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error.toString(),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref
                            .read(businessDetailNotifierProvider.notifier)
                            .loadBusiness(widget.businessId);
                      },
                      child: const Text('Reessayer'),
                    ),
                  ],
                ),
              ),
        ),
      ), // Close PopScope child (Scaffold)
    ); // Close PopScope
  }

  Widget _buildContent(
    BuildContext context,
    BusinessEntity business,
    String? currentUserId,
  ) {
    final theme = Theme.of(context);
    final isOwner = currentUserId == business.ownerId;
    final hasImages = business.photoUrls.isNotEmpty;

    return CustomScrollView(
      slivers: [
        // App bar with image
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background:
                hasImages
                    ? CachedNetworkImage(
                      imageUrl: business.photoUrls.first,
                      fit: BoxFit.cover,
                      placeholder:
                          (_, __) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                      errorWidget:
                          (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(business.category.icon, size: 64),
                          ),
                    )
                    : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        business.category.icon,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                    ),
          ),
          actions: [
            if (isOwner)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.push(
                        '/businesses/${business.id}/edit',
                        extra: business,
                      );
                      break;
                    case 'boost':
                      context.push(
                        '/businesses/${business.id}/boost',
                        extra: business,
                      );
                      break;
                  }
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Modifier'),
                      ),
                      const PopupMenuItem(
                        value: 'boost',
                        child: Text('Booster'),
                      ),
                    ],
              ),
          ],
        ),
        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(business.category.icon, size: 16),
                          const SizedBox(width: 4),
                          Text(business.category.label),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (business.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Verifie',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    if (business.isBoosted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              AppIcon.star,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Premium',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Nom de l'entreprise (§17d) : serif à point terracotta,
                // sous la photo de couverture qui sert déjà d'en-tête.
                DesignTitle(business.name, size: 24),
                const SizedBox(height: 8),
                // Rating
                if (business.averageRating > 0)
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return AppIcon(
                          index < business.averageRating.round()
                              ? AppIcon.star
                              : AppIcon.starBorder,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '${business.averageRating.toStringAsFixed(1)} (${business.reviewCount} avis)',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                // Description
                Text(business.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                // Contact section
                Text(
                  'Contact',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (business.phone != null)
                  ListTile(
                    leading: const AppIcon(AppIcon.call),
                    title: Text(business.phone!),
                    onTap: () => _launchPhone(business.phone!),
                  ),
                if (business.email != null)
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: Text(business.email!),
                    onTap: () => _launchEmail(business.email!),
                  ),
                if (business.website != null)
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(business.website!),
                    onTap: () => _launchUrl(business.website!),
                  ),
                if (business.address != null)
                  ListTile(
                    leading: const AppIcon(AppIcon.location),
                    title: Text(business.address!),
                    subtitle:
                        business.city != null ? Text(business.city!) : null,
                  ),
                const SizedBox(height: 24),
                // Services
                if (business.services.isNotEmpty) ...[
                  Text(
                    'Services',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        business.services.map((service) {
                          return Chip(label: Text(service));
                        }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                      icon: Icon(
                        Icons.visibility,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      value: business.viewCount.toString(),
                      label: 'Vues',
                    ),
                    _StatItem(
                      icon: AppIcon(
                        AppIcon.star,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      value: business.reviewCount.toString(),
                      label: 'Avis',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Opening Hours
                if (business.openingHours.isNotEmpty) ...[
                  _OpeningHoursSection(openingHours: business.openingHours),
                  const SizedBox(height: 24),
                ],
                // Active Offers
                _OffersSection(businessId: business.id),
                const SizedBox(height: 24),
                // Reviews Section
                _ReviewsPreviewSection(
                  businessId: business.id,
                  business: business,
                  isOwner: isOwner,
                ),
                const SizedBox(height: 24),
                // Posts/Announcements
                _PostsSection(businessId: business.id, isOwner: isOwner),
                const SizedBox(height: 24),
                // Contact Button
                if (!isOwner)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        context.push(
                          '/messages/new',
                          extra: {
                            'recipientId': business.ownerId,
                            'recipientName':
                                business.ownerName ?? business.name,
                          },
                        );
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Contacter'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpeningHoursSection extends StatelessWidget {
  final Map<String, OpeningHours> openingHours;

  const _OpeningHoursSection({required this.openingHours});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const allDays = [
      'lundi',
      'mardi',
      'mercredi',
      'jeudi',
      'vendredi',
      'samedi',
      'dimanche',
    ];
    final dayLabels = {
      'lundi': 'Lundi',
      'mardi': 'Mardi',
      'mercredi': 'Mercredi',
      'jeudi': 'Jeudi',
      'vendredi': 'Vendredi',
      'samedi': 'Samedi',
      'dimanche': 'Dimanche',
    };

    // Jour courant en tête (§17d), le reste dans l'ordre de la semaine.
    final todayIndex = DateTime.now().weekday - 1;
    final todayKey = allDays[todayIndex];
    final days = [
      ...allDays.sublist(todayIndex),
      ...allDays.sublist(0, todayIndex),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horaires d\'ouverture',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...days.where((day) => openingHours.containsKey(day)).map((day) {
          final hours = openingHours[day]!;
          final isToday = day == todayKey;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      dayLabels[day] ?? day,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isToday ? FontWeight.w700 : null,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Aujourd'hui",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  hours.isClosed ? 'Fermé' : '${hours.open} - ${hours.close}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hours.isClosed ? theme.colorScheme.error : null,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _OffersSection extends ConsumerWidget {
  final String businessId;

  const _OffersSection({required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offersAsync = ref.watch(businessOffersNotifierProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_offer, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(
              'Offres en cours',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        offersAsync.when(
          data: (offers) {
            if (offers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AppIcon(AppIcon.info, color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    Text(
                      'Aucune offre en cours',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children:
                  offers.map((offer) => _OfferCard(offer: offer)).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  final BusinessPostEntity offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount =
        offer.discountPercent != null && offer.discountPercent! > 0;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-${offer.discountPercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (hasDiscount) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(offer.content, style: theme.textTheme.bodyMedium),
            if (offer.promoCode != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.confirmation_number,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Code: ${offer.promoCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (offer.offerEndDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Valable jusqu\'au ${dateFormat.format(offer.offerEndDate!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostsSection extends ConsumerWidget {
  final String businessId;
  final bool isOwner;

  const _PostsSection({required this.businessId, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final postsAsync = ref.watch(businessPostsNotifierProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Actualites',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isOwner)
              TextButton.icon(
                onPressed: () {
                  _showCreatePostDialog(context, ref);
                },
                icon: const AppIcon(AppIcon.add, size: 18),
                label: const Text('Ajouter'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        postsAsync.when(
          data: (posts) {
            // Filter out offers (they're shown in the offers section)
            final filteredPosts =
                posts.where((p) => p.type != BusinessPostType.offer).toList();
            if (filteredPosts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AppIcon(AppIcon.info, color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    Text(
                      'Aucune actualite',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children:
                  filteredPosts
                      .map(
                        (post) => _PostCard(
                          post: post,
                          isOwner: isOwner,
                          onDelete: () => _deletePost(context, ref, post),
                        ),
                      )
                      .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showCreatePostDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    BusinessPostType selectedType = BusinessPostType.announcement;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Nouvelle publication'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<BusinessPostType>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items:
                              BusinessPostType.values.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Icon(
                                        type.icon,
                                        size: 18,
                                        color: type.color,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(type.label),
                                    ],
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedType = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Titre',
                            hintText: 'Ex: Nouvelle collection disponible',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: contentController,
                          decoration: const InputDecoration(
                            labelText: 'Contenu',
                            hintText: 'Decrivez votre actualite...',
                          ),
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty ||
                            contentController.text.isEmpty) {
                          return;
                        }
                        final post = BusinessPostEntity(
                          id: '',
                          businessId: businessId,
                          title: titleController.text,
                          content: contentController.text,
                          type: selectedType,
                        );
                        await ref
                            .read(businessPostActionsProvider.notifier)
                            .createPost(post);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Publier'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _deletePost(
    BuildContext context,
    WidgetRef ref,
    BusinessPostEntity post,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Supprimer'),
            content: const Text(
              'Voulez-vous vraiment supprimer cette publication ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(businessPostActionsProvider.notifier)
                      .deletePost(post.id, businessId);
                  if (context.mounted) Navigator.pop(context);
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final BusinessPostEntity post;
  final bool isOwner;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy a HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post images
          if (post.imageUrls.isNotEmpty)
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: post.imageUrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? 0 : 4,
                      right: index == post.imageUrls.length - 1 ? 0 : 4,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrls[index],
                        fit: BoxFit.cover,
                        width: 200,
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: post.type.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            post.type.icon,
                            size: 14,
                            color: post.type.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.type.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: post.type.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isOwner)
                      IconButton(
                        icon: const AppIcon(AppIcon.delete, size: 20),
                        onPressed: onDelete,
                        color: theme.colorScheme.error,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(post.content, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (post.createdAt != null)
                  Text(
                    dateFormat.format(post.createdAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final Widget icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        icon,
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _ReviewsPreviewSection extends ConsumerWidget {
  final String businessId;
  final BusinessEntity business;
  final bool isOwner;

  const _ReviewsPreviewSection({
    required this.businessId,
    required this.business,
    required this.isOwner,
  });

  void _showReviewForm(BuildContext context, WidgetRef ref, {ReviewEntity? existingReview}) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez etre connecte pour laisser un avis')),
      );
      return;
    }

    ReviewFormModal.show(
      context,
      businessId: businessId,
      userId: currentUser.id,
      userDisplayName: currentUser.displayName ?? 'Utilisateur',
      userPhotoUrl: currentUser.photoUrl,
      existingReview: existingReview,
    );
  }

  /// Réponse du gérant à un avis (§18c). Réutilise le chemin d'écriture
  /// existant `updateReview` en posant `ownerReply`/`ownerReplyAt` sur l'avis.
  void _showReplyDialog(BuildContext context, WidgetRef ref, ReviewEntity review) {
    final controller = TextEditingController(text: review.ownerReply ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Répondre à l\'avis'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Votre réponse en tant que gérant…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              final updated = review.copyWith(
                ownerReply: text.isEmpty ? null : text,
                ownerReplyAt: text.isEmpty ? null : DateTime.now(),
              );
              final ok = await ref
                  .read(reviewActionsNotifierProvider.notifier)
                  .updateReview(updated);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      text.isEmpty ? 'Réponse supprimée' : 'Réponse publiée',
                    ),
                  ),
                );
              }
            },
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(businessReviewsNotifierProvider(businessId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final userReviewAsync = ref.watch(userBusinessReviewNotifierProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rate_review, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Avis clients',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                context.push('/businesses/$businessId/reviews', extra: business);
              },
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Rating summary
        if (business.averageRating > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  business.averageRating.toStringAsFixed(1),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StarRatingDisplay(
                      rating: business.averageRating,
                      size: 16,
                      showValue: false,
                    ),
                    Text(
                      '${business.reviewCount} avis',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // Reviews preview
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      color: theme.colorScheme.outline,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aucun avis pour le moment',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                    if (!isOwner && userReviewAsync.valueOrNull == null) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _showReviewForm(context, ref),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Ecrire le premier avis'),
                      ),
                    ],
                  ],
                ),
              );
            }

            // Show first 2 reviews as preview
            final previewReviews = reviews.take(2).toList();
            return Column(
              children: [
                ...previewReviews.map((review) {
                  final reviewIsOwner = currentUser?.id == review.userId;
                  final hasMarkedHelpful = review.helpfulByUserIds.contains(currentUser?.id);

                  return ReviewCard(
                    review: review,
                    isOwner: reviewIsOwner,
                    hasMarkedHelpful: hasMarkedHelpful,
                    onEdit: reviewIsOwner
                        ? () => _showReviewForm(context, ref, existingReview: review)
                        : null,
                    onMarkHelpful: currentUser != null && !reviewIsOwner
                        ? () => ref
                            .read(reviewActionsNotifierProvider.notifier)
                            .toggleHelpful(review.id, businessId, hasMarkedHelpful)
                        : null,
                    // Le gérant de l'entreprise peut répondre à l'avis (§18c).
                    canReply: isOwner,
                    onReply:
                        isOwner ? () => _showReplyDialog(context, ref, review) : null,
                  );
                }),
                if (!isOwner && userReviewAsync.valueOrNull == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReviewForm(context, ref),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Ecrire un avis'),
                      ),
                    ),
                  ),
                if (reviews.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () {
                        context.push('/businesses/$businessId/reviews', extra: business);
                      },
                      child: Text('Voir les ${reviews.length - 2} autres avis'),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
