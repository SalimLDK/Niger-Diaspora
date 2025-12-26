import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/business_entity.dart';
import '../providers/business_provider.dart';

class BusinessDetailScreen extends ConsumerStatefulWidget {
  final String businessId;
  final BusinessEntity? initialBusiness;

  const BusinessDetailScreen({
    super.key,
    required this.businessId,
    this.initialBusiness,
  });

  @override
  ConsumerState<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends ConsumerState<BusinessDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(businessDetailNotifierProvider.notifier).loadBusiness(widget.businessId);
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

    return Scaffold(
      body: businessAsync.when(
        data: (loadedBusiness) => _buildContent(context, loadedBusiness ?? widget.initialBusiness!, currentUser?.id),
        loading: () => business != null
            ? _buildContent(context, business, currentUser?.id)
            : const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(error.toString(), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(businessDetailNotifierProvider.notifier).loadBusiness(widget.businessId);
                },
                child: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BusinessEntity business, String? currentUserId) {
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
            background: hasImages
                ? CachedNetworkImage(
                    imageUrl: business.photoUrls.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(business.category.icon, size: 64),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(business.category.icon, size: 64, color: theme.colorScheme.outline),
                  ),
          ),
          actions: [
            if (isOwner)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.push('/businesses/${business.id}/edit', extra: business);
                      break;
                    case 'boost':
                      context.push('/businesses/${business.id}/boost', extra: business);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  const PopupMenuItem(value: 'boost', child: Text('Booster')),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Verifie', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    if (business.isBoosted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 16, color: theme.colorScheme.onPrimary),
                            const SizedBox(width: 4),
                            Text('Premium', style: TextStyle(color: theme.colorScheme.onPrimary)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  business.name,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Rating
                if (business.averageRating > 0)
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < business.averageRating.round() ? Icons.star : Icons.star_border,
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
                Text(
                  business.description,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                // Contact section
                Text(
                  'Contact',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (business.phone != null)
                  ListTile(
                    leading: const Icon(Icons.phone),
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
                    leading: const Icon(Icons.location_on),
                    title: Text(business.address!),
                    subtitle: business.city != null ? Text(business.city!) : null,
                  ),
                const SizedBox(height: 24),
                // Services
                if (business.services.isNotEmpty) ...[
                  Text(
                    'Services',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: business.services.map((service) {
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
                      icon: Icons.visibility,
                      value: business.viewCount.toString(),
                      label: 'Vues',
                    ),
                    _StatItem(
                      icon: Icons.star,
                      value: business.reviewCount.toString(),
                      label: 'Avis',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
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
        Icon(icon, size: 32, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}
