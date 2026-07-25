import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../groups/domain/entities/group_entity.dart';

class AdminContentScreen extends ConsumerStatefulWidget {
  const AdminContentScreen({super.key});

  @override
  ConsumerState<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends ConsumerState<AdminContentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminDashboardNotifierProvider.notifier).fetchRecentContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminDashboardNotifierProvider);

    if (adminState.isLoading && adminState.recentContent.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Modération du Contenu',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            IconButton(
              icon: const AppIcon(AppIcon.refresh),
              onPressed: () {
                ref
                    .read(adminDashboardNotifierProvider.notifier)
                    .fetchRecentContent();
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: adminState.recentContent.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = adminState.recentContent[index];
              return _buildContentItem(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContentItem(dynamic item) {
    if (item is EventEntity) {
      return ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const AppIcon(AppIcon.event, color: Colors.blue),
        ),
        title: Text(item.title),
        subtitle: Text('Événement par ${item.organizerId}'),
        trailing: Text(
          DateFormat('dd/MM HH:mm').format(item.createdAt ?? DateTime.now()),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    } else if (item is GroupEntity) {
      return ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const AppIcon(AppIcon.groups, color: Colors.green),
        ),
        title: Text(item.name),
        subtitle: Text('Groupe • ${item.isPrivate ? "Privé" : "Public"}'),
        trailing: Text(
          DateFormat('dd/MM HH:mm').format(item.createdAt ?? DateTime.now()),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return const SizedBox();
  }
}
