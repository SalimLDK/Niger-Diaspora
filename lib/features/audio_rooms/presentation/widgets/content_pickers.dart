import 'package:flutter/material.dart';

import '../../../../shared/widgets/dn_sheet_handle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../events/presentation/providers/event_provider.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../embassies/presentation/providers/embassies_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Bottom sheet for picking an event to link to an audio room
class EventPickerBottomSheet extends ConsumerStatefulWidget {
  final String? selectedEventId;
  final void Function(String? eventId, String? eventTitle) onSelect;

  const EventPickerBottomSheet({
    super.key,
    this.selectedEventId,
    required this.onSelect,
  });

  @override
  ConsumerState<EventPickerBottomSheet> createState() =>
      _EventPickerBottomSheetState();
}

class _EventPickerBottomSheetState
    extends ConsumerState<EventPickerBottomSheet> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: DnSheetHandle(),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const AppIcon(AppIcon.event, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Lier un evenement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.selectedEventId != null)
                      TextButton(
                        onPressed: () {
                          widget.onSelect(null, null);
                          Navigator.pop(context);
                        },
                        child: Text(AppLocalizations.of(context)!.remove),
                      ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchEventHint,
                    prefixIcon: const AppIcon(AppIcon.search, color: AppColors.secondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 12),
              // List
              Expanded(
                child: eventsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, _) => Center(
                        child: Text(
                          ErrorHandler.instance.getShortMessage(
                            ErrorHandler.instance.handleException(error),
                          ),
                        ),
                      ),
                  data: (events) {
                    final filteredEvents =
                        events.where((e) {
                          if (_searchQuery.isEmpty) return true;
                          final query = _searchQuery.toLowerCase();
                          return e.title.toLowerCase().contains(query) ||
                              e.location.toLowerCase().contains(query);
                        }).toList();

                    if (filteredEvents.isEmpty) {
                      return Center(
                        child: Text(AppLocalizations.of(context)!.noEventFound),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        final isSelected = event.id == widget.selectedEventId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color:
                              isSelected
                                  ? AppColors.secondary.withValues(alpha: 0.1)
                                  : null,
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(
                                  event.category,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getCategoryIcon(event.category),
                                color: _getCategoryColor(event.category),
                              ),
                            ),
                            title: Text(
                              event.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'EEE d MMM, HH:mm',
                                    'fr_FR',
                                  ).format(event.startDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing:
                                isSelected
                                    ? const AppIcon(AppIcon.checkCircle,
                                      color: AppColors.secondary,
                                    )
                                    : const AppIcon(AppIcon.chevronRight, color: AppColors.secondary),
                            onTap: () {
                              widget.onSelect(event.id, event.title);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(EventCategory category) {
    return switch (category) {
      EventCategory.networking => Icons.people_alt_rounded,
      EventCategory.cultural => Icons.theater_comedy_rounded,
      EventCategory.business => Icons.business_center_rounded,
      EventCategory.educational => Icons.school_rounded,
      EventCategory.sports => Icons.sports_soccer_rounded,
      EventCategory.charity => Icons.volunteer_activism_rounded,
      EventCategory.social => Icons.celebration_rounded,
      EventCategory.other => Icons.event_rounded,
    };
  }

  Color _getCategoryColor(EventCategory category) {
    return switch (category) {
      EventCategory.networking => Colors.blue,
      EventCategory.cultural => Colors.purple,
      EventCategory.business => Colors.orange,
      EventCategory.educational => Colors.green,
      EventCategory.sports => Colors.red,
      EventCategory.charity => Colors.pink,
      EventCategory.social => Colors.teal,
      EventCategory.other => Colors.grey,
    };
  }
}

/// Bottom sheet for picking a group to link to an audio room
class GroupPickerBottomSheet extends ConsumerStatefulWidget {
  final String? selectedGroupId;
  final void Function(String? groupId, String? groupName) onSelect;

  const GroupPickerBottomSheet({
    super.key,
    this.selectedGroupId,
    required this.onSelect,
  });

  @override
  ConsumerState<GroupPickerBottomSheet> createState() =>
      _GroupPickerBottomSheetState();
}

class _GroupPickerBottomSheetState
    extends ConsumerState<GroupPickerBottomSheet> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: DnSheetHandle(),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const AppIcon(
                      AppIcon.groups,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.audioRoomLinkGroup,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.selectedGroupId != null)
                      TextButton(
                        onPressed: () {
                          widget.onSelect(null, null);
                          Navigator.pop(context);
                        },
                        child: Text(AppLocalizations.of(context)!.remove),
                      ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchGroupHint,
                    prefixIcon: const AppIcon(AppIcon.search, color: AppColors.secondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 12),
              // List
              Expanded(
                child: groupsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, _) => Center(
                        child: Text(
                          ErrorHandler.instance.getShortMessage(
                            ErrorHandler.instance.handleException(error),
                          ),
                        ),
                      ),
                  data: (groups) {
                    final filteredGroups =
                        groups.where((g) {
                          if (_searchQuery.isEmpty) return true;
                          final query = _searchQuery.toLowerCase();
                          return g.name.toLowerCase().contains(query) ||
                              g.description.toLowerCase().contains(query);
                        }).toList();

                    if (filteredGroups.isEmpty) {
                      return Center(
                        child: Text(AppLocalizations.of(context)!.noGroupFound),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        final isSelected = group.id == widget.selectedGroupId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color:
                              isSelected
                                  ? AppColors.secondary.withValues(alpha: 0.1)
                                  : null,
                          child: ListTile(
                            leading:
                                group.imageUrl != null
                                    ? CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        group.imageUrl!,
                                      ),
                                    )
                                    : CircleAvatar(
                                      backgroundColor: _getGroupCategoryColor(
                                        group.category,
                                      ).withValues(alpha: 0.1),
                                      child: Icon(
                                        _getGroupCategoryIcon(group.category),
                                        color: _getGroupCategoryColor(
                                          group.category,
                                        ),
                                      ),
                                    ),
                            title: Text(
                              group.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.category.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${group.memberIds.length} membres',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing:
                                isSelected
                                    ? const AppIcon(AppIcon.checkCircle,
                                      color: AppColors.secondary,
                                    )
                                    : const AppIcon(AppIcon.chevronRight, color: AppColors.secondary),
                            onTap: () {
                              widget.onSelect(group.id, group.name);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getGroupCategoryIcon(GroupCategory category) {
    return switch (category) {
      GroupCategory.professional => Icons.work_rounded,
      GroupCategory.cultural => Icons.theater_comedy_rounded,
      GroupCategory.sports => Icons.sports_soccer_rounded,
      GroupCategory.students => Icons.school_rounded,
      GroupCategory.entrepreneurs => Icons.rocket_launch_rounded,
      GroupCategory.women => Icons.woman_rounded,
      GroupCategory.youth => Icons.child_care_rounded,
      GroupCategory.regional => Icons.location_city_rounded,
      GroupCategory.other => Icons.groups_rounded,
    };
  }

  Color _getGroupCategoryColor(GroupCategory category) {
    return switch (category) {
      GroupCategory.professional => Colors.blue,
      GroupCategory.cultural => Colors.purple,
      GroupCategory.sports => Colors.red,
      GroupCategory.students => Colors.green,
      GroupCategory.entrepreneurs => Colors.orange,
      GroupCategory.women => Colors.pink,
      GroupCategory.youth => Colors.teal,
      GroupCategory.regional => Colors.brown,
      GroupCategory.other => Colors.grey,
    };
  }
}

/// Bottom sheet for picking an embassy to link to an audio room
class EmbassyPickerBottomSheet extends ConsumerStatefulWidget {
  final String? selectedEmbassyId;
  final void Function(String? embassyId, String? embassyName) onSelect;

  const EmbassyPickerBottomSheet({
    super.key,
    this.selectedEmbassyId,
    required this.onSelect,
  });

  @override
  ConsumerState<EmbassyPickerBottomSheet> createState() =>
      _EmbassyPickerBottomSheetState();
}

class _EmbassyPickerBottomSheetState
    extends ConsumerState<EmbassyPickerBottomSheet> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final embassiesController = ref.watch(embassiesControllerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: DnSheetHandle(),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const AppIcon(
                      AppIcon.bank,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.audioRoomLinkEmbassy,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.selectedEmbassyId != null)
                      TextButton(
                        onPressed: () {
                          widget.onSelect(null, null);
                          Navigator.pop(context);
                        },
                        child: Text(AppLocalizations.of(context)!.remove),
                      ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchEmbassyHint,
                    prefixIcon: const AppIcon(AppIcon.search, color: AppColors.secondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 12),
              // List
              Expanded(
                child: embassiesController.embassies.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, _) => Center(
                        child: Text(
                          ErrorHandler.instance.getShortMessage(
                            ErrorHandler.instance.handleException(error),
                          ),
                        ),
                      ),
                  data: (embassies) {
                    final filteredEmbassies =
                        embassies.where((e) {
                          if (_searchQuery.isEmpty) return true;
                          final query = _searchQuery.toLowerCase();
                          return e.name.toLowerCase().contains(query) ||
                              e.country.toLowerCase().contains(query) ||
                              e.city.toLowerCase().contains(query);
                        }).toList();

                    if (filteredEmbassies.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)!.noEmbassyFound,
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredEmbassies.length,
                      itemBuilder: (context, index) {
                        final embassy = filteredEmbassies[index];
                        final isSelected =
                            embassy.id == widget.selectedEmbassyId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color:
                              isSelected
                                  ? AppColors.secondary.withValues(alpha: 0.1)
                                  : null,
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  embassy.imageUrl != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          embassy.imageUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : const AppIcon(
                                        AppIcon.bank,
                                        color: AppColors.primary,
                                      ),
                            ),
                            title: Text(
                              embassy.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${embassy.city}, ${embassy.country}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            embassy.isVerified
                                                ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                                : Colors.orange.withValues(
                                                  alpha: 0.1,
                                                ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        embassy.isVerified
                                            ? AppLocalizations.of(context)!.audioRoomVerified
                                            : AppLocalizations.of(context)!.audioRoomNotVerified,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              embassy.isVerified
                                                  ? Colors.green
                                                  : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      embassy.type == 'embassy'
                                          ? AppLocalizations.of(context)!.embassyTypeEmbassy
                                          : AppLocalizations.of(context)!.embassyTypeConsulate,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing:
                                isSelected
                                    ? const AppIcon(AppIcon.checkCircle,
                                      color: AppColors.secondary,
                                    )
                                    : const AppIcon(AppIcon.chevronRight, color: AppColors.secondary),
                            onTap: () {
                              widget.onSelect(embassy.id, embassy.name);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Helper function to show event picker
Future<void> showEventPicker({
  required BuildContext context,
  String? selectedEventId,
  required void Function(String? eventId, String? eventTitle) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => EventPickerBottomSheet(
          selectedEventId: selectedEventId,
          onSelect: onSelect,
        ),
  );
}

/// Helper function to show group picker
Future<void> showGroupPicker({
  required BuildContext context,
  String? selectedGroupId,
  required void Function(String? groupId, String? groupName) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => GroupPickerBottomSheet(
          selectedGroupId: selectedGroupId,
          onSelect: onSelect,
        ),
  );
}

/// Helper function to show embassy picker
Future<void> showEmbassyPicker({
  required BuildContext context,
  String? selectedEmbassyId,
  required void Function(String? embassyId, String? embassyName) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => EmbassyPickerBottomSheet(
          selectedEmbassyId: selectedEmbassyId,
          onSelect: onSelect,
        ),
  );
}
