import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/embassy_entity.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EmbassyListItem extends StatelessWidget {
  final EmbassyEntity embassy;

  const EmbassyListItem({super.key, required this.embassy});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/embassies/${embassy.id}', extra: embassy),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Country Flag or Embassy Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    embassy.imageUrl != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: embassy.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            errorWidget:
                                (context, url, error) => const Icon(
                                  Icons.account_balance,
                                  color: AppColors.primary,
                                  size: 30,
                                ),
                          ),
                        )
                        : const Icon(
                          Icons.account_balance,
                          color: AppColors.primary,
                          size: 30,
                        ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      embassy.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${embassy.address}, ${embassy.city}, ${embassy.country}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
