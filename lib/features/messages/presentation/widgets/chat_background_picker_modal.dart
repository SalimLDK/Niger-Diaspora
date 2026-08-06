import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../settings/data/models/chat_background_model.dart';
import '../../../settings/domain/constants/chat_background_colors.dart';
import '../../../settings/domain/entities/chat_background_entity.dart';
import 'chat_wallpapers.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class ChatBackgroundPickerModal extends StatefulWidget {
  final String? conversationId; // If null, apply to all conversations
  final ChatBackgroundEntity? currentBackground;

  const ChatBackgroundPickerModal({
    super.key,
    this.conversationId,
    this.currentBackground,
  });

  static Future<ChatBackgroundEntity?> show(
    BuildContext context, {
    String? conversationId,
    ChatBackgroundEntity? currentBackground,
  }) {
    return showModalBottomSheet<ChatBackgroundEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ChatBackgroundPickerModal(
            conversationId: conversationId,
            currentBackground: currentBackground,
          ),
    );
  }

  @override
  State<ChatBackgroundPickerModal> createState() =>
      _ChatBackgroundPickerModalState();
}

class _ChatBackgroundPickerModalState extends State<ChatBackgroundPickerModal> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  ChatBackgroundEntity? _selectedBackground;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedBackground = widget.currentBackground;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedBackground = ChatBackgroundEntity.image(
            localImagePath: image.path,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyBackground() async {
    if (_selectedBackground == null) return;

    try {
      final prefs = PreferencesService.instance;
      final model = ChatBackgroundModel.fromEntity(_selectedBackground!);
      final json = jsonEncode(model.toJson());

      if (widget.conversationId != null) {
        // Apply to specific conversation
        await prefs.setCustomChatBackground(widget.conversationId!, json);
      } else {
        // Apply as default for all conversations
        await prefs.setDefaultChatBackground(json);
      }

      if (mounted) {
        Navigator.pop(context, _selectedBackground);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.isDarkMode;
    final colors = ChatBackgroundColors.getColors(isDarkMode);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.conversationId != null
                        ? l10n.conversationBackground
                        : l10n.defaultBackground,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: AppIcon(AppIcon.close, color: context.textSecondaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Preview
              if (_selectedBackground != null) ...[
                _buildPreview(),
                const SizedBox(height: 20),
              ],

              // Default Theme Option
              _buildDefaultOption(),
              const SizedBox(height: 16),

              // Color Options
              Text(
                l10n.colors,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    colors.map((color) => _buildColorOption(color)).toList(),
              ),
              const SizedBox(height: 20),

              // Fonds nommés (§21c) — rendus procéduralement
              Text(
                'Fonds',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ChatWallpaper.all
                    .map((w) => _buildPatternOption(w))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Image Option
              _buildImageOption(),
              const SizedBox(height: 24),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedBackground != null ? _applyBackground : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.adaptivePrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.apply,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: _selectedBackground!.isColor ? _selectedBackground!.color : null,
        image:
            _selectedBackground!.isImage &&
                    _selectedBackground!.localImagePath != null
                ? DecorationImage(
                  image: FileImage(File(_selectedBackground!.localImagePath!)),
                  fit: BoxFit.cover,
                )
                : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineColor, width: 1),
      ),
      child: Stack(
        children: [
          // Fond nommé procédural (§21c)
          if (_selectedBackground!.isPattern &&
              ChatWallpaper.byId(_selectedBackground!.patternId) != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: ChatWallpaper.byId(_selectedBackground!.patternId)!
                      .painter(context.isDarkMode),
                ),
              ),
            ),
          // Semi-transparent overlay
          if (!_selectedBackground!.isDefault)
            Container(
              decoration: BoxDecoration(
                color:
                    context.isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          // Preview bubbles
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Received message bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(left: 40, right: 80, bottom: 8),
                  decoration: BoxDecoration(
                    color:
                        context.isDarkMode
                            ? Colors.green.shade800
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l10n.receivedMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ),
                // Sent message bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(left: 80, right: 40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.adaptiveSecondaryColor,
                        context.adaptiveSecondaryColor.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l10n.messageSent,
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultOption() {
    final isSelected = _selectedBackground?.isDefault ?? false;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedBackground = const ChatBackgroundEntity.defaultTheme();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected
                    ? context.adaptivePrimaryColor
                    : context.outlineColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.palette_outlined,
              color:
                  isSelected
                      ? context.adaptivePrimaryColor
                      : context.textSecondaryColor,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.defaultTheme,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color:
                    isSelected
                        ? context.adaptivePrimaryColor
                        : context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    final isSelected =
        _selectedBackground?.isColor == true &&
        _selectedBackground?.color == color;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedBackground = ChatBackgroundEntity.color(color);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? context.adaptivePrimaryColor
                    : context.outlineColor,
            width: isSelected ? 3 : 1,
          ),
        ),
        child:
            isSelected
                ? AppIcon(
                  AppIcon.check,
                  color: context.adaptivePrimaryColor,
                  size: 32,
                )
                : null,
      ),
    );
  }

  Widget _buildPatternOption(ChatWallpaper wallpaper) {
    final isSelected = _selectedBackground?.isPattern == true &&
        _selectedBackground?.patternId == wallpaper.id;
    final isDark = context.isDarkMode;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedBackground = ChatBackgroundEntity.pattern(wallpaper.id);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? context.adaptivePrimaryColor
                    : context.outlineColor,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: wallpaper.thumbnail(isDark, size: 60),
          ),
          const SizedBox(height: 4),
          Text(
            wallpaper.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? context.adaptivePrimaryColor
                  : context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOption() {
    final isSelected = _selectedBackground?.isImage ?? false;

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected
                    ? context.adaptivePrimaryColor
                    : context.outlineColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            AppIcon(
              AppIcon.image,
              color:
                  isSelected
                      ? context.adaptivePrimaryColor
                      : context.textSecondaryColor,
            ),
            const SizedBox(width: 12),
            Text(
              isSelected ? l10n.imageSelected : l10n.chooseImage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color:
                    isSelected
                        ? context.adaptivePrimaryColor
                        : context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
