import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';

import '../../domain/enums/admin_enums.dart';
import '../../domain/constants/role_permissions.dart';
import '../providers/role_management_provider.dart';
import 'admin_create_admin_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class AdminRoleManagementScreen extends ConsumerStatefulWidget {
  const AdminRoleManagementScreen({super.key});

  @override
  ConsumerState<AdminRoleManagementScreen> createState() =>
      _AdminRoleManagementScreenState();
}

class _AdminRoleManagementScreenState
    extends ConsumerState<AdminRoleManagementScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roleManagementNotifierProvider.notifier).loadAdmins();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleManagementNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Expanded(
          child: _buildAdminsList(state),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AdminColors.actionBlue, AdminColors.actionBlueLight],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.admin_panel_settings, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.adminRoleManagementTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AdminColors.text,
                ),
              ),
              Text(
                l10n.adminRoleManagementSubtitle,
                style: TextStyle(
                  color: AdminColors.text2,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminCreateAdminScreen(),
              ),
            );
            if (result == true) {
              ref.read(roleManagementNotifierProvider.notifier).loadAdmins();
            }
          },
          icon: const Icon(Icons.person_add),
          label: Text(l10n.adminNewAdmin),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.actionBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: l10n.adminRefresh,
          onPressed: () {
            ref.read(roleManagementNotifierProvider.notifier).loadAdmins();
          },
        ),
      ],
    );
  }

  Widget _buildAdminsList(RoleManagementState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AdminColors.statusRed),
            const SizedBox(height: 16),
            Text(state.error!, style: const TextStyle(color: AdminColors.statusRed)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(roleManagementNotifierProvider.notifier).loadAdmins();
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (state.admins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings_outlined,
                size: 64, color: AdminColors.text3),
            SizedBox(height: 16),
            Text(
              l10n.adminNoAdminsConfigured,
              style: TextStyle(
                fontSize: 18,
                color: AdminColors.text2,
              ),
            ),
          ],
        ),
      );
    }

    // Grouper par rôle
    final groupedAdmins = <AdminRole, List<AdminUser>>{};
    for (final admin in state.admins) {
      groupedAdmins.putIfAbsent(admin.adminRole, () => []).add(admin);
    }

    return ListView(
      children: [
        for (final role in AdminRole.values)
          if (role != AdminRole.none && groupedAdmins.containsKey(role))
            _buildRoleSection(role, groupedAdmins[role]!),
      ],
    );
  }

  Widget _buildRoleSection(AdminRole role, List<AdminUser> admins) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: role.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(role.icon, color: role.color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                role.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: role.color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminColors.statusGrayBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${admins.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AdminColors.text2,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...admins.map((admin) => _buildAdminCard(admin)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAdminCard(AdminUser admin) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: admin.photoUrl != null
                  ? NetworkImage(admin.photoUrl!)
                  : null,
              child: admin.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    admin.displayName ?? l10n.adminNoName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    admin.email ?? '',
                    style: const TextStyle(color: AdminColors.text2),
                  ),
                  if (admin.lastLoginAt != null)
                    Text(
                      'Dernière connexion: ${_formatDate(admin.lastLoginAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.text3,
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<AdminRole?>(
              icon: const Icon(Icons.more_vert, color: AdminColors.text2),
              itemBuilder: (context) => [
                ...availableAdminRoles
                    .where((r) => r != admin.adminRole)
                    .map((role) => PopupMenuItem(
                          value: role,
                          child: Row(
                            children: [
                              Icon(role.icon, size: 18, color: role.color),
                              const SizedBox(width: 8),
                              Text('Changer en ${role.shortName}'),
                            ],
                          ),
                        )),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline,
                          size: 18, color: AdminColors.statusRed),
                      SizedBox(width: 8),
                      Text('Révoquer l\'accès',
                          style: TextStyle(color: AdminColors.statusRed)),
                    ],
                  ),
                ),
              ],
              onSelected: (newRole) {
                if (newRole == null) {
                  _confirmRevoke(admin);
                } else {
                  _confirmChangeRole(admin, newRole);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmChangeRole(AdminUser admin, AdminRole newRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminChangeRoleTitle),
        content: Text(
          'Voulez-vous changer le rôle de ${admin.displayName ?? admin.email} '
          'de ${admin.adminRole.shortName} à ${newRole.shortName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.adminCancelAction),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(roleManagementNotifierProvider.notifier)
                  .assignRole(admin.id, newRole);
            },
            child: Text(l10n.adminConfirmAction),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(AdminUser admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Révoquer l\'accès admin'),
        content: Text(
          'Voulez-vous vraiment révoquer l\'accès admin de '
          '${admin.displayName ?? admin.email}? Cette personne ne pourra plus '
          'accéder au panneau d\'administration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.adminCancelAction),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(roleManagementNotifierProvider.notifier)
                  .revokeRole(admin.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.statusRed,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.adminRevoke),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
