import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../../../core/utils/user_color_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/call_entity.dart';
import '../providers/call_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Filter type for call history
enum CallHistoryFilter { all, missed, incoming, outgoing }

/// Historique des appels (fiche 13c) : en-tête à sous-titre d'alerte, chips
/// pilule dont « Manqués » porte son compteur, lignes groupées par jour avec
/// rappel en un geste.
class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  CallHistoryFilter _selectedFilter = CallHistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final callHistoryAsync = ref.watch(callHistoryProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final currentUserId = currentUser?.id ?? '';
    final allCalls = callHistoryAsync.valueOrNull ?? const <CallEntity>[];
    final missedCount = allCalls.where(_isMissed).length;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, missedCount),
            _buildFilterChips(context, missedCount),
            const SizedBox(height: 4),
            Expanded(
              child: callHistoryAsync.when(
                data: (calls) {
                  final filteredCalls = _filterCalls(calls, currentUserId);
                  if (filteredCalls.isEmpty) {
                    return _buildEmptyState(context, l10n);
                  }
                  final groupedCalls = _groupCallsByDate(filteredCalls);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      for (final entry in groupedCalls.entries)
                        ..._buildDateSection(
                          context,
                          entry.key,
                          entry.value,
                          currentUserId,
                          l10n,
                        ),
                      const SizedBox(height: 14),
                      const _SwipeHint(),
                    ],
                  );
                },
                loading:
                    () => Center(
                      child: CircularProgressIndicator(
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                error:
                    (error, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(
                            AppIcon.error,
                            size: 48,
                            color: context.textTertiaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.loadingError,
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => ref.invalidate(callHistoryProvider),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // En-tête et filtres
  // ---------------------------------------------------------------------------

  /// Titre « Appels » et, dessous, le nombre d'appels manqués en rouge :
  /// l'alerte se lit sans ouvrir la liste ni changer de filtre (fiche 13c).
  Widget _buildHeader(BuildContext context, int missedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // La maquette n'a pas de flèche — elle suppose un onglet de
          // navigation. Ici la route est empilée (depuis le profil), donc on
          // la montre quand, et seulement quand, il y a où revenir.
          if (context.canPop()) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pop(),
              child: Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: AppIcon(
                  AppIcon.arrowBack,
                  size: 24,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.calls,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: context.textPrimaryColor,
                  ),
                ),
                if (missedCount > 0)
                  Text(
                    missedCount > 1
                        ? '$missedCount appels manqués'
                        : '1 appel manqué',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HeaderMenuButton(onClear: () => _showClearHistoryDialog(context, ref)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, int missedCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          _buildFilterChip(context, label: l10n.everything, filter: CallHistoryFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: 'Manqués',
            filter: CallHistoryFilter.missed,
            badge: missedCount,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: 'Entrants',
            filter: CallHistoryFilter.incoming,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            label: 'Sortants',
            filter: CallHistoryFilter.outgoing,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required CallHistoryFilter filter,
    int badge = 0,
  }) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? context.textPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border:
              isSelected ? null : Border.all(color: context.borderStrongColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected
                        ? context.backgroundColor
                        : context.textSecondaryColor,
              ),
            ),
            // Le compteur ne s'affiche que s'il y a effectivement des manqués :
            // un « 0 » rouge serait une alerte pour rien.
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filtrage et regroupement
  // ---------------------------------------------------------------------------

  static bool _isMissed(CallEntity call) =>
      call.status == CallStatus.missed || call.status == CallStatus.declined;

  List<CallEntity> _filterCalls(List<CallEntity> calls, String currentUserId) {
    switch (_selectedFilter) {
      case CallHistoryFilter.all:
        return calls;
      case CallHistoryFilter.missed:
        return calls.where(_isMissed).toList();
      case CallHistoryFilter.incoming:
        return calls.where((call) => call.isIncoming(currentUserId)).toList();
      case CallHistoryFilter.outgoing:
        return calls.where((call) => !call.isIncoming(currentUserId)).toList();
    }
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final (String message, IconData icon) = switch (_selectedFilter) {
      CallHistoryFilter.all => (l10n.noCallHistory, Icons.call_outlined),
      CallHistoryFilter.missed => (l10n.noMissedCalls, Icons.call_missed),
      CallHistoryFilter.incoming => (l10n.noIncomingCalls, Icons.call_received),
      CallHistoryFilter.outgoing => (l10n.noOutgoingCalls, Icons.call_made),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: context.adaptivePrimaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.noCallHistoryDescription,
              style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<CallEntity>> _groupCallsByDate(List<CallEntity> calls) {
    final grouped = <String, List<CallEntity>>{};
    for (final call in calls) {
      grouped.putIfAbsent(_getDateKey(call.createdAt), () => []).add(call);
    }
    return grouped;
  }

  String _getDateKey(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(local.year, local.month, local.day);

    if (callDate == today) return 'today';
    if (callDate == yesterday) return 'yesterday';
    if (now.difference(local).inDays < 7) {
      return DateFormat(
        'EEEE',
        LocaleHelper.getDateFormatLocale(context),
      ).format(local);
    }
    return DateFormat(
      'd MMMM yyyy',
      LocaleHelper.getDateFormatLocale(context),
    ).format(local);
  }

  String _formatDateHeader(String key, AppLocalizations l10n) {
    if (key == 'today') return l10n.today('');
    if (key == 'yesterday') return l10n.yesterday('');
    return key.substring(0, 1).toUpperCase() + key.substring(1);
  }

  List<Widget> _buildDateSection(
    BuildContext context,
    String dateKey,
    List<CallEntity> calls,
    String currentUserId,
    AppLocalizations l10n,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          _formatDateHeader(dateKey, l10n).toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.05,
            color: context.goldColor,
          ),
        ),
      ),
      // Regroupe les appels consécutifs avec le même correspondant (§13c).
      ..._collapseConsecutive(calls, currentUserId).map(
        (group) => _SwipeableCallHistoryItem(
          key: ValueKey(group.call.id),
          call: group.call,
          currentUserId: currentUserId,
          repeatCount: group.count,
          onTap: () => _onCallTap(context, group.call, currentUserId),
          onCallBack: () => _onCallBack(group.call, currentUserId),
          onDelete: () => _onDeleteCall(context, ref, group.call, l10n),
        ),
      ),
    ];
  }

  /// Fusionne les appels consécutifs partageant le même correspondant en une
  /// seule entrée portant le nombre d'appels (§13c). L'appel le plus récent du
  /// groupe sert de représentant.
  List<({CallEntity call, int count})> _collapseConsecutive(
    List<CallEntity> calls,
    String currentUserId,
  ) {
    final result = <({CallEntity call, int count})>[];
    for (final call in calls) {
      final party = call.getOtherPartyId(currentUserId);
      if (result.isNotEmpty &&
          result.last.call.getOtherPartyId(currentUserId) == party) {
        final prev = result.removeLast();
        result.add((call: prev.call, count: prev.count + 1));
      } else {
        result.add((call: call, count: 1));
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _onDeleteCall(
    BuildContext context,
    WidgetRef ref,
    CallEntity call,
    AppLocalizations l10n,
  ) async {
    final repository = ref.read(callRepositoryProvider);
    final result = await repository.deleteCall(call.id);

    result.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteError),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (_) {
        ref.invalidate(callHistoryProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.callDeleted)));
        }
      },
    );
  }

  void _onCallTap(BuildContext context, CallEntity call, String currentUserId) {
    context.push('/profile/${call.getOtherPartyId(currentUserId)}');
  }

  void _onCallBack(CallEntity call, String currentUserId) {
    ref
        .read(currentCallProvider.notifier)
        .initiateCall(
          calleeId: call.getOtherPartyId(currentUserId),
          calleeName: call.getOtherPartyName(currentUserId),
          calleePhotoUrl: call.getOtherPartyPhotoUrl(currentUserId),
          type: call.type,
        );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.clearHistory),
            content: Text(l10n.clearHistoryConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final calls = ref.read(callHistoryProvider).valueOrNull ?? [];
                  if (calls.isEmpty) return;
                  final repository = ref.read(callRepositoryProvider);
                  var allSuccess = true;
                  for (final call in calls) {
                    final result = await repository.deleteCall(call.id);
                    if (result.isLeft()) allSuccess = false;
                  }
                  ref.invalidate(callHistoryProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          allSuccess ? 'Historique effacé' : l10n.callDeleteError,
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  l10n.clear,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}

/// Bouton ⋯ de l'en-tête : pastille 42×42 rayon 14 (fiche 13c) au lieu de
/// l'icône nue, pour équilibrer le titre de 26 px.
class _HeaderMenuButton extends StatelessWidget {
  final VoidCallback onClear;

  const _HeaderMenuButton({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: context.textSecondaryColor),
        padding: EdgeInsets.zero,
        onSelected: (value) {
          if (value == 'clear') onClear();
        },
        itemBuilder:
            (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const AppIcon(AppIcon.delete, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(l10n.clearHistory),
                  ],
                ),
              ),
            ],
      ),
    );
  }
}

/// Ligne d'historique (fiche 13c) : avatar carré arrondi 46, nom en rouge si
/// l'appel a été manqué, sous-ligne « sens · heure · durée », et le bouton de
/// rappel teinté en vert quand il y a un appel à rattraper.
class _CallHistoryItem extends StatelessWidget {
  final CallEntity call;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onCallBack;
  final int repeatCount;

  const _CallHistoryItem({
    required this.call,
    required this.currentUserId,
    required this.onTap,
    required this.onCallBack,
    this.repeatCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = call.isIncoming(currentUserId);
    final isMissed = call.status == CallStatus.missed;
    final isDeclined = call.status == CallStatus.declined;
    final isBusy = call.status == CallStatus.busy;
    final needsAttention = isMissed || isDeclined || isBusy;
    final otherPartyId = call.getOtherPartyId(currentUserId);
    final otherPartyName = call.getOtherPartyName(currentUserId);
    final otherPartyPhoto = call.getOtherPartyPhotoUrl(currentUserId);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            _Avatar(
              name: otherPartyName,
              photoUrl: otherPartyPhoto,
              userId: otherPartyId,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherPartyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color:
                          needsAttention
                              ? AppColors.error
                              : context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        _callIcon(isIncoming, isMissed, isDeclined, isBusy),
                        size: 15,
                        color:
                            needsAttention
                                ? AppColors.error
                                : context.textTertiaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _subtitle(context, isIncoming, needsAttention),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CallBackButton(
              isVideo: call.type == CallType.video,
              highlighted: needsAttention,
              onTap: onCallBack,
            ),
          ],
        ),
      ),
    );
  }

  IconData _callIcon(
    bool isIncoming,
    bool isMissed,
    bool isDeclined,
    bool isBusy,
  ) {
    if (isBusy) return Icons.phone_disabled;
    if (isMissed || isDeclined) {
      return isIncoming ? Icons.call_missed : Icons.call_missed_outgoing;
    }
    return isIncoming ? Icons.call_received : Icons.call_made;
  }

  /// « Manqué · 09:12 · 2 appels » / « Sortant · 08:40 · 12 min ».
  String _subtitle(BuildContext context, bool isIncoming, bool needsAttention) {
    final l10n = AppLocalizations.of(context)!;
    final String sense;
    if (call.status == CallStatus.busy) {
      sense = l10n.busyCall;
    } else if (call.status == CallStatus.missed) {
      sense = l10n.callMissed;
    } else if (call.status == CallStatus.declined) {
      sense = isIncoming ? l10n.declinedCall : l10n.noAnswer;
    } else {
      sense = isIncoming ? 'Entrant' : 'Sortant';
    }

    final parts = <String>[
      sense,
      DateFormat('HH:mm').format(call.createdAt.toLocal()),
    ];
    // Le nombre d'appels remplace la durée sur une série manquée : c'est
    // l'insistance qui compte, pas les 0 seconde de chaque tentative.
    if (repeatCount > 1) {
      parts.add('$repeatCount appels');
    } else {
      final duration = _compactDuration(call.durationSeconds);
      if (duration != null) parts.add(duration);
    }
    return parts.join(' · ');
  }

  static String? _compactDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    if (seconds < 60) return '$seconds s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h ${rest.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String userId;

  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: UserColorUtils.getUserColor(userId),
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child:
          (photoUrl != null && photoUrl!.isNotEmpty)
              ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                width: 46,
                height: 46,
                errorBuilder: (_, __, ___) => _initialsLabel(initials),
              )
              : _initialsLabel(initials),
    );
  }

  Widget _initialsLabel(String initials) => Text(
    initials,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  );

  static String _initials(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

class _CallBackButton extends StatelessWidget {
  final bool isVideo;
  final bool highlighted;
  final VoidCallback onTap;

  const _CallBackButton({
    required this.isVideo,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          // Vert quand il y a quelque chose à rattraper, neutre sinon.
          color:
              highlighted
                  ? context.successBackgroundColor
                  : context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: AppIcon(
          isVideo ? AppIcon.video : AppIcon.call,
          size: 19,
          color: highlighted ? context.successColor : context.textSecondaryColor,
        ),
      ),
    );
  }
}

/// Astuce de bas de liste (fiche 13c) : le balayage n'a aucune affordance,
/// personne ne le devine.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderStrongColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.swipe_left_outlined,
            size: 19,
            color: context.textTertiaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Balayez une ligne vers la gauche pour la supprimer',
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable wrapper for call history items with delete functionality
class _SwipeableCallHistoryItem extends StatelessWidget {
  final CallEntity call;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onCallBack;
  final VoidCallback onDelete;
  final int repeatCount;

  const _SwipeableCallHistoryItem({
    super.key,
    required this.call,
    required this.currentUserId,
    required this.onTap,
    required this.onCallBack,
    required this.onDelete,
    this.repeatCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey('dismissible_${call.id}'),
      direction: DismissDirection.endToStart,
      // La maquette supprime sans confirmation ; on la garde — un historique
      // effacé par un geste involontaire ne se récupère pas.
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text(l10n.deleteCall),
                    content: Text(l10n.deleteCallConfirmation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          l10n.delete,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const AppIcon(AppIcon.delete, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              l10n.delete,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      child: _CallHistoryItem(
        call: call,
        currentUserId: currentUserId,
        onTap: onTap,
        onCallBack: onCallBack,
        repeatCount: repeatCount,
      ),
    );
  }
}
