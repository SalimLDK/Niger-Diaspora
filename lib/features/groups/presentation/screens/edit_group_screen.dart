import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class EditGroupScreen extends ConsumerStatefulWidget {
  final GroupEntity group;

  const EditGroupScreen({super.key, required this.group});

  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _tagsController;

  late GroupCategory _selectedCategory;
  late bool _isPrivate;
  bool _isLoading = false;
  File? _selectedImage;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(
      text: widget.group.description,
    );
    _locationController = TextEditingController(
      text: widget.group.location ?? '',
    );
    _tagsController = TextEditingController(text: widget.group.tags.join(', '));
    _selectedCategory = widget.group.category;
    _isPrivate = widget.group.isPrivate;
    _currentImageUrl = widget.group.imageUrl;
  }

  Future<void> _pickImage() async {
    final imageService = ImageUploadService();
    final image = await imageService.pickImageFromGallery();
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _deletePhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deletePhoto),
            content: const Text(
              'Voulez-vous vraiment supprimer la photo du groupe ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.undo),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _selectedImage = null;
        _currentImageUrl = null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Upload new image if selected
    String? imageUrl = _currentImageUrl;
    if (_selectedImage != null) {
      final imageService = ImageUploadService();
      final uploadedUrl = await imageService.uploadImage(
        file: _selectedImage!,
        type: ImageUploadType.group,
        id: widget.group.id,
      );
      if (uploadedUrl != null) {
        imageUrl = uploadedUrl;
      }
    }

    final tags =
        _tagsController.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();

    final updatedGroup = GroupEntity(
      id: widget.group.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      creatorId: widget.group.creatorId,
      creatorName: widget.group.creatorName,
      category: _selectedCategory,
      isPrivate: _isPrivate,
      location:
          _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
      tags: tags,
      adminIds: widget.group.adminIds,
      memberIds: widget.group.memberIds,
      imageUrl: imageUrl,
      createdAt: widget.group.createdAt,
    );

    final success = await ref
        .read(myGroupsNotifierProvider.notifier)
        .updateGroup(updatedGroup);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ToastUtils.showSuccess(context, l10n.groupModified);

      // Refresh groups list
      ref.read(groupsNotifierProvider.notifier).refresh();
      // Also update the detail view
      ref.read(groupDetailNotifierProvider.notifier).loadGroup(widget.group.id);

      if (mounted) context.pop();
    } else if (mounted) {
      ToastUtils.showError(context, l10n.eventUpdateError);
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deleteGroup),
            content: Text(
              l10n.confirmDeleteGroup,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.undo),
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
        .read(myGroupsNotifierProvider.notifier)
        .deleteGroup(widget.group.id);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminGroupDeleted),
          behavior: SnackBarBehavior.fixed,
        ),
      );
      // Refresh groups list
      ref.read(groupsNotifierProvider.notifier).refresh();
      // Go back to groups list
      context.go('/groups');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.removalError),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.groupEditTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _deleteGroup,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Photo de groupe
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.borderColor,
                          width: 2,
                        ),
                      ),
                      child:
                          _selectedImage != null
                              ? ClipOval(
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                              : _currentImageUrl != null
                              ? ClipOval(
                                child: Image.network(
                                  _currentImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Icon(
                                        Icons.groups,
                                        size: 50,
                                        color: context.textTertiaryColor,
                                      ),
                                ),
                              )
                              : Icon(
                                Icons.groups,
                                size: 50,
                                color: context.textTertiaryColor,
                              ),
                    ),
                    // Delete button (only show if there's a photo)
                    if (_selectedImage != null || _currentImageUrl != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _deletePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.backgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Camera button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.backgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Nom du groupe
            _buildLabel('Nom du groupe *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(l10n.groupNameExample),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.groupNameIsRequired;
                }
                if (value.trim().length < 3) {
                  return l10n.groupNameMinLength;
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Description
            _buildLabel(l10n.businessDescriptionLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(l10n.describeYourGroup),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.descriptionRequired;
                }
                if (value.trim().length < 10) {
                  return l10n.descriptionMinLength;
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
                child: DropdownButton<GroupCategory>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items:
                      GroupCategory.values
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
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

            // Localisation
            _buildLabel('Localisation (optionnel)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              decoration: _inputDecoration(l10n.locationHint),
            ),

            const SizedBox(height: 20),

            // Tags
            _buildLabel(l10n.audioRoomTagsOptional),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tagsController,
              decoration: _inputDecoration(l10n.tagsExample),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.tagsHint,
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
            ),

            const SizedBox(height: 20),

            // Groupe privé
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
                          l10n.privateGroup,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          l10n.membersNeedApproval,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    onChanged: (value) => setState(() => _isPrivate = value),
                    activeThumbColor: context.adaptivePrimaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Bouton modifier
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.adaptivePrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          l10n.saveChanges,
                          style: TextStyle(
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

  InputDecoration _inputDecoration(String hint) {
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
