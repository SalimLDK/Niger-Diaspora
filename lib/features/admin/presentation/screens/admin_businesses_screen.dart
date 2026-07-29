import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../businesses/domain/entities/business_entity.dart';

class AdminBusinessesScreen extends ConsumerStatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  ConsumerState<AdminBusinessesScreen> createState() =>
      _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends ConsumerState<AdminBusinessesScreen> {
  int _selectedFilter = 0;

  // Couleurs cohérentes avec le dashboard
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminBusinessNotifierProvider.notifier).fetchAllBusinesses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminBusinessNotifierProvider);

    final allBusinesses = state.businesses;
    final pendingBusinesses = state.pendingVerification;
    final boostedBusinesses =
        state.businesses.where((b) => b.isBoosted).toList();

    List<BusinessEntity> filteredList;
    switch (_selectedFilter) {
      case 1:
        filteredList = pendingBusinesses;
        break;
      case 2:
        filteredList = boostedBusinesses;
        break;
      default:
        filteredList = allBusinesses;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gestion des Commerces',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            IconButton(
              icon: const AppIcon(AppIcon.refresh, color: _textSecondary),
              onPressed: () {
                ref
                    .read(adminBusinessNotifierProvider.notifier)
                    .fetchAllBusinesses();
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Filter chips
        Wrap(
          spacing: 12,
          children: [
            _buildFilterChip(
              label: 'Tous (${allBusinesses.length})',
              isSelected: _selectedFilter == 0,
              onTap: () => setState(() => _selectedFilter = 0),
            ),
            _buildFilterChip(
              label: 'En attente (${pendingBusinesses.length})',
              isSelected: _selectedFilter == 1,
              onTap: () => setState(() => _selectedFilter = 1),
            ),
            _buildFilterChip(
              label: 'Boostés (${boostedBusinesses.length})',
              isSelected: _selectedFilter == 2,
              onTap: () => setState(() => _selectedFilter = 2),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Content
        Expanded(
          child:
              state.isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  )
                  : state.error != null
                  ? Center(
                    child: Text(
                      'Erreur: ${state.error}',
                      style: const TextStyle(color: AdminColors.statusRed),
                    ),
                  )
                  : filteredList.isEmpty
                  ? const Center(
                    child: Text(
                      'Aucun commerce trouvé',
                      style: TextStyle(color: _textSecondary, fontSize: 16),
                    ),
                  )
                  : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      return _buildBusinessCard(filteredList[index]);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryColor : AdminColors.border,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: _primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessCard(BusinessEntity business) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Logo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AdminColors.statusGrayBg,
                borderRadius: BorderRadius.circular(12),
                image:
                    business.logoUrl != null
                        ? DecorationImage(
                          image: NetworkImage(business.logoUrl!),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  business.logoUrl == null
                      ? const AppIcon(AppIcon.store, color: _textSecondary, size: 28)
                      : null,
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          business.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      if (business.isVerified)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: const Icon(
                            Icons.verified,
                            color: AdminColors.actionBlueLight,
                            size: 20,
                          ),
                        ),
                      if (business.isBoosted)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          child: const Icon(
                            Icons.rocket_launch,
                            color: AdminColors.statusAmber,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${business.city ?? ''}, ${business.country ?? ''}'.trim(),
                    style: const TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      business.category.label,
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _textSecondary),
              onSelected: (value) => _handleAction(value, business),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder:
                  (context) => [
                    if (!business.isVerified)
                      const PopupMenuItem(
                        value: 'verify',
                        child: Row(
                          children: [
                            AppIcon(
                              AppIcon.checkCircle,
                              color: AdminColors.statusGreen,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text('Vérifier'),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'unverify',
                        child: Row(
                          children: [
                            AppIcon(AppIcon.cancel, color: AdminColors.statusAmber, size: 20),
                            SizedBox(width: 12),
                            Text('Retirer vérification'),
                          ],
                        ),
                      ),
                    if (!business.isBoosted)
                      const PopupMenuItem(
                        value: 'boost',
                        child: Row(
                          children: [
                            Icon(
                              Icons.rocket_launch,
                              color: AdminColors.actionBlueLight,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text('Booster (30 jours)'),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'unboost',
                        child: Row(
                          children: [
                            AppIcon(AppIcon.cancel, color: AdminColors.statusGray, size: 20),
                            SizedBox(width: 12),
                            Text('Retirer boost'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          AppIcon(AppIcon.delete, color: AdminColors.statusRed, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Supprimer',
                            style: TextStyle(color: AdminColors.statusRed),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action, BusinessEntity business) async {
    final notifier = ref.read(adminBusinessNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    switch (action) {
      case 'verify':
        await notifier.verifyBusiness(
          business.id,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _showSnackBar('Commerce vérifié');
        break;
      case 'unverify':
        await notifier.unverifyBusiness(
          business.id,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _showSnackBar('Vérification retirée');
        break;
      case 'boost':
        await notifier.toggleBoost(
          business.id,
          true,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _showSnackBar('Commerce boosté pour 30 jours');
        break;
      case 'unboost':
        await notifier.toggleBoost(
          business.id,
          false,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _showSnackBar('Boost retiré');
        break;
      case 'delete':
        final confirm = await _showDeleteConfirmation();
        if (confirm == true) {
          await notifier.deleteBusiness(
            business.id,
            adminId: currentAdmin.id,
            adminName: currentAdmin.name,
          );
          _showSnackBar('Commerce supprimé');
        }
        break;
    }
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Confirmer la suppression'),
            content: const Text(
              'Êtes-vous sûr de vouloir supprimer ce commerce ? Cette action est irréversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.statusRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
