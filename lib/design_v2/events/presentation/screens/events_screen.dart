import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../features/events/domain/entities/event_entity.dart';
import '../../../../features/events/presentation/providers/event_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/profile/domain/entities/profile_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/geo_utils.dart';

/// Filtres rapides (§13a), indépendants de la catégorie : appliqués côté
/// client sur la liste déjà chargée (pas de requête serveur supplémentaire).
enum _QuickFilter { nearMe, online, free }

const double _nearMeRadiusKm = 50.0;

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  EventCategory? _selectedCategory;
  final Set<_QuickFilter> _quickFilters = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventsNotifierProvider.notifier).refresh();
      ref.read(pastEventsNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleQuickFilter(_QuickFilter filter) {
    if (_quickFilters.contains(filter)) {
      _quickFilters.remove(filter);
    } else {
      _quickFilters.add(filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.eventsTitle),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add, color: context.adaptivePrimaryColor),
            ),
            onPressed: () => context.push('/events/create'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.adaptivePrimaryColor,
          labelColor: context.adaptivePrimaryColor,
          unselectedLabelColor: context.textTertiaryColor,
          tabs: [Tab(text: l10n.upcoming), Tab(text: l10n.past)],
        ),
      ),
      body: Column(
        children: [
          // Category Filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: l10n.all,
                  isSelected: _selectedCategory == null,
                  onTap: () {
                    setState(() => _selectedCategory = null);
                    if (_tabController.index == 0) {
                      ref
                          .read(eventsNotifierProvider.notifier)
                          .loadUpcomingEvents();
                    } else {
                      ref
                          .read(pastEventsNotifierProvider.notifier)
                          .loadPastEvents();
                    }
                  },
                ),
                ...EventCategory.values.map(
                  (category) => _CategoryChip(
                    label: category.label,
                    isSelected: _selectedCategory == category,
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      if (_tabController.index == 0) {
                        ref
                            .read(eventsNotifierProvider.notifier)
                            .loadEventsByCategory(category);
                      } else {
                        ref
                            .read(pastEventsNotifierProvider.notifier)
                            .loadPastEventsByCategory(category);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Filtres rapides (§13a) : Près de moi / En ligne / Gratuits —
          // multi-sélection, indépendants de la catégorie.
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _QuickFilterChip(
                  label: l10n.all,
                  isSelected: _quickFilters.isEmpty,
                  onTap: () => setState(_quickFilters.clear),
                ),
                _QuickFilterChip(
                  label: l10n.eventsNearMe,
                  isSelected: _quickFilters.contains(_QuickFilter.nearMe),
                  onTap: () => setState(
                    () => _toggleQuickFilter(_QuickFilter.nearMe),
                  ),
                ),
                _QuickFilterChip(
                  label: l10n.eventsOnline,
                  isSelected: _quickFilters.contains(_QuickFilter.online),
                  onTap: () => setState(
                    () => _toggleQuickFilter(_QuickFilter.online),
                  ),
                ),
                _QuickFilterChip(
                  label: l10n.eventsFree,
                  isSelected: _quickFilters.contains(_QuickFilter.free),
                  onTap: () => setState(
                    () => _toggleQuickFilter(_QuickFilter.free),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Events List with Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UpcomingEventsTab(
                  quickFilters: _quickFilters,
                  onCategoryChange: () {
                    setState(() => _selectedCategory = null);
                  },
                ),
                _PastEventsTab(
                  quickFilters: _quickFilters,
                  onCategoryChange: () {
                    setState(() => _selectedCategory = null);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventsTab extends ConsumerWidget {
  final Set<_QuickFilter> quickFilters;
  final VoidCallback onCategoryChange;

  const _UpcomingEventsTab({
    required this.quickFilters,
    required this.onCategoryChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final eventsState = ref.watch(eventsNotifierProvider);
    final myProfile = _myProfile(ref);

    return eventsState.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: LoadingIndicator()),
      error:
          (error, _) => CustomErrorWidget(
            message: error.toString(),
            onRetry: () => ref.read(eventsNotifierProvider.notifier).refresh(),
          ),
      data: (allEvents) {
        final events = _applyQuickFilters(allEvents, quickFilters, myProfile);
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 80,
                  color: context.textTertiaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noUpcomingEvents,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        // Regroupement « Cette semaine » / « Plus tard » (§13a).
        final now = DateTime.now();
        final weekEnd = now.add(const Duration(days: 7));
        final sorted = [...events]
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        final thisWeek =
            sorted.where((e) => e.startDate.isBefore(weekEnd)).toList();
        final later =
            sorted.where((e) => !e.startDate.isBefore(weekEnd)).toList();

        Widget card(EventEntity event) => _EventCard(
              event: event,
              onTap: () => context.push('/events/${event.id}'),
            );

        return RefreshIndicator(
          onRefresh: () => ref.read(eventsNotifierProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              if (thisWeek.isNotEmpty) ...[
                _EventsSectionHeader(label: l10n.thisWeek),
                ...thisWeek.map(card),
              ],
              if (later.isNotEmpty) ...[
                _EventsSectionHeader(label: l10n.later),
                ...later.map(card),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EventsSectionHeader extends StatelessWidget {
  final String label;

  const _EventsSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: context.textSecondaryColor,
        ),
      ),
    );
  }
}

class _PastEventsTab extends ConsumerWidget {
  final Set<_QuickFilter> quickFilters;
  final VoidCallback onCategoryChange;

  const _PastEventsTab({
    required this.quickFilters,
    required this.onCategoryChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final eventsState = ref.watch(pastEventsNotifierProvider);
    final myProfile = _myProfile(ref);

    return eventsState.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: LoadingIndicator()),
      error:
          (error, _) => CustomErrorWidget(
            message: error.toString(),
            onRetry:
                () => ref.read(pastEventsNotifierProvider.notifier).refresh(),
          ),
      data: (allEvents) {
        final events = _applyQuickFilters(allEvents, quickFilters, myProfile);
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: context.textTertiaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noPastEvents,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh:
              () => ref.read(pastEventsNotifierProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _EventCard(
                event: event,
                onTap: () => context.push('/events/${event.id}'),
                isPast: true,
              );
            },
          ),
        );
      },
    );
  }
}

/// Profil courant (pour le filtre "Près de moi") : lat/lng déjà chargées
/// ailleurs dans l'app, aucune requête supplémentaire ici.
ProfileEntity? _myProfile(WidgetRef ref) {
  final uid = ref.watch(currentUserProvider).valueOrNull?.id;
  if (uid == null) return null;
  return ref.watch(profileNotifierProvider(uid)).valueOrNull;
}

List<EventEntity> _applyQuickFilters(
  List<EventEntity> events,
  Set<_QuickFilter> filters,
  ProfileEntity? myProfile,
) {
  if (filters.isEmpty) return events;
  return events.where((event) {
    if (filters.contains(_QuickFilter.online) && !event.isOnline) {
      return false;
    }
    if (filters.contains(_QuickFilter.free) && !event.isFree) {
      return false;
    }
    if (filters.contains(_QuickFilter.nearMe)) {
      final myLat = myProfile?.latitude;
      final myLng = myProfile?.longitude;
      if (myLat == null ||
          myLng == null ||
          event.latitude == null ||
          event.longitude == null) {
        return false;
      }
      final distance = GeoUtils.calculateDistance(
        myLat,
        myLng,
        event.latitude!,
        event.longitude!,
      );
      if (distance > _nearMeRadiusKm) return false;
    }
    return true;
  }).toList();
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? context.adaptivePrimaryColor.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isSelected
                      ? context.adaptivePrimaryColor
                      : context.borderColor,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color:
                    isSelected
                        ? context.adaptivePrimaryColor
                        : context.textSecondaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? context.adaptivePrimaryColor
                    : context.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected
                      ? context.adaptivePrimaryColor
                      : context.borderColor,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isSelected
                        ? context.onPrimaryColor
                        : context.textSecondaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerStatefulWidget {
  final EventEntity event;
  final VoidCallback onTap;
  final bool isPast;

  const _EventCard({
    required this.event,
    required this.onTap,
    this.isPast = false,
  });

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _isJoining = false;

  bool _canAttend(EventEntity event) {
    if (event.maxAttendees == 0) return true;
    return event.attendeeIds.length < event.maxAttendees;
  }

  Future<void> _join(EventEntity event, String userId) async {
    if (_isJoining) return;
    setState(() => _isJoining = true);

    final result = await ref
        .read(eventRepositoryProvider)
        .attendEvent(event.id, userId);

    if (!mounted) return;
    setState(() => _isJoining = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (_) {
        // Rafraîchit la liste pour mettre à jour le compteur et l'état du bouton.
        ref.read(eventsNotifierProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.registrationConfirmed),
            backgroundColor: context.adaptiveSecondaryColor,
          ),
        );
      },
    );
  }

  // Bouton d'action par carte (§13a) : Participer / Complet / Inscrit,
  // au lieu d'un « Voir plus » générique. Le tap de la carte reste la
  // navigation vers le détail.
  Widget _buildCardAction(
    BuildContext context,
    EventEntity event,
    bool isPast,
    String? currentUserId,
  ) {
    final l10n = AppLocalizations.of(context)!;

    Widget pill({
      required String label,
      required Color background,
      required Color foreground,
      IconData? icon,
      VoidCallback? onTap,
    }) {
      return Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isJoining)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else if (icon != null) ...[
                  Icon(icon, size: 15, color: foreground),
                  const SizedBox(width: 6),
                ],
                if (!_isJoining)
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Événement passé : on garde une simple entrée vers le détail.
    if (isPast) {
      return pill(
        label: l10n.seeMore,
        background: context.adaptivePrimaryColor,
        foreground: context.onPrimaryColor,
        onTap: widget.onTap,
      );
    }

    final isAttending =
        currentUserId != null && event.attendeeIds.contains(currentUserId);

    if (isAttending) {
      // Déjà inscrit : état confirmé, tap → détail pour gérer.
      return pill(
        label: l10n.registered,
        background: context.adaptiveSecondaryColor.withValues(alpha: 0.15),
        foreground: context.adaptiveSecondaryColor,
        icon: Icons.check_circle,
        onTap: widget.onTap,
      );
    }

    if (!_canAttend(event)) {
      // Complet : bouton désactivé, pas d'action inline.
      return pill(
        label: l10n.full,
        background: context.textTertiaryColor.withValues(alpha: 0.15),
        foreground: context.textTertiaryColor,
      );
    }

    // Peut participer : inscription directe depuis la carte.
    return pill(
      label: l10n.participate,
      background: context.adaptivePrimaryColor,
      foreground: context.onPrimaryColor,
      icon: Icons.check,
      onTap:
          currentUserId == null
              ? widget.onTap
              : () => _join(event, currentUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final onTap = widget.onTap;
    final isPast = widget.isPast;
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm', 'fr_FR');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: context.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                gradient:
                    event.posterUrls.isEmpty
                        ? context.adaptivePrimaryGradient
                        : null,
                image:
                    event.posterUrls.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(event.posterUrls.first),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child: Stack(
                children: [
                  // Category Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.category.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.adaptivePrimaryColor,
                        ),
                      ),
                    ),
                  ),
                  // Past/Completed Badge
                  if (isPast)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.status.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Online Badge
                  if (event.isOnline && !isPast)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.adaptiveSecondaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam,
                              size: 14,
                              color: context.onSecondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.online,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.onSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Badge « Complet » quand l'événement est plein (refonte 13a).
                  if (!isPast &&
                      !event.isOnline &&
                      event.maxAttendees > 0 &&
                      event.attendeeIds.length >= event.maxAttendees)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC23E2D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_busy_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.full,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Badge « Gratuit » (§13a/25a) en haut à gauche.
                  if (!isPast && event.isFree)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_activity_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.eventFree,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Default icon if no image
                  if (event.posterUrls.isEmpty)
                    Center(
                      child: Icon(
                        Icons.event,
                        size: 60,
                        color: context.onPrimaryColor,
                      ),
                    ),
                  // Pastille de date flottante (§13a).
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      width: 52,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('dd').format(event.startDate),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: const Color(0xFFB85E24),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM', 'fr_FR')
                                .format(event.startDate)
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Event Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Date & Time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: context.adaptivePrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateFormat.format(event.startDate),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          Text(
                            timeFormat.format(event.startDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Location
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.adaptiveSecondaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 16,
                          color: context.adaptiveSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textSecondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Attendees & Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 18,
                            color: context.textTertiaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.participants(event.attendeeIds.length),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textTertiaryColor,
                            ),
                          ),
                        ],
                      ),
                      _buildCardAction(context, event, isPast, currentUserId),
                    ],
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
