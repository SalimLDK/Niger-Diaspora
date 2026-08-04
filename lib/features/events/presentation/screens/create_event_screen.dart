import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/event_entity.dart';
import '../providers/event_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/analytics_service.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/shared/widgets/dashed_border_painter.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';
import '../../../messages/presentation/providers/media_gallery_provider.dart'
    show groupConversationIdProvider;
import '../../../messages/presentation/providers/message_provider.dart'
    show sendMessageProvider;

class CreateEventScreen extends ConsumerStatefulWidget {
  final String? groupId;
  final String? groupName;
  final String? conversationId;

  /// Catégorie pré-sélectionnée (raccourcis de l'état vide « créer le premier »).
  final EventCategory? initialCategory;

  const CreateEventScreen({
    super.key,
    this.groupId,
    this.groupName,
    this.conversationId,
    this.initialCategory,
  });

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
  final _priceController = TextEditingController();

  EventCategory _selectedCategory = EventCategory.other;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isOnline = false;
  bool _isLoading = false;
  // Groupe uniquement : publier aussi l'event dans le fil public (écran
  // Événements global), en plus de la visibilité par défaut aux membres.
  bool _publishToFeed = false;
  final List<XFile> _selectedPosters = [];
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Catégorie pré-sélectionnée depuis les raccourcis de l'accueil.
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    // Pre-fill location from user's profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillLocation();
    });
  }

  void _prefillLocation() {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser != null) {
      final profile =
          ref.read(profileNotifierProvider(currentUser.id)).valueOrNull;
      if (profile != null && _locationController.text.isEmpty) {
        final parts = <String>[];
        if (profile.currentCity != null && profile.currentCity!.isNotEmpty) {
          parts.add(profile.currentCity!);
        }
        if (profile.currentCountry != null &&
            profile.currentCountry!.isNotEmpty) {
          parts.add(profile.currentCountry!);
        }
        if (parts.isNotEmpty) {
          setState(() {
            _locationController.text = parts.join(', ');
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _onlineLinkController.dispose();
    _maxAttendeesController.dispose();
    _priceController.dispose();
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
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          // Limit to 5 posters total
          final remaining = 5 - _selectedPosters.length;
          if (remaining > 0) {
            _selectedPosters.addAll(images.take(remaining));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorHandler.instance.getShortMessage(
                ErrorHandler.instance.handleException(e),
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removePoster(int index) {
    setState(() {
      _selectedPosters.removeAt(index);
    });
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final l10n = AppLocalizations.of(context)!;
    final successMessage = l10n.eventCreatedSuccess;
    final errorMessage = l10n.eventCreationError;
    final onlineLabel = l10n.online;

    // Récupérer le pays de l'utilisateur depuis son profil
    final profile =
        ref.read(profileNotifierProvider(currentUser.id)).valueOrNull;
    final userCountry = profile?.currentCountry;

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
      country: userCountry,
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
      price: _priceController.text.trim().isNotEmpty
          ? double.tryParse(
                _priceController.text.trim().replaceAll(',', '.'),
              ) ??
              0.0
          : 0.0,
      attendeeIds: [currentUser.id],
      groupId: widget.groupId,
      groupName: widget.groupName,
      conversationId: widget.conversationId,
      // Événement créé depuis une discussion (DM ou groupe) : privé par défaut
      // (participants du DM / membres du groupe) ; la case "publier dans le fil"
      // l'expose aussi à l'écran Événements global. Standalone : géré côté
      // requêtes/RLS.
      isPublic: (widget.groupId != null || widget.conversationId != null)
          ? _publishToFeed
          : false,
      createdAt: DateTime.now(),
    );

    final created = await ref
        .read(myEventsNotifierProvider.notifier)
        .createEvent(event);
    final success = created != null;

    if (success && _selectedPosters.isNotEmpty) {
      // Upload posters if event was created successfully
      final repository = ref.read(eventRepositoryProvider);
      for (final poster in _selectedPosters) {
        await repository.uploadEventPoster(created.id, poster.path);
      }
    }

    if (success) {
      AnalyticsService.instance.logEvent(
        name: 'create_event',
        parameters: {
          'category': _selectedCategory.name,
          'is_online': _isOnline,
          'has_posters': _selectedPosters.isNotEmpty,
        },
      );
      // Bulle événement dans la discussion d'origine (DM ou chat de groupe).
      await _postEventBubble(created);
    }

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

  /// Poste la bulle événement dans la discussion d'origine : la conversation
  /// DM directement, ou le chat du groupe (résolu via son id) pour un event
  /// de groupe. Ne bloque pas la création si l'envoi échoue (best-effort).
  Future<void> _postEventBubble(EventEntity created) async {
    String? targetConversationId = widget.conversationId;
    if (targetConversationId == null && widget.groupId != null) {
      targetConversationId = await ref.read(
        groupConversationIdProvider(widget.groupId!).future,
      );
    }
    if (targetConversationId == null) return;

    final eventData = <String, dynamic>{
      'eventId': created.id,
      'title': created.title,
      'startDate': created.startDate.toUtc().toIso8601String(),
      'location': created.location,
      'isOnline': created.isOnline,
    };

    try {
      await ref.read(sendMessageProvider.notifier).sendText(
            conversationId: targetConversationId,
            content: '📅 ${created.title}',
            eventData: eventData,
          );
    } catch (_) {
      // Non bloquant : l'event existe même si la bulle échoue à s'envoyer.
    }
  }

  /// Le formulaire contient-il quelque chose que fermer ferait perdre ?
  bool get _isDirty =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _addressController.text.trim().isNotEmpty ||
      _onlineLinkController.text.trim().isNotEmpty ||
      _maxAttendeesController.text.trim().isNotEmpty ||
      _priceController.text.trim().isNotEmpty ||
      _selectedPosters.isNotEmpty;

  /// ✕ de l'en-tête. La fiche affiche « Brouillon » à côté, mais rien n'est
  /// persisté : plutôt que de laisser croire à une reprise, on demande
  /// confirmation dès que le formulaire contient quelque chose.
  Future<void> _handleClose() async {
    if (!_isDirty) {
      if (mounted) context.pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Abandonner cet événement ?'),
            content: const Text(
              "Le brouillon n'est pas conservé : ce qui est saisi ici sera perdu.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuer la saisie'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Abandonner',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (leave == true && mounted) context.pop();
  }

  /// « Aperçu » — non maquetté dans la fiche. Montre l'événement tel qu'il
  /// sera enregistré, à partir des valeurs réellement saisies : aucun champ
  /// n'est inventé, ceux qui sont vides n'apparaissent pas.
  void _showPreview() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final locale = Localizations.localeOf(context).languageCode;
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final price =
        double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ??
        0.0;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aperçu',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_selectedPosters.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 3 / 2,
                        child: Image.file(
                          File(_selectedPosters.first.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    _titleController.text.trim(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PreviewRow(
                    icon: Icons.event_outlined,
                    text:
                        '${DateFormat('EEEE d MMMM', locale).format(startDateTime)}'
                        ' · ${DateFormat('HH:mm', locale).format(startDateTime)}',
                  ),
                  _PreviewRow(
                    icon: _isOnline ? Icons.videocam_outlined : Icons.place_outlined,
                    text:
                        _isOnline
                            ? (_onlineLinkController.text.trim().isEmpty
                                ? 'En ligne'
                                : _onlineLinkController.text.trim())
                            : _locationController.text.trim(),
                  ),
                  if (_maxAttendeesController.text.trim().isNotEmpty)
                    _PreviewRow(
                      icon: Icons.people_outline,
                      text:
                          '${_maxAttendeesController.text.trim()} participants max',
                    ),
                  _PreviewRow(
                    icon: Icons.local_offer_outlined,
                    text: price <= 0 ? 'Gratuit' : '$price €',
                    color: price <= 0 ? context.successColor : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _descriptionController.text.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    // « 2 août » comme la fiche, et non « 02 août 2026 ».
    final dateFormat = DateFormat('d MMMM', locale);
    final timeFormat = DateFormat('HH:mm', locale);
    final fromDiscussion =
        widget.groupId != null || widget.conversationId != null;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleClose();
      },
      child: Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: AppBar(
          toolbarHeight: 48,
          backgroundColor: context.backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: AppIcon(
              AppIcon.close,
              color: Theme.of(context).iconTheme.color!,
            ),
            onPressed: _handleClose,
          ),
          title: Text(
            'Nouvel événement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Brouillon',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _buildPosterZone(l10n),
              const SizedBox(height: 16),

              _buildLabel('Titre'),
              const SizedBox(height: 7),
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration(l10n.eventTitleHint, context),
                style: _fieldTextStyle(context),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.eventTitleRequiredError;
                  }
                  if (value.trim().length < 5) return l10n.eventTitleTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // La fiche ne montre pas la description, mais elle est
              // obligatoire : la reléguer sous la ligne de flottaison ferait
              // échouer la validation sans que l'on voie pourquoi.
              // `descriptionRequired` est un message d'erreur (« La
              // description est requise »), pas un libellé de champ.
              _buildLabel(l10n.description),
              const SizedBox(height: 7),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration(l10n.descriptionHint, context),
                style: _fieldTextStyle(context),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.descriptionRequiredError;
                  }
                  if (value.trim().length < 20) return l10n.descriptionTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPickerField(
                      label: 'Date',
                      icon: AppIcon(
                        AppIcon.event,
                        size: 17,
                        color: context.textTertiaryColor,
                      ),
                      value: dateFormat.format(_startDate),
                      onTap: _selectStartDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPickerField(
                      label: 'Heure',
                      icon: AppIcon(
                        AppIcon.clock,
                        size: 17,
                        color: context.textTertiaryColor,
                      ),
                      value: timeFormat.format(
                        DateTime(2024, 1, 1, _startTime.hour, _startTime.minute),
                      ),
                      onTap: _selectStartTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildLabel(l10n.endDateTimeOptional),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _buildPickerField(
                      icon: AppIcon(
                        AppIcon.event,
                        size: 17,
                        color: context.textTertiaryColor,
                      ),
                      value:
                          _endDate != null
                              ? dateFormat.format(_endDate!)
                              : l10n.endDate,
                      muted: _endDate == null,
                      onTap: _selectEndDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPickerField(
                      icon: AppIcon(
                        AppIcon.clock,
                        size: 17,
                        color: context.textTertiaryColor,
                      ),
                      value:
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
                      muted: _endTime == null,
                      onTap: _endDate != null ? _selectEndTime : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildLabel('Format'),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _buildFormatOption(
                      label: 'Sur place',
                      active: !_isOnline,
                      onTap: () => setState(() => _isOnline = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFormatOption(
                      label: 'En ligne',
                      active: _isOnline,
                      onTap: () => setState(() => _isOnline = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_isOnline)
                TextFormField(
                  controller: _onlineLinkController,
                  decoration: _inputDecoration(
                    l10n.videoConferenceLinkHint,
                    context,
                  ).copyWith(
                    prefixIcon: Icon(
                      Icons.videocam_outlined,
                      size: 17,
                      color: context.textTertiaryColor,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 24,
                    ),
                  ),
                  style: _fieldTextStyle(context),
                  keyboardType: TextInputType.url,
                )
              else ...[
                TextFormField(
                  controller: _locationController,
                  decoration: _inputDecoration(
                    l10n.locationHint,
                    context,
                  ).copyWith(
                    prefixIcon: AppIcon(
                      AppIcon.location,
                      size: 17,
                      color: context.textTertiaryColor,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 24,
                    ),
                  ),
                  style: _fieldTextStyle(context),
                  validator: (value) {
                    if (!_isOnline && (value == null || value.trim().isEmpty)) {
                      return l10n.locationRequiredError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildLabel(l10n.addressOptional),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _addressController,
                  decoration: _inputDecoration(l10n.addressHint, context),
                  style: _fieldTextStyle(context),
                ),
              ],
              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Participants max'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _maxAttendeesController,
                          // `unlimitedAttendees` (« Laissez vide pour un
                          // nombre illimité ») est une phrase d'aide : dans un
                          // champ demi-largeur elle se coupe à « Laissez vide
                          // pou… ».
                          decoration: _inputDecoration(
                            l10n.maxAttendeesHint,
                            context,
                          ),
                          style: _fieldTextStyle(context),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Prix'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _priceController,
                          // Champ vide = gratuit : le libellé « Gratuit » en
                          // vert de la fiche est l'état par défaut, pas une
                          // valeur à saisir.
                          decoration: _inputDecoration(
                            'Gratuit',
                            context,
                          ).copyWith(
                            hintStyle: TextStyle(
                              color: context.successColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            suffixText:
                                _priceController.text.trim().isEmpty ? null : '€',
                            suffixStyle: TextStyle(
                              color: context.textSecondaryColor,
                            ),
                          ),
                          style: _fieldTextStyle(context),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildLabel(l10n.category),
              const SizedBox(height: 7),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<EventCategory>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: context.surfaceColor,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: context.textTertiaryColor,
                    ),
                    style: _fieldTextStyle(context),
                    items:
                        EventCategory.values
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category.label,
                                  style: _fieldTextStyle(context),
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

              // Visibilité : uniquement quand l'événement naît d'une
              // discussion. La fiche montre ici « Prévenir mes groupes », qui
              // diffuserait dans plusieurs groupes — voir ECRANS_FICHES.md.
              if (fromDiscussion) ...[
                const SizedBox(height: 14),
                _buildToggleCard(
                  title: 'Publier dans le fil public',
                  subtitle:
                      _publishToFeed
                          ? 'Visible par tout le monde dans Événements, en plus de la discussion.'
                          : (widget.groupId != null
                              ? 'Visible uniquement par les membres du groupe.'
                              : 'Visible uniquement par les participants de la conversation.'),
                  value: _publishToFeed,
                  onChanged: (v) => setState(() => _publishToFeed = v),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: _buildFooter(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Blocs de la fiche 16e
  // ---------------------------------------------------------------------------

  /// Zone d'affiche en tête de formulaire : cadre pointillé de 104 px tant
  /// qu'aucune image n'est choisie, grille des affiches ensuite.
  Widget _buildPosterZone(AppLocalizations l10n) {
    if (_selectedPosters.isEmpty) {
      return GestureDetector(
        onTap: _pickPosters,
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: context.borderStrongColor,
            radius: 18,
          ),
          child: Container(
            height: 104,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(
                  AppIcon.image,
                  size: 24,
                  color: context.adaptivePrimaryColor,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ajouter une affiche',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recommandé · 3:2',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3 / 2,
          ),
          itemCount: _selectedPosters.length,
          itemBuilder: (context, index) {
            final poster = _selectedPosters[index];
            return Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(poster.path), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removePoster(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const AppIcon(
                        AppIcon.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (_selectedPosters.length < 5)
          TextButton.icon(
            onPressed: _pickPosters,
            icon: AppIcon(AppIcon.add, color: context.adaptivePrimaryColor),
            label: Text('${l10n.eventSelectImages} (${_selectedPosters.length}/5)'),
            style: TextButton.styleFrom(
              foregroundColor: context.adaptivePrimaryColor,
            ),
          ),
      ],
    );
  }

  /// Champ non saisissable ouvrant un sélecteur (date, heure) : même gabarit
  /// 50 px / rayon 14 que les champs de texte.
  Widget _buildPickerField({
    String? label,
    required Widget icon,
    required String value,
    required VoidCallback? onTap,
    bool muted = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[_buildLabel(label), const SizedBox(height: 7)],
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          muted
                              ? context.textTertiaryColor
                              : context.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatOption({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.textPrimaryColor : context.surfaceColor,
          borderRadius: BorderRadius.circular(13),
          border: active ? null : Border.all(color: context.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? context.backgroundColor : context.textSecondaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: context.successColor,
          ),
        ],
      ),
    );
  }

  /// Barre de pied fixe : « Aperçu » en contour, « Publier l'événement » plein.
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _isLoading ? null : _showPreview,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                foregroundColor: context.textSecondaryColor,
                side: BorderSide(color: context.borderStrongColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Aperçu',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.adaptivePrimaryColor,
                    foregroundColor: context.onPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                          : const Text(
                            "Publier l'événement",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: context.textSecondaryColor,
      ),
    );
  }

  TextStyle _fieldTextStyle(BuildContext context) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: context.textPrimaryColor,
  );

  InputDecoration _inputDecoration(String hint, BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textTertiaryColor, fontSize: 14),
      filled: true,
      fillColor: context.surfaceColor,
      isDense: true,
      border: border(context.borderColor),
      enabledBorder: border(context.borderColor),
      focusedBorder: border(context.adaptivePrimaryColor),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red),
      // 15 px de haut + 20 de ligne ≈ les 50 px de la fiche.
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _PreviewRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: context.textTertiaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? context.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
