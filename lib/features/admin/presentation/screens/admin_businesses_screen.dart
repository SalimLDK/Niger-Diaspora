import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/admin_bandeau_erreur.dart';
import '../providers/admin_provider.dart';
import '../../../businesses/domain/entities/business_entity.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/admin_charger_plus.dart';

class AdminBusinessesScreen extends ConsumerStatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  ConsumerState<AdminBusinessesScreen> createState() =>
      _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends ConsumerState<AdminBusinessesScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
      unawaited(ref.read(adminBusinessNotifierProvider.notifier).fetchAllBusinesses());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminBusinessNotifierProvider);

    final filtreActif = FiltreCommerces.values[_selectedFilter];
    final filteredList = state.liste(filtreActif);
    final encorePlus = state.encorePlus.contains(filtreActif);

    String compte(FiltreCommerces f) =>
        '${state.liste(f).length}${state.encorePlus.contains(f) ? '+' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const DesignTitle(
              'Gestion des Commerces',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              accent: AdminColors.titleDot,
            ),
            IconButton(
              icon: const AppIcon(AppIcon.refresh, color: _textSecondary),
              onPressed: () {
                unawaited(ref
                    .read(adminBusinessNotifierProvider.notifier)
                    .fetchAllBusinesses());
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
              label: 'Tous (${compte(FiltreCommerces.tous)})',
              isSelected: _selectedFilter == 0,
              onTap: () => setState(() => _selectedFilter = 0),
            ),
            _buildFilterChip(
              label: 'En attente (${compte(FiltreCommerces.enAttente)})',
              isSelected: _selectedFilter == 1,
              onTap: () => setState(() => _selectedFilter = 1),
            ),
            _buildFilterChip(
              label: 'Boostés (${compte(FiltreCommerces.boostes)})',
              isSelected: _selectedFilter == 2,
              onTap: () => setState(() => _selectedFilter = 2),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Content
        Expanded(
          child: Column(
            children: [
              // Une erreur posée après une action (zéro ligne, journal
              // refusé) ne doit pas effacer la liste : page pleine seulement
              // quand il n'y a rien d'autre à montrer.
              if (state.error != null && state.businesses.isNotEmpty)
                AdminBandeauErreur(
                  message: state.error!,
                  onFermer: ref
                      .read(adminBusinessNotifierProvider.notifier)
                      .effacerErreur,
                ),
              Expanded(
                child:
                    state.isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        )
                        : state.error != null && state.businesses.isEmpty
                        ? Center(
                          child: Text(
                            'Erreur: ${state.error}',
                            style: const TextStyle(
                              color: AdminColors.statusRed,
                            ),
                          ),
                        )
                        : filteredList.isEmpty
                        ? const Center(
                          child: Text(
                            'Aucun commerce trouvé',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        )
                        : ListView.builder(
                          itemCount: filteredList.length + (encorePlus ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredList.length) {
                              return AdminChargerPlus(
                                enCours: state.chargementPlus == filtreActif,
                                onPressed: () => unawaited(
                                  ref
                                      .read(
                                        adminBusinessNotifierProvider.notifier,
                                      )
                                      .chargerPlus(filtreActif),
                                ),
                              );
                            }
                            return _buildBusinessCard(filteredList[index]);
                          },
                        ),
              ),
            ],
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
    return DesignFilterChip(label: label, selected: isSelected, onTap: onTap);
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
                      PopupMenuItem(
                        value: 'verify',
                        child: Row(
                          children: [
                            AppIcon(
                              AppIcon.checkCircle,
                              color: AdminColors.statusGreen,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(l10n.adminVerify),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'unverify',
                        child: Row(
                          children: [
                            AppIcon(AppIcon.cancel, color: AdminColors.statusAmber, size: 20),
                            SizedBox(width: 12),
                            Text(l10n.adminRemoveVerification),
                          ],
                        ),
                      ),
                    if (!business.isBoosted)
                      PopupMenuItem(
                        value: 'boost',
                        child: Row(
                          children: [
                            Icon(
                              Icons.rocket_launch,
                              color: AdminColors.actionBlueLight,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(l10n.adminBoost30Days),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'unboost',
                        child: Row(
                          children: [
                            AppIcon(AppIcon.cancel, color: AdminColors.statusGray, size: 20),
                            SizedBox(width: 12),
                            Text(l10n.adminRemoveBoost),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          AppIcon(AppIcon.delete, color: AdminColors.statusRed, size: 20),
                          SizedBox(width: 12),
                          Text(
                            l10n.adminDelete,
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
      _showSnackBar(l10n.adminNotConnected);
      return;
    }

    switch (action) {
      case 'verify':
        final ok = await notifier.verifyBusiness(
          business.id,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _montrerBilan(ok, l10n.adminBusinessVerified);
        break;
      case 'unverify':
        final ok = await notifier.unverifyBusiness(
          business.id,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _montrerBilan(ok, l10n.adminVerificationRemoved);
        break;
      case 'boost':
        final ok = await notifier.toggleBoost(
          business.id,
          true,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _montrerBilan(ok, l10n.adminBusinessBoosted);
        break;
      case 'unboost':
        final ok = await notifier.toggleBoost(
          business.id,
          false,
          adminId: currentAdmin.id,
          adminName: currentAdmin.name,
        );
        _montrerBilan(ok, l10n.adminBoostRemoved);
        break;
      case 'delete':
        final confirm = await _showDeleteConfirmation();
        if (confirm == true) {
          final ok = await notifier.deleteBusiness(
            business.id,
            adminId: currentAdmin.id,
            adminName: currentAdmin.name,
          );
          _montrerBilan(ok, l10n.adminBusinessDeleted);
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
            title: Text(l10n.adminConfirmDelete),
            content: Text(
              l10n.adminDeleteBusinessConfirm,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.adminCancelAction),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.statusRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  l10n.adminDelete,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  /// Le libellé de succès ne s'affiche que si le notifier a rendu vrai ;
  /// sinon son `state.error` (zéro ligne sous RLS, journal d'audit refusé…).
  /// Avant, le succès s'affichait quoi qu'il arrive (audit du 2026-10-14,
  /// § 5).
  void _montrerBilan(bool ok, String succes) {
    if (!mounted) return;
    if (ok) {
      _showSnackBar(succes);
      return;
    }
    _showSnackBar(
      ref.read(adminBusinessNotifierProvider).error ?? l10n.loadingError,
      isError: true,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdminColors.statusRed : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
