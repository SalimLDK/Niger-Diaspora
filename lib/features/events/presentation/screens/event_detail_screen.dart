import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:carousel_slider/carousel_slider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/event_entity.dart';
import '../providers/event_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/analytics_service.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  final EventEntity? initialEvent;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.initialEvent,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isLoading = false;
  int _currentPosterIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialEvent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(eventDetailNotifierProvider.notifier)
            .loadEvent(widget.eventId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final eventAsync = ref.watch(eventDetailNotifierProvider);

    final event = widget.initialEvent ?? eventAsync.valueOrNull;

    if (event == null) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final isAttending = event.attendeeIds.contains(currentUser?.id);
    final isOrganizer = event.organizerId == currentUser?.id;
    final dateFormat = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm', 'fr_FR');

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar avec image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceColor.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: context.textPrimaryColor),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isOrganizer)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.surfaceColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit, color: context.textPrimaryColor),
                  ),
                  onPressed: () {
                    context.push('/events/${event.id}/edit', extra: event);
                  },
                ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.surfaceColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share, color: context.textPrimaryColor),
                ),
                onPressed: () {
                  AnalyticsService.instance.logEvent(
                    name: 'share_event',
                    parameters: {'event_id': event.id},
                  );
                  _shareEvent(event);
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster Carousel or Single Image
                  event.posterUrls.length > 1
                      ? Stack(
                        children: [
                          CarouselSlider(
                            options: CarouselOptions(
                              height: double.infinity,
                              viewportFraction: 1.0,
                              enableInfiniteScroll: event.posterUrls.length > 2,
                              onPageChanged: (index, reason) {
                                setState(() => _currentPosterIndex = index);
                              },
                            ),
                            items:
                                event.posterUrls.map((url) {
                                  return Builder(
                                    builder: (BuildContext context) {
                                      return Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: NetworkImage(url),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                          ),
                          // Page Indicator Dots
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children:
                                  event.posterUrls.asMap().entries.map((entry) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            _currentPosterIndex == entry.key
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                  alpha: 0.4,
                                                ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ],
                      )
                      : Container(
                        decoration: BoxDecoration(
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
                        child:
                            event.posterUrls.isEmpty
                                ? Center(
                                  child: Icon(
                                    Icons.event,
                                    size: 80,
                                    color: context.onPrimaryColor,
                                  ),
                                )
                                : null,
                      ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  // Category and online badge
                  Positioned(
                    top: 100,
                    left: 16,
                    child: Row(
                      children: [
                        Container(
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
                        if (event.isOnline) ...[
                          const SizedBox(width: 8),
                          Container(
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
                                  l10n.online,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.onSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date et heure
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: context.shadowColor,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.adaptivePrimaryColor.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateFormat.format(event.startDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.endDate != null
                                    ? '${timeFormat.format(event.startDate)} - ${timeFormat.format(event.endDate!)}'
                                    : l10n.startingFrom(
                                      timeFormat.format(event.startDate),
                                    ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Lieu
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: context.shadowColor,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.adaptiveSecondaryColor.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            event.isOnline ? Icons.videocam : Icons.location_on,
                            color: context.adaptiveSecondaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.location,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              if (event.address != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  event.address!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.textTertiaryColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (event.isOnline && event.onlineLink != null)
                          IconButton(
                            icon: Icon(
                              Icons.open_in_new,
                              color: context.adaptivePrimaryColor,
                            ),
                            onPressed: () async {
                              final uri = Uri.parse(event.onlineLink!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    l10n.aboutEvent,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondaryColor,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Organisateur
                  Text(
                    l10n.organizer,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: context.adaptivePrimaryGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              event.organizerPhotoUrl != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      event.organizerPhotoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Icon(
                                            Icons.person,
                                            color: context.onPrimaryColor,
                                          ),
                                    ),
                                  )
                                  : Icon(
                                    Icons.person,
                                    color: context.onPrimaryColor,
                                  ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.organizerName ?? l10n.organizer,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.organizer,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Participants
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.participantsTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaceVariantColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.maxAttendees > 0
                              ? '${event.attendeeIds.length}/${event.maxAttendees}'
                              : l10n.participants(event.attendeeIds.length),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (event.attendeeIds.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: context.textTertiaryColor.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noParticipantsYet,
                            style: TextStyle(color: context.textTertiaryColor),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          // Stack of participant avatars
                          SizedBox(
                            width: 80,
                            height: 40,
                            child: Stack(
                              children: List.generate(
                                event.attendeeIds.length.clamp(0, 3),
                                (index) => Positioned(
                                  left: index * 20.0,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: context.adaptivePrimaryGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: context.surfaceColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: context.onPrimaryColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (event.attendeeIds.length > 3)
                            Text(
                              l10n.othersMore(event.attendeeIds.length - 3),
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Recap Section (if exists)
                  if (event.recapDescription != null &&
                      event.recapPhotoUrls.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Icon(
                          Icons.photo_library,
                          size: 20,
                          color: context.adaptivePrimaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Récapitulatif',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            try {
                              final shareText = '''
📸 ${event.title} - R\u00e9capitulatif

${event.recapDescription}

Voir plus de d\u00e9tails sur DiaspoNiger
''';
                              await Share.share(shareText);
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Erreur lors du partage'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            Icons.share,
                            color: context.adaptivePrimaryColor,
                          ),
                          tooltip: 'Partager le récapitulatif',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.recapDescription!,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: event.recapPhotoUrls.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            event.recapPhotoUrls[index],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: context.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: context.adaptivePrimaryColor,
                  ),
                )
                : isOrganizer
                ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteEvent(event.id),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: Text(
                          l10n.delete,
                          style: const TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(
                            '/events/${event.id}/edit',
                            extra: event,
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: Text(l10n.edit),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.adaptivePrimaryColor,
                          foregroundColor: context.onPrimaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                )
                : isAttending
                ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () => _cancelAttendance(event.id, currentUser!.id),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: Text(
                          l10n.cancel,
                          style: const TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _addToCalendar(event),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(l10n.calendar),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.adaptivePrimaryColor,
                          foregroundColor: context.onPrimaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                )
                : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _canAttend(event)
                            ? () => _attendEvent(event.id, currentUser!.id)
                            : null,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _canAttend(event) ? l10n.participate : l10n.full,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: context.onPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
      ),
    );
  }

  bool _canAttend(EventEntity event) {
    if (event.maxAttendees == 0) return true;
    return event.attendeeIds.length < event.maxAttendees;
  }

  Future<void> _attendEvent(String eventId, String userId) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    final success = await ref
        .read(eventDetailNotifierProvider.notifier)
        .attendEvent(eventId, userId);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.registrationConfirmed),
          backgroundColor: context.adaptiveSecondaryColor,
        ),
      );
    }
  }

  Future<void> _cancelAttendance(String eventId, String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.cancelParticipation),
            content: Text(l10n.cancelParticipationConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.no),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.yesCancel),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(eventDetailNotifierProvider.notifier)
        .cancelAttendance(eventId, userId);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.participationCancelled)));
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deleteEvent),
            content: Text(l10n.deleteEventConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(myEventsNotifierProvider.notifier)
        .deleteEvent(eventId);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.eventDeleted)));
      // Refresh events list
      ref.read(eventsNotifierProvider.notifier).refresh();
      context.pop();
    }
  }

  Future<void> _addToCalendar(EventEntity event) async {
    final l10n = AppLocalizations.of(context)!;
    final calendarEvent = Event(
      title: event.title,
      description:
          '${event.description}\n\n${l10n.organizedBy} ${event.organizerName ?? "Diaspo Niger"}',
      location:
          event.isOnline ? (event.onlineLink ?? l10n.online) : event.location,
      startDate: event.startDate,
      endDate: event.endDate ?? event.startDate.add(const Duration(hours: 2)),
      allDay: false,
    );

    final success = await Add2Calendar.addEvent2Cal(calendarEvent);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.addedToCalendar : l10n.cannotAddToCalendar,
          ),
          backgroundColor:
              success ? context.adaptiveSecondaryColor : Colors.red,
        ),
      );
    }
  }

  void _shareEvent(EventEntity event) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('EEEE dd MMMM yyyy à HH:mm', 'fr_FR');

    final shareText = '''
🎉 ${event.title}

📅 ${dateFormat.format(event.startDate)}
📍 ${event.isOnline ? l10n.online : event.location}

${event.description}

${event.isOnline && event.onlineLink != null ? '🔗 ${event.onlineLink}' : ''}

Niger Diaspora
''';

    Share.share(shareText.trim(), subject: event.title);
  }
}
