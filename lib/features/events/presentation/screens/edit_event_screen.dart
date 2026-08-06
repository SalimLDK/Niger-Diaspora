import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../domain/entities/event_entity.dart';
import '../providers/event_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final EventEntity event;

  const EditEventScreen({super.key, required this.event});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;
  late final TextEditingController _onlineLinkController;
  late final TextEditingController _maxAttendeesController;

  late EventCategory _selectedCategory;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  late bool _isOnline;
  bool _isLoading = false;
  late List<String> _currentPosterUrls;
  final List<XFile> _newPosters = [];
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing event data
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(
      text: widget.event.description,
    );
    _locationController = TextEditingController(
      text: widget.event.isOnline ? '' : widget.event.location,
    );
    _addressController = TextEditingController(
      text: widget.event.address ?? '',
    );
    _onlineLinkController = TextEditingController(
      text: widget.event.onlineLink ?? '',
    );
    _maxAttendeesController = TextEditingController(
      text:
          widget.event.maxAttendees > 0
              ? widget.event.maxAttendees.toString()
              : '',
    );

    _selectedCategory = widget.event.category;
    _startDate = widget.event.startDate;
    _startTime = TimeOfDay(
      hour: widget.event.startDate.hour,
      minute: widget.event.startDate.minute,
    );
    _endDate = widget.event.endDate;
    if (widget.event.endDate != null) {
      _endTime = TimeOfDay(
        hour: widget.event.endDate!.hour,
        minute: widget.event.endDate!.minute,
      );
    }
    _isOnline = widget.event.isOnline;
  }

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

  Future<void> _pickPosters() async {
    try {
      final totalPosters = _currentPosterUrls.length + _newPosters.length;
      final remaining = 5 - totalPosters;

      if (remaining <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.eventPosterLimit),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _newPosters.addAll(images.take(remaining));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la s\u00e9lection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteExistingPoster(int index) async {
    final url = _currentPosterUrls[index];
    setState(() => _isLoading = true);

    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.deleteEventPoster(widget.event.id, url);

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (_) {
        setState(() => _currentPosterUrls.removeAt(index));
      },
    );

    setState(() => _isLoading = false);
  }

  void _removeNewPoster(int index) {
    setState(() => _newPosters.removeAt(index));
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    final successMessage = l10n.eventUpdatedSuccess;
    final errorMessage = l10n.eventUpdateError;
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

    final updatedEvent = EventEntity(
      id: widget.event.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startDate: startDateTime,
      endDate: endDateTime,
      location: _isOnline ? onlineLabel : _locationController.text.trim(),
      address:
          _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
      organizerId: widget.event.organizerId,
      organizerName: widget.event.organizerName,
      organizerPhotoUrl: widget.event.organizerPhotoUrl,
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
      attendeeIds: widget.event.attendeeIds,
      posterUrls: _currentPosterUrls,
      recapPhotoUrls: widget.event.recapPhotoUrls,
      recapDescription: widget.event.recapDescription,
      recapCreatedAt: widget.event.recapCreatedAt,
      createdAt: widget.event.createdAt,
    );

    final success = await ref
        .read(myEventsNotifierProvider.notifier)
        .updateEvent(updatedEvent);

    setState(() => _isLoading = false);

    if (success && mounted) {
      // Upload new posters if any
      if (_newPosters.isNotEmpty) {
        final repository = ref.read(eventRepositoryProvider);
        for (final poster in _newPosters) {
          await repository.uploadEventPoster(widget.event.id, poster.path);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: context.adaptiveSecondaryColor,
        ),
      );
      // Refresh events list
      ref.read(eventsNotifierProvider.notifier).refresh();
      // Also update the detail view
      ref.read(eventDetailNotifierProvider.notifier).loadEvent(widget.event.id);
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
        title: Text(l10n.editEvent),
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

            // Affiches de l'événement
            _buildLabel('Affiches de l\'événement'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'G\u00e9rer les affiches (${_currentPosterUrls.length + _newPosters.length}/5)',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textTertiaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Existing posters
                  if (_currentPosterUrls.isNotEmpty) ...[
                    Text(
                      l10n.eventCurrentPosters,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                      itemCount: _currentPosterUrls.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _currentPosterUrls[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _deleteExistingPoster(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // New posters
                  if (_newPosters.isNotEmpty) ...[
                    Text(
                      l10n.eventNewPosters,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                      itemCount: _newPosters.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_newPosters[index].path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeNewPoster(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Add button
                  if (_currentPosterUrls.length + _newPosters.length < 5)
                    Center(
                      child: TextButton.icon(
                        onPressed: _pickPosters,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(
                          _currentPosterUrls.isEmpty && _newPosters.isEmpty
                              ? 'S\u00e9lectionner des images'
                              : l10n.eventAddImages,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: context.adaptivePrimaryColor,
                        ),
                      ),
                    ),
                ],
              ),
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
                    activeThumbColor: context.adaptivePrimaryColor,
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

            // Bouton modifier
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateEvent,
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
                          l10n.saveModifications,
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
