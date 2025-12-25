import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/event_entity.dart';
import '../providers/event_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _onlineLinkController = TextEditingController();
  final _maxAttendeesController = TextEditingController();

  EventCategory _selectedCategory = EventCategory.other;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isOnline = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _onlineLinkController.dispose();
    _maxAttendeesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: context.adaptivePrimaryColor,
                onPrimary: context.onPrimaryColor,
                surface: context.surfaceColor,
                onSurface: context.textPrimaryColor,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: context.adaptivePrimaryColor,
                onPrimary: context.onPrimaryColor,
                surface: context.surfaceColor,
                onSurface: context.textPrimaryColor,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: context.adaptivePrimaryColor,
                onPrimary: context.onPrimaryColor,
                surface: context.surfaceColor,
                onSurface: context.textPrimaryColor,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime,
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: context.adaptivePrimaryColor,
                onPrimary: context.onPrimaryColor,
                surface: context.surfaceColor,
                onSurface: context.textPrimaryColor,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final l10n = AppLocalizations.of(context)!;
    final successMessage = l10n.eventCreatedSuccess;
    final errorMessage = l10n.eventCreationError;
    final onlineLabel = l10n.online;

    setState(() => _isLoading = true);

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    DateTime? endDateTime;
    if (_endDate != null && _endTime != null) {
      endDateTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );
    }

    final event = EventEntity(
      id: '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startDate: startDateTime,
      endDate: endDateTime,
      location: _isOnline ? onlineLabel : _locationController.text.trim(),
      address:
          _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
      organizerId: currentUser.id,
      organizerName: currentUser.displayName,
      organizerPhotoUrl: currentUser.photoUrl,
      category: _selectedCategory,
      isOnline: _isOnline,
      onlineLink:
          _isOnline && _onlineLinkController.text.trim().isNotEmpty
              ? _onlineLinkController.text.trim()
              : null,
      maxAttendees:
          _maxAttendeesController.text.isNotEmpty
              ? int.tryParse(_maxAttendeesController.text) ?? 0
              : 0,
      attendeeIds: [currentUser.id],
      createdAt: DateTime.now(),
    );

    final success = await ref
        .read(myEventsNotifierProvider.notifier)
        .createEvent(event);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: context.adaptiveSecondaryColor,
        ),
      );
      // Refresh events list
      ref.read(eventsNotifierProvider.notifier).refresh();
      // Refresh home stats
      ref.read(homeStatsNotifierProvider.notifier).refresh();
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('dd MMM yyyy', locale);
    final timeFormat = DateFormat('HH:mm', locale);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.createEvent),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Titre
            _buildLabel(l10n.eventTitleRequired),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(l10n.eventTitleHint, context),
              style: TextStyle(color: context.textPrimaryColor),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.eventTitleRequiredError;
                }
                if (value.trim().length < 5) {
                  return l10n.eventTitleTooShort;
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Description
            _buildLabel(l10n.descriptionRequired),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(l10n.descriptionHint, context),
              style: TextStyle(color: context.textPrimaryColor),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.descriptionRequiredError;
                }
                if (value.trim().length < 20) {
                  return l10n.descriptionTooShort;
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Catégorie
            _buildLabel(l10n.category),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<EventCategory>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: context.surfaceColor,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: context.textPrimaryColor,
                  ),
                  items:
                      EventCategory.values
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(
                                category.label,
                                style: TextStyle(
                                  color: context.textPrimaryColor,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Date et heure de début
            _buildLabel(l10n.startDateTime),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dateFormat.format(_startDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectStartTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            timeFormat.format(
                              DateTime(
                                2024,
                                1,
                                1,
                                _startTime.hour,
                                _startTime.minute,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Date et heure de fin (optionnel)
            _buildLabel(l10n.endDateTimeOptional),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color:
                                _endDate != null
                                    ? context.adaptivePrimaryColor
                                    : context.textTertiaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _endDate != null
                                ? dateFormat.format(_endDate!)
                                : l10n.endDate,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  _endDate != null
                                      ? context.textPrimaryColor
                                      : context.textTertiaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _endDate != null ? _selectEndTime : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color:
                                _endTime != null
                                    ? context.adaptivePrimaryColor
                                    : context.textTertiaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _endTime != null
                                ? timeFormat.format(
                                  DateTime(
                                    2024,
                                    1,
                                    1,
                                    _endTime!.hour,
                                    _endTime!.minute,
                                  ),
                                )
                                : l10n.endTime,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  _endTime != null
                                      ? context.textPrimaryColor
                                      : context.textTertiaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Événement en ligne
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.onlineEvent,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.onlineEventDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOnline,
                    onChanged: (value) => setState(() => _isOnline = value),
                    activeColor: context.adaptivePrimaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Lieu ou lien
            if (_isOnline) ...[
              _buildLabel(l10n.videoConferenceLink),
              const SizedBox(height: 8),
              TextFormField(
                controller: _onlineLinkController,
                decoration: _inputDecoration(
                  l10n.videoConferenceLinkHint,
                  context,
                ),
                style: TextStyle(color: context.textPrimaryColor),
                keyboardType: TextInputType.url,
              ),
            ] else ...[
              _buildLabel(l10n.locationRequired),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: _inputDecoration(l10n.locationHint, context),
                style: TextStyle(color: context.textPrimaryColor),
                validator: (value) {
                  if (!_isOnline && (value == null || value.trim().isEmpty)) {
                    return l10n.locationRequiredError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel(l10n.addressOptional),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: _inputDecoration(l10n.addressHint, context),
                style: TextStyle(color: context.textPrimaryColor),
              ),
            ],

            const SizedBox(height: 20),

            // Nombre max de participants
            _buildLabel(l10n.maxAttendeesOptional),
            const SizedBox(height: 8),
            TextFormField(
              controller: _maxAttendeesController,
              decoration: _inputDecoration(l10n.maxAttendeesHint, context),
              style: TextStyle(color: context.textPrimaryColor),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.unlimitedAttendees,
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
            ),

            const SizedBox(height: 32),

            // Bouton créer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.adaptivePrimaryColor,
                  foregroundColor: context.onPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: context.onPrimaryColor,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          l10n.createEventButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.textPrimaryColor,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, BuildContext context) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textTertiaryColor),
      filled: true,
      fillColor: context.surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.adaptivePrimaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
