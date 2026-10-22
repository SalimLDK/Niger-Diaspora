import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/services/image_upload_service.dart';
import 'reglages_briques.dart';

class AdminMediasTab extends ConsumerStatefulWidget {
  final AppSettingsEntity settings;

  const AdminMediasTab({super.key, required this.settings});

  @override
  ConsumerState<AdminMediasTab> createState() => _AdminMediasTabState();
}

class _AdminMediasTabState extends ConsumerState<AdminMediasTab> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const _primaryColor = AdminColors.actionBlue;

  /// Plancher appliqué par [ImageUploadService.setConfig] : le formulaire
  /// refuse ce que l'envoi ignorerait.
  static const _plancherImages = ImageUploadConfig();

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _imageMaxWidthController;
  late TextEditingController _imageQualityController;
  late TextEditingController _maxImagesController;
  late TextEditingController _messageMaxCharsController;
  late TextEditingController _maxImageSizeController;
  late TextEditingController _maxVideoSizeController;

  @override
  void initState() {
    super.initState();
    final limits = widget.settings.mediaLimits;
    _imageMaxWidthController =
        TextEditingController(text: limits.imageMaxWidth.toString());
    _imageQualityController =
        TextEditingController(text: limits.imageQuality.toString());
    _maxImagesController =
        TextEditingController(text: limits.maxImagesPerUpload.toString());
    _messageMaxCharsController =
        TextEditingController(text: limits.messageMaxChars.toString());
    _maxImageSizeController =
        TextEditingController(text: limits.maxImageSizeMb.toString());
    _maxVideoSizeController =
        TextEditingController(text: limits.maxVideoSizeMb.toString());
  }

  @override
  void dispose() {
    _imageMaxWidthController.dispose();
    _imageQualityController.dispose();
    _maxImagesController.dispose();
    _messageMaxCharsController.dispose();
    _maxImageSizeController.dispose();
    _maxVideoSizeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    final current = widget.settings.mediaLimits;
    final newLimits = MediaLimitsEntity(
      imageMaxWidth: int.parse(_imageMaxWidthController.text),
      imageMaxHeight: int.parse(_imageMaxWidthController.text),
      imageQuality: int.parse(_imageQualityController.text),
      maxImagesPerUpload: int.parse(_maxImagesController.text),
      minWidthForCompression: current.minWidthForCompression,
      messageMaxChars: int.parse(_messageMaxCharsController.text),
      messageCharCountThreshold: current.messageCharCountThreshold,
      maxImageSizeMb: int.parse(_maxImageSizeController.text),
      maxVideoSizeMb: int.parse(_maxVideoSizeController.text),
      maxDocumentSizeMb: current.maxDocumentSizeMb,
      maxAudioDurationSeconds: current.maxAudioDurationSeconds,
    );

    await ref
        .read(appSettingsNotifierProvider.notifier)
        .updateMediaLimits(newLimits, currentUser.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(l10n.adminMediaLimitsUpdated),
            ],
          ),
          backgroundColor: AdminColors.statusGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReglagesCarteSection(
              title: l10n.adminImagesTitle,
              subtitle: l10n.adminImagesDesc,
              icon: Icons.image_rounded,
              color: AdminColors.actionBlueLight,
              children: [
                // `min` : en dessous du plancher de ImageUploadConfig, la
                // valeur serait enregistrée puis ignorée à l'envoi — un
                // réglage muet. Mieux vaut la refuser ici.
                _buildIntField(
                  controller: _imageMaxWidthController,
                  label: l10n.adminMaxDimension,
                  hint: l10n.adminImagesDimensionHint,
                  min: _plancherImages.maxWidth,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildIntField(
                        controller: _imageQualityController,
                        label: l10n.adminCompressionQuality,
                        hint: '${_plancherImages.quality}-100',
                        max: 100,
                        min: _plancherImages.quality,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildIntField(
                        controller: _maxImagesController,
                        label: l10n.adminMaxImagesUpload,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildIntField(
                  controller: _maxImageSizeController,
                  label: l10n.adminMaxImageSize,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ReglagesCarteSection(
              title: l10n.adminVideosTitle,
              subtitle: l10n.adminVideosDesc,
              icon: Icons.videocam_rounded,
              color: AdminColors.statusRed,
              children: [
                _buildIntField(
                  controller: _maxVideoSizeController,
                  label: l10n.adminMaxVideoSize,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ReglagesCarteSection(
              title: l10n.adminMessagesTitle,
              subtitle: l10n.adminMessagesDesc,
              icon: Icons.message_rounded,
              color: AdminColors.statusGreen,
              children: [
                _buildIntField(
                  controller: _messageMaxCharsController,
                  label: l10n.adminMaxMessageChars,
                ),
              ],
            ),
            const SizedBox(height: 32),
            ReglagesBoutonEnregistrer(label: l10n.save, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _buildIntField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? max,
    int? min,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AdminColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.statusRed),
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v == null || v.isEmpty) return l10n.adminFieldRequired;
        final num = int.tryParse(v);
        if (num == null || num <= 0) return l10n.quantityInvalidError;
        if (max != null && num > max) return 'Max: $max';
        if (min != null && num < min) return 'Min: $min';
        return null;
      },
    );
  }
}

// ============================================================================
// SYSTEM SETTINGS TAB
// ============================================================================
