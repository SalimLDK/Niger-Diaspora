import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../domain/entities/event_entity.dart';
import '../providers/event_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  EventCategory? _selectedCategory;
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

          const SizedBox(height: 16),

          // Events List with Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UpcomingEventsTab(
                  onCategoryChange: () {
                    setState(() => _selectedCategory = null);
                  },
                ),
                _PastEventsTab(
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
  final VoidCallback onCategoryChange;

  const _UpcomingEventsTab({required this.onCategoryChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final eventsState = ref.watch(eventsNotifierProvider);

    return eventsState.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: LoadingIndicator()),
      error:
          (error, _) => CustomErrorWidget(
            message: error.toString(),
            onRetry: () => ref.read(eventsNotifierProvider.notifier).refresh(),
          ),
      data: (events) {
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

        return RefreshIndicator(
          onRefresh: () => ref.read(eventsNotifierProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _EventCard(
                event: event,
                onTap: () => context.push('/events/${event.id}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _PastEventsTab extends ConsumerWidget {
  final VoidCallback onCategoryChange;

  const _PastEventsTab({required this.onCategoryChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final eventsState = ref.watch(pastEventsNotifierProvider);

    return eventsState.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: LoadingIndicator()),
      error:
          (error, _) => CustomErrorWidget(
            message: error.toString(),
            onRetry:
                () => ref.read(pastEventsNotifierProvider.notifier).refresh(),
          ),
      data: (events) {
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

class _EventCard extends StatelessWidget {
  final EventEntity event;
  final VoidCallback onTap;
  final bool isPast;

  const _EventCard({
    required this.event,
    required this.onTap,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
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
                  // Default icon if no image
                  if (event.posterUrls.isEmpty)
                    Center(
                      child: Icon(
                        Icons.event,
                        size: 60,
                        color: context.onPrimaryColor,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.seeMore,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.onPrimaryColor,
                          ),
                        ),
                      ),
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
