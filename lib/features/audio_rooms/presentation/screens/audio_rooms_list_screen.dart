import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/audio_room_entity.dart';
import '../providers/audio_room_provider.dart';
import '../providers/monetization_provider.dart';
import '../widgets/_shared/collection_progress_bar.dart';
import '../widgets/_shared/dn_tab_bar.dart';
import '../widgets/_shared/live_dot.dart';
import '../widgets/_shared/mode_chip.dart';
import '../widgets/buy_ticket_bottom_sheet.dart';
import '../widgets/timezone_display_widget.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// /audio-rooms — Live + Programmés list with Sahel design.
class AudioRoomsListScreen extends ConsumerStatefulWidget {
  const AudioRoomsListScreen({super.key});

  @override
  ConsumerState<AudioRoomsListScreen> createState() =>
      _AudioRoomsListScreenState();
}

class _AudioRoomsListScreenState extends ConsumerState<AudioRoomsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String _selectedCategory = 'Tous';

  static const _categories = [
    'Tous', 'Discussion', 'Actualités', 'Culture', 'Griot/Conte',
    'Business', 'Mentorat', 'Famille', 'Officiel', 'Spiritualité', 'Éducation',
  ];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveAudioRoomsProvider);
    final scheduled = ref.watch(scheduledAudioRoomsProvider);
    final liveCount = live.value?.length ?? 0;
    final scheduledCount = scheduled.value?.length ?? 0;
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;

    return Scaffold(
      backgroundColor: dn.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _ArHeader(liveCount: liveCount, scheduledCount: scheduledCount),
                DnTabBar(
                  controller: _tabs,
                  labels: [
                    l10n.audioRoomsLiveTabLabel(liveCount),
                    l10n.audioRoomsScheduledTabLabel(scheduledCount),
                  ],
                ),
                _CategoryFilters(
                  selected: _selectedCategory,
                  categories: _categories,
                  onSelect: (c) => setState(() => _selectedCategory = c),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _LiveList(rooms: live, category: _selectedCategory),
                      _ScheduledList(rooms: scheduled, category: _selectedCategory),
                    ],
                  ),
                ),
              ],
            ),
            // Le CTA principal était un petit rond de 52 px avec une icône
            // seule, moins visible que le bouton secondaire à côté. Il
            // devient une pilule large qui se nomme (maquette 1a/2g).
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: Row(
                children: [
                  Expanded(
                    child: _OpenRoomButton(
                      onTap: () => context.push('/audio-rooms/create'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ScheduleButton(
                    onTap: () => context.push('/audio-rooms/schedule'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ArHeader extends StatelessWidget {
  final int liveCount;
  final int scheduledCount;

  const _ArHeader({required this.liveCount, required this.scheduledCount});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      child: Row(
        children: [
          BackButton(
            color: dn.onSurface,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              minimumSize: WidgetStateProperty.all(const Size(36, 36)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.audioRoomsTitle,
                    style: DNText.serif(size: 20, color: dn.onSurface),),
                // La répartition direct/programmés est plus utile que le
                // total combiné, qui ne disait pas ce qui est écoutable tout
                // de suite.
                Text(
                  AppLocalizations.of(context)!
                      .audioRoomsLiveAndScheduled(liveCount, scheduledCount),
                  style: DNText.mono(size: 9, color: dn.onSurface3),
                ),
              ],
            ),
          ),
          // Remplace un bouton loupe qui était un `onPressed: () {}` — il
          // n'existe aucune recherche de salons. Le patrimoine oral, lui,
          // n'avait aucun point d'entrée du tout.
          IconButton(
            icon: Icon(Icons.auto_stories_rounded, color: dn.onSurface, size: 20),
            tooltip: AppLocalizations.of(context)!.heritageOralTitle,
            onPressed: () => context.push('/audio-rooms/heritage'),
          ),
        ],
      ),
    );
  }
}

// ─── Category filters ─────────────────────────────────────────────────────────

class _CategoryFilters extends StatelessWidget {
  final String selected;
  final List<String> categories;
  final ValueChanged<String> onSelect;

  const _CategoryFilters({
    required this.selected,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final active = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? dn.onSurface : dn.surface2,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                cat,
                style: DNText.mono(
                  size: 9,
                  color: active ? dn.surface : dn.onSurface3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Live list ────────────────────────────────────────────────────────────────

class _LiveList extends ConsumerWidget {
  final AsyncValue<List<AudioRoomEntity>> rooms;
  final String category;

  const _LiveList({required this.rooms, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return rooms.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: DNColors.terra),),
      error: (e, _) => Center(
          child: Text(
            ErrorHandler.instance.getShortMessage(
              ErrorHandler.instance.handleException(e),
            ),
            style: DNText.sans(color: context.dn.onSurface),
          ),),
      data: (list) {
        final filtered = category == 'Tous'
            ? list
            : list.where((r) => r.categoryLabel == category).toList();
        if (filtered.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return _EmptyState(
              message: l10n.audioRoomsNoLiveRooms,
              sub: '${l10n.audioRoomsNoLiveSubtitle} 🎙',
              showActions: true,);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _LiveCard(room: filtered[i]),
        );
      },
    );
  }
}

/// « Patrimoine · Zarma · Tillabéri » quand le salon est marqué patrimoine.
/// `null` sinon — on n'affiche pas une ligne vide.
String? _heritageSubtitle(BuildContext context, AudioRoomEntity room) {
  if (!room.isHeritageContent) return null;
  final parts = <String>[AppLocalizations.of(context)!.audioRoomModeHeritage];
  if (room.heritageLanguage != null && room.heritageLanguage!.isNotEmpty) {
    parts.add(room.heritageLanguage!);
  }
  if (room.heritageRegion != null && room.heritageRegion!.isNotEmpty) {
    parts.add(room.heritageRegion!);
  }
  return parts.join(' · ');
}

class _LiveCard extends ConsumerWidget {
  final AudioRoomEntity room;

  const _LiveCard({required this.room});

  void _enterRoom(BuildContext context) {
    context.push('/audio-rooms/${room.id}', extra: {'title': room.title});
  }

  /// Salon payant (§1h) : vérifie un billet déjà acheté avant d'entrer,
  /// sinon ouvre `BuyTicketBottomSheet` — l'entrée ne suit que si l'achat
  /// réussit (ou si un billet valide existait déjà).
  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    if (!room.isPaid) {
      _enterRoom(context);
      return;
    }

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final hasTicket = await ref.read(
      hasValidTicketProvider((roomId: room.id, userId: currentUser.id)).future,
    );
    if (hasTicket) {
      if (context.mounted) _enterRoom(context);
      return;
    }

    if (!context.mounted) return;
    final purchased = await BuyTicketBottomSheet.show(context, room: room);
    if (purchased == true && context.mounted) {
      _enterRoom(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dn = context.dn;
    final mode = roomModeFrom(room.mode.name);
    final isAdmin = ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;
    return GestureDetector(
      onTap: () => _handleTap(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dn.surface,
          border: Border.all(color: dn.surface2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LiveDot(),
                const SizedBox(width: 5),
                Text(
                  AppLocalizations.of(context)!.audioRoomsLiveListeners(room.listenerCount),
                  style: DNText.mono(size: 9, color: DNColors.terra),
                ),
                // Depuis combien de temps ça tourne : ce qui dit si on
                // arrive au début d'un salon ou à sa fin.
                if (room.startedAt != null) ...[
                  Text(' · ',
                      style: DNText.mono(size: 9, color: DNColors.terra),),
                  Text(
                    AppLocalizations.of(context)!.audioRoomElapsedMinutes(
                      DateTime.now().difference(room.startedAt!).inMinutes,
                    ),
                    style: DNText.mono(size: 9, color: DNColors.terra),
                  ),
                ],
                const Spacer(),
                // Seul point d'entrée vers la vue fantôme : la route existait
                // mais aucun écran n'y menait, donc toute la modération
                // invisible était inatteignable.
                if (isAdmin) ...[
                  Tooltip(
                    message: AppLocalizations.of(context)!.ghostSuperAdminBadge,
                    child: InkWell(
                      onTap: () =>
                          context.push('/audio-rooms/${room.id}/ghost'),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.visibility_off_outlined,
                          size: 15,
                          color: dn.onSurface3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                ModeChip(mode: mode),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              room.title,
              style: DNText.serif(size: 16, color: dn.onSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // « Patrimoine · Zarma · Tillabéri » : la langue et la région
            // d'un salon patrimoine étaient stockées sans jamais être vues.
            if (_heritageSubtitle(context, room) != null) ...[
              const SizedBox(height: 2),
              Text(
                _heritageSubtitle(context, room)!,
                style: DNText.mono(size: 9, color: DNColors.ochre),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _AvatarStack(names: [room.hostName]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    room.hostName,
                    style: DNText.sans(size: 11, color: dn.onSurface2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.isPaid)
                  _PricePill(
                    price: (room.ticketPrice ?? 0) / 100,
                    currencyCode: room.ticketCurrency,
                  ),
              ],
            ),
            // Métriques (§1a) : intervenants sur max + tags + Participer.
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.mic_none_rounded, size: 13, color: dn.onSurface3),
                const SizedBox(width: 3),
                Text(
                  '${room.speakerIds.length}/${room.maxSpeakers}',
                  style: DNText.mono(size: 9, color: dn.onSurface3),
                ),
                if (room.tags.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      room.tags.take(3).map((t) => '#$t').join('  '),
                      style: DNText.mono(size: 9, color: dn.onSurface3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: DNColors.terra,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    // Un salon payant demande d'abord un billet : afficher
                    // « Rejoindre » laissait croire à une entrée directe.
                    room.isPaid
                        ? AppLocalizations.of(context)!.audioRoomTicketAction
                        : AppLocalizations.of(context)!.join,
                    style: DNText.mono(size: 9, color: DNColors.paper),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scheduled list ───────────────────────────────────────────────────────────

class _ScheduledList extends ConsumerWidget {
  final AsyncValue<List<AudioRoomEntity>> rooms;
  final String category;

  const _ScheduledList({required this.rooms, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return rooms.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: DNColors.terra),),
      error: (e, _) => Center(
          child: Text(
            ErrorHandler.instance.getShortMessage(
              ErrorHandler.instance.handleException(e),
            ),
            style: DNText.sans(color: context.dn.onSurface),
          ),),
      data: (list) {
        final filtered = category == 'Tous'
            ? list
            : list.where((r) => r.categoryLabel == category).toList();
        if (filtered.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          return _EmptyState(
              message: l10n.audioRoomsNoScheduledRooms,
              sub: '${l10n.audioRoomsNoScheduledSubtitle} 📅',);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ScheduledCard(room: filtered[i]),
        );
      },
    );
  }
}

class _ScheduledCard extends StatelessWidget {
  final AudioRoomEntity room;

  const _ScheduledCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final mode = roomModeFrom(room.mode.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dn.surface,
        border: Border.all(color: dn.surface2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (room.scheduledAt != null)
                Text(
                  '📅 ${_fmtDate(context, room.scheduledAt!)}',
                  style: DNText.mono(size: 9, color: dn.onSurface3),
                ),
              const Spacer(),
              ModeChip(mode: mode),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            room.title,
            style: DNText.serif(size: 16, color: dn.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${room.hostName} · ${AppLocalizations.of(context)!.audioRoomsRegisteredCount(room.listenerCount)}',
            style: DNText.sans(size: 11, color: dn.onSurface3),
          ),
          // Heure dans plusieurs fuseaux (§1a) — réutilise la logique tz testée.
          if (room.scheduledAt != null) ...[
            const SizedBox(height: 8),
            TimezoneDisplayWidget(
              utcTime: room.scheduledAt!.toUtc(),
              timezones: room.displayTimezones,
              compact: true,
              showDate: false,
            ),
          ],
          if (room.hasActiveCollection) ...[
            const SizedBox(height: 8),
            CollectionProgressBar(
              current: room.collectionAmount / 100,
              goal: (room.collectionGoal ?? 0) / 100,
              beneficiary: room.collectionBeneficiary ?? '',
              roomId: room.id,
              currencyCode: room.ticketCurrency,
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _scheduleReminder(context),
            icon: const Text('🔔', style: TextStyle(fontSize: 13)),
            label: Text(AppLocalizations.of(context)!.remindLater,
                style: DNText.sans(size: 12, color: dn.onSurface),),
            style: OutlinedButton.styleFrom(
              foregroundColor: dn.onSurface,
              side: BorderSide(color: dn.onSurface4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(BuildContext context, DateTime d) {
    final month = DateFormat('MMM', LocaleHelper.getDateFormatLocale(context)).format(d);
    return '${d.day} $month · '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  /// « Me le rappeler » (§1a) : programme une notification locale au début du
  /// salon et confirme à l'utilisateur.
  Future<void> _scheduleReminder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final at = room.scheduledAt;
    if (at != null && at.isAfter(DateTime.now())) {
      await NotificationService().scheduleNotification(
        id: room.id.hashCode & 0x7fffffff,
        title: room.title,
        body: l10n.audioRoomsStartingSoon,
        scheduledDate: at,
      );
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.audioRoomsReminderSet)),
    );
  }
}

// ─── FAB & schedule button ────────────────────────────────────────────────────

class _OpenRoomButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OpenRoomButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: DNColors.terra,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Même blanc que le libellé du bouton, qui utilise déjà
              // DNColors.paper : les deux se répondent sur l'aplat terra.
              const AppIcon(AppIcon.mic, color: DNColors.paper, size: 18),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.audioRoomOpenRoom,
                style: DNText.sans(
                    size: 14, w: FontWeight.w600, color: DNColors.paper,),
              ),
            ],
          ),
        ),
      );
}

class _ScheduleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScheduleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: dn.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: dn.onSurface4),
        ),
        alignment: Alignment.center,
        child: Text(
          '📅 ${AppLocalizations.of(context)!.audioRoomsScheduleButton}',
          style: DNText.sans(size: 12, w: FontWeight.w500, color: dn.onSurface),
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _AvatarStack extends StatelessWidget {
  final List<String> names;

  const _AvatarStack({required this.names});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final visible = names.take(3).toList();
    return SizedBox(
      width: 20.0 + (visible.length - 1) * 14,
      height: 20,
      child: Stack(
        children: visible.asMap().entries.map((e) {
          return Positioned(
            left: e.key * 14.0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: dn.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: dn.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                (e.value.isEmpty ? '?' : e.value[0]).toUpperCase(),
                style: DNText.mono(size: 7, color: dn.onSurface2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final double price;

  /// Devise du billet (`AudioRoomEntity.ticketCurrency`). Le prix s'affichait
  /// en € en dur : un salon facturé en XOF s'annonçait en € dans la liste puis
  /// en XOF dans la feuille d'achat, qui elle respecte déjà la devise réelle.
  final String? currencyCode;

  const _PricePill({required this.price, this.currencyCode});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: DNColors.ochre,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          CurrencyService.instance.format(
            price,
            CurrencyExtension.fromCode(currencyCode ?? 'EUR'),
          ),
          style: DNText.mono(size: 9, color: DNColors.paper),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String sub;

  /// Cartes de sortie (maquette 2e). L'état vide se contentait d'un emoji et
  /// de deux lignes : rien à faire depuis là, alors que c'est précisément le
  /// moment où l'utilisateur a besoin d'une action.
  final bool showActions;

  const _EmptyState({
    required this.message,
    required this.sub,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎙', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            message,
            style: DNText.serif(size: 18, color: dn.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: DNText.mono(size: 10, color: dn.onSurface3),
            textAlign: TextAlign.center,
          ),
          if (showActions) ...[
            const SizedBox(height: 24),
            _EmptyActionCard(
              emoji: '🎤',
              title: l10n.audioRoomOpenRoom,
              hint: l10n.audioRoomOpenRoomHint,
              accent: DNColors.terra,
              onTap: () => context.push('/audio-rooms/create'),
            ),
            const SizedBox(height: 10),
            _EmptyActionCard(
              emoji: '📚',
              title: l10n.heritageOralTitle,
              hint: l10n.heritageOralHint,
              accent: DNColors.ochre,
              onTap: () => context.push('/audio-rooms/heritage'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyActionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String hint;
  final Color accent;
  final VoidCallback onTap;

  const _EmptyActionCard({
    required this.emoji,
    required this.title,
    required this.hint,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dn.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: DNText.sans(
                          size: 14, w: FontWeight.w600, color: dn.onSurface,),),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: DNText.mono(size: 9, color: dn.onSurface3),),
                ],
              ),
            ),
            AppIcon(AppIcon.chevronRight, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}
