import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminDashboardNotifierProvider.notifier).fetchRecentUsers();
    });
  }

  Future<void> _handleForceLogout(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la déconnexion'),
            content: Text(
              'Voulez-vous vraiment déconnecter $userName de tous ses appareils ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Déconnecter'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final success = await ref
          .read(adminDashboardNotifierProvider.notifier)
          .forceLogoutUser(userId);

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$userName a été déconnecté.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminDashboardNotifierProvider);

    if (adminState.isLoading && adminState.recentUsers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Gestion des Utilisateurs',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref
                    .read(adminDashboardNotifierProvider.notifier)
                    .fetchRecentUsers();
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            elevation: 2,
            child: ListView.separated(
              itemCount: adminState.recentUsers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = adminState.recentUsers[index];
                final lastLogin =
                    user.lastLoginAt != null
                        ? DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(user.lastLoginAt!)
                        : 'Jamais';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                    child:
                        user.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(user.displayName ?? 'No Name'),
                  subtitle: Text(user.email ?? 'No Email'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Dernière connexion: $lastLogin',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (user.isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        tooltip: 'Déconnecter de force',
                        onPressed:
                            () => _handleForceLogout(
                              user.id,
                              user.displayName ?? 'Utilisateur',
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
