import 'dart:async';
import 'dart:convert';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import '../providers/audit_journal_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';

class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _acteur = TextEditingController();
  final _action = TextEditingController();
  final _idRessource = TextEditingController();
  String? _type;
  String? _resultat;
  DateTime? _du;
  DateTime? _au;
  Timer? _delai;

  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  static const _types = [
    'user', 'business', 'event', 'group', 'report', 'product',
    'transaction', 'settings', 'notification', 'order',
  ];
  static const _resultats = ['success', 'denied', 'failed', 'partial'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(auditJournalProvider.notifier).appliquer(const AuditFiltre()));
    });
  }

  @override
  void dispose() {
    _delai?.cancel();
    _acteur.dispose();
    _action.dispose();
    _idRessource.dispose();
    super.dispose();
  }

  AuditFiltre get _filtre => AuditFiltre(
        acteur: _acteur.text,
        action: _action.text,
        typeRessource: _type,
        idRessource: _idRessource.text,
        resultat: _resultat,
        du: _du,
        au: _au,
      );

  /// Les filtres texte attendent la fin de la frappe ; les autres s'appliquent
  /// tout de suite. Chaque application relit le serveur.
  void _appliquer({bool differe = false}) {
    _delai?.cancel();
    if (differe) {
      _delai = Timer(const Duration(milliseconds: 400),
          () => unawaited(ref.read(auditJournalProvider.notifier).appliquer(_filtre)));
    } else {
      unawaited(ref.read(auditJournalProvider.notifier).appliquer(_filtre));
    }
  }

  void _reinitialiser() {
    _acteur.clear();
    _action.clear();
    _idRessource.clear();
    setState(() {
      _type = null;
      _resultat = null;
      _du = null;
      _au = null;
    });
    _appliquer();
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(auditJournalProvider);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(etat),
                const SizedBox(height: 24),
                _buildFilters(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ];
      },
      body: etat.chargement
          ? _buildLoadingState()
          : etat.erreur != null && etat.lignes.isEmpty
              ? _buildErrorState(etat.erreur!)
              : _buildAuditLogsList(etat),
    );
  }

  Widget _buildHeader(AuditJournalState etat) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignTitle(
              l10n.adminAuditHistoryTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              accent: AdminColors.titleDot,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.jrnAudSubtitle,
              style: const TextStyle(fontSize: 14, color: _textSecondary),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: etat.export ? null : _exporter,
              icon: etat.export
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined, size: 18),
              label: Text(l10n.jrnAudExport),
            ),
            const SizedBox(width: 8),
            _buildRefreshButton(),
          ],
        ),
      ],
    );
  }

  Future<void> _exporter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.jrnAudExportTitle),
        content: Text(l10n.jrnAudExportBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.mbrAdmCancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.jrnAudExport)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(auditJournalProvider.notifier).exporter();
    if (!mounted) return;
    final erreur = ref.read(auditJournalProvider).erreur;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r == null
          ? (erreur ?? l10n.adminLoadingError)
          : r.tronque
              ? l10n.jrnAudExportTruncated('${r.lignes}')
              : l10n.jrnAudExported('${r.lignes}')),
    ));
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(ref.read(auditJournalProvider.notifier).recharger()),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primaryColor, AdminColors.actionBlueLight],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withAlpha(50),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(AppIcon.refresh, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.adminRefresh,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _champ(TextEditingController c, String libelle, {double largeur = 220}) {
    return SizedBox(
      width: largeur,
      child: TextField(
        controller: c,
        onChanged: (_) => _appliquer(differe: true),
        decoration: InputDecoration(
          labelText: libelle,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: c.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.jrnAudReset,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    c.clear();
                    setState(() {});
                    _appliquer();
                  },
                ),
        ),
      ),
    );
  }

  Widget _liste(String libelle, String? valeur, List<String> options,
      String Function(String) nom, ValueChanged<String?> surChoix) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String?>(
        initialValue: valeur,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: libelle,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(l10n.jrnAudAll)),
          for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(nom(o))),
        ],
        onChanged: (v) {
          surChoix(v);
          _appliquer();
        },
      ),
    );
  }

  Future<void> _choisirDate(bool debut) async {
    final maintenant = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (debut ? _du : _au) ?? maintenant,
      firstDate: DateTime(2025, 1, 1),
      lastDate: maintenant,
    );
    if (d == null) return;
    setState(() => debut ? _du = d : _au = d);
    _appliquer();
  }

  Widget _date(bool debut) {
    final v = debut ? _du : _au;
    final f = DateFormat('dd/MM/yyyy');
    return SizedBox(
      width: 170,
      child: OutlinedButton.icon(
        onPressed: () => _choisirDate(debut),
        icon: const Icon(Icons.event, size: 16),
        label: Text(
          v == null
              ? (debut ? l10n.jrnAudFrom : l10n.jrnAudTo)
              : '${debut ? l10n.jrnAudFrom : l10n.jrnAudTo} ${f.format(v)}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final inversee = _du != null && _au != null && _du!.isAfter(_au!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _champ(_acteur, l10n.jrnAudActor),
              _champ(_action, l10n.jrnAudAction),
              _liste(l10n.jrnAudResource, _type, _types, (t) => _getTargetTypeInfo(t).label,
                  (v) => setState(() => _type = v)),
              _champ(_idRessource, l10n.jrnAudResourceId),
              _liste(l10n.jrnAudResult, _resultat, _resultats, _nomResultat,
                  (v) => setState(() => _resultat = v)),
              _date(true),
              _date(false),
              TextButton(onPressed: _reinitialiser, child: Text(l10n.jrnAudReset)),
            ],
          ),
          if (inversee)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.jrnAudPeriodInverted,
                  style: const TextStyle(fontSize: 12, color: AdminColors.statusRed)),
            ),
        ],
      ),
    );
  }

  String _nomResultat(String r) => switch (r) {
        'success' => l10n.jrnAudResultSuccess,
        'denied' => l10n.jrnAudResultDenied,
        'failed' => l10n.jrnAudResultFailed,
        _ => l10n.jrnAudResultPartial,
      };

  Widget _buildAuditLogsList(AuditJournalState etat) {
    if (etat.lignes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: etat.lignes.length + 1,
      itemBuilder: (context, index) {
        if (index < etat.lignes.length) {
          return _buildAuditLogCard(etat.lignes[index]);
        }
        // Pied de liste : suite, chargement, ou erreur de la suite.
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: etat.chargementSuite
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (etat.erreur != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(etat.erreur!,
                              style: const TextStyle(color: AdminColors.statusRed)),
                        ),
                      if (etat.encoreDesLignes)
                        OutlinedButton(
                          onPressed: () =>
                              unawaited(ref.read(auditJournalProvider.notifier).chargerPlus()),
                          child: Text(l10n.jrnAudLoadMore),
                        )
                      else
                        Text(l10n.jrnAudEnd,
                            style: const TextStyle(fontSize: 12, color: _textSecondary)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _montrerDetail(AuditLogEntry log) {
    final f = DateFormat('dd/MM/yyyy HH:mm:ss');
    Widget ligne(String k, String? v) => v == null || v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(k, style: const TextStyle(fontSize: 12, color: _textSecondary)),
                ),
                Expanded(child: SelectableText(v, style: const TextStyle(fontSize: 13))),
              ],
            ),
          );
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.jrnAudDetailTitle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ligne(l10n.jrnAudWhen, log.timestamp == null ? null : f.format(log.timestamp!)),
                ligne(l10n.jrnAudActor, log.adminName),
                ligne(l10n.jrnAudActorId, log.adminId),
                ligne(l10n.jrnAudAction, log.action),
                ligne(l10n.jrnAudResource, log.targetType),
                ligne(l10n.jrnAudResourceId, log.targetId),
                ligne(l10n.jrnAudResult, _nomResultat(log.result)),
                ligne(l10n.jrnAudReason, log.reasonCode),
                ligne(l10n.jrnAudCorrelation, log.correlationId),
                ligne(l10n.jrnAudEntryId, log.id),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.adminDetailsLabel,
                      style: const TextStyle(fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(log.details),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.mbrAdmClose)),
        ],
      ),
    ));
  }

  Widget _buildAuditLogCard(AuditLogEntry log) {
    final actionInfo = _getActionInfo(log.action);
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR');

    return InkWell(
      onTap: () => _montrerDetail(log),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: actionInfo.color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: actionInfo.icon,
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        actionInfo.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    if (log.result != 'success') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AdminColors.statusRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_nomResultat(log.result),
                            style: const TextStyle(
                                fontSize: 11, color: AdminColors.statusRed)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _buildTargetTypeBadge(log.targetType),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const AppIcon(AppIcon.person, size: 16, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      log.adminName ?? l10n.adminUnknownAdmin,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const AppIcon(AppIcon.clock, size: 16, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      log.timestamp != null
                          ? dateFormatter.format(log.timestamp!)
                          : l10n.adminUnknownDate,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (log.targetId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tag, size: 14, color: _textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'ID: ${log.targetId}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (log.details != null && log.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailsSection(log.details!),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTargetTypeBadge(String targetType) {
    final typeInfo = _getTargetTypeInfo(targetType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: typeInfo.color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          typeInfo.icon,
          const SizedBox(width: 4),
          Text(
            typeInfo.label,
            style: TextStyle(
              color: typeInfo.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(Map<String, dynamic> details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminDetailsLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ...details.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  _ActionInfo _getActionInfo(String action) {
    switch (action) {
      case 'ban_user':
        return _ActionInfo(l10n.adminUserBanned, const Icon(Icons.block, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'unban_user':
        return _ActionInfo(l10n.adminUserUnbanned, const AppIcon(AppIcon.checkCircle, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'promote_admin':
        return _ActionInfo('Promu administrateur', const Icon(Icons.admin_panel_settings, color: AdminColors.statusPurple, size: 24), AdminColors.statusPurple);
      case 'demote_admin':
        return _ActionInfo(l10n.adminDemoted, const Icon(Icons.remove_moderator, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'verify_profile':
        return _ActionInfo(l10n.adminProfileVerifiedSuccess, const Icon(Icons.verified, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'verify_business':
        return _ActionInfo(l10n.adminBusinessVerified, const Icon(Icons.verified_user, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'unverify_business':
        return _ActionInfo(l10n.adminVerificationRemoved, const AppIcon(AppIcon.cancel, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_business':
        return _ActionInfo(l10n.adminBusinessDeleted, const AppIcon(AppIcon.delete, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'toggle_boost':
        return _ActionInfo(l10n.adminBoostChanged, const Icon(Icons.trending_up, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_event':
        return _ActionInfo(l10n.adminEventDeleted, const Icon(Icons.event_busy, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'cancel_event':
        return _ActionInfo(l10n.adminEventCancelled, const Icon(Icons.event_busy, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_group':
        return _ActionInfo(l10n.adminGroupDeleted, const Icon(Icons.group_off, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'toggle_privacy':
        return _ActionInfo(l10n.adminPrivacyChanged, const AppIcon(AppIcon.lock, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'resolve_report':
        return _ActionInfo(l10n.adminReportResolved, const AppIcon(AppIcon.checkCircle, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'dismiss_report':
        return _ActionInfo(l10n.adminReportDismissed, const AppIcon(AppIcon.cancel, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'delete_content':
        return _ActionInfo(l10n.adminContentDeleted, const Icon(Icons.delete_forever, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'refund_transaction':
        return _ActionInfo(l10n.adminTransactionRefunded, const Icon(Icons.money_off, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'complete_transaction':
        return _ActionInfo(l10n.adminTransactionCompleted, const AppIcon(AppIcon.checkCircle, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'fail_transaction':
        return _ActionInfo('Transaction échouée', const AppIcon(AppIcon.error, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'delete_product':
        return _ActionInfo(l10n.adminProductDeleted, const Icon(Icons.shopping_bag, color: AdminColors.statusRed, size: 24), AdminColors.statusRed);
      case 'toggle_product':
        return _ActionInfo(l10n.adminAvailabilityChanged, const Icon(Icons.inventory, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'resolve_dispute':
        return _ActionInfo(l10n.adminDisputeResolved, const Icon(Icons.gavel, color: AdminColors.statusGreen, size: 24), AdminColors.statusGreen);
      case 'update_settings':
        return _ActionInfo(l10n.adminConfigUpdated, const Icon(Icons.settings, color: AdminColors.actionBlue, size: 24), AdminColors.actionBlue);
      case 'toggle_feature':
        return _ActionInfo(l10n.adminFeatureChanged, const Icon(Icons.toggle_on, color: AdminColors.statusPurple, size: 24), AdminColors.statusPurple);
      case 'send_notification':
        return _ActionInfo(l10n.adminNotificationSent, const Icon(Icons.notifications, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      case 'force_logout':
        return _ActionInfo(l10n.adminForceLogoutAction, const Icon(Icons.logout, color: AdminColors.statusAmber, size: 24), AdminColors.statusAmber);
      default:
        return _ActionInfo(action, AppIcon(AppIcon.info, color: _textSecondary, size: 24), _textSecondary);
    }
  }

  _TargetTypeInfo _getTargetTypeInfo(String targetType) {
    switch (targetType) {
      case 'user':
        return _TargetTypeInfo(l10n.user, const AppIcon(AppIcon.person, size: 14, color: AdminColors.actionBlueLight), AdminColors.actionBlueLight);
      case 'business':
        return _TargetTypeInfo(l10n.reportTypeBusiness, const AppIcon(AppIcon.store, size: 14, color: AdminColors.statusGreen), AdminColors.statusGreen);
      case 'event':
        return _TargetTypeInfo(l10n.eventLabel, const AppIcon(AppIcon.event, size: 14, color: AdminColors.statusAmber), AdminColors.statusAmber);
      case 'group':
        return _TargetTypeInfo(l10n.group, const AppIcon(AppIcon.groups, size: 14, color: AdminColors.statusPurple), AdminColors.statusPurple);
      case 'report':
        return _TargetTypeInfo('Signalement', const Icon(Icons.report, size: 14, color: AdminColors.statusRed), AdminColors.statusRed);
      case 'product':
        return _TargetTypeInfo(l10n.reportTypeProduct, const Icon(Icons.shopping_bag, size: 14, color: AdminColors.actionBlue), AdminColors.actionBlue);
      case 'transaction':
        return _TargetTypeInfo(l10n.ticketCategoryTransaction, const Icon(Icons.payments, size: 14, color: AdminColors.statusGreen), AdminColors.statusGreen);
      case 'settings':
        return _TargetTypeInfo(l10n.adminConfiguration, const Icon(Icons.settings, size: 14, color: AdminColors.statusGray), AdminColors.statusGray);
      case 'notification':
        return _TargetTypeInfo('Notification', const Icon(Icons.notifications, size: 14, color: AdminColors.statusAmber), AdminColors.statusAmber);
      case 'order':
        return _TargetTypeInfo('Commande', const Icon(Icons.shopping_cart, size: 14, color: AdminColors.actionBlue), AdminColors.actionBlue);
      default:
        return _TargetTypeInfo(targetType, Icon(Icons.help, size: 14, color: _textSecondary), _textSecondary);
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(_primaryColor),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminColors.statusRed.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                AppIcon.error,
                size: 48,
                color: AdminColors.statusRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.adminLoadingError,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => unawaited(ref.read(auditJournalProvider.notifier).recharger()),
              icon: const AppIcon(AppIcon.refresh),
              label: Text(l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DesignEmptyState(
          icon: Icons.history,
          title: l10n.adminAuditEmptyTitle,
          body: l10n.adminAuditEmptyState,
        ),
      ),
    );
  }
}

class _ActionInfo {
  final String label;
  final Widget icon;
  final Color color;

  _ActionInfo(this.label, this.icon, this.color);
}

class _TargetTypeInfo {
  final String label;
  final Widget icon;
  final Color color;

  _TargetTypeInfo(this.label, this.icon, this.color);
}
