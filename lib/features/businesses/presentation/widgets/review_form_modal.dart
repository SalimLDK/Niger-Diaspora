import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/review_provider.dart';
import 'star_rating_input.dart';

class ReviewFormModal extends ConsumerStatefulWidget {
  final String businessId;
  final String userId;
  final String userDisplayName;
  final String? userPhotoUrl;
  final ReviewEntity? existingReview;

  const ReviewFormModal({
    super.key,
    required this.businessId,
    required this.userId,
    required this.userDisplayName,
    this.userPhotoUrl,
    this.existingReview,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String businessId,
    required String userId,
    required String userDisplayName,
    String? userPhotoUrl,
    ReviewEntity? existingReview,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewFormModal(
        businessId: businessId,
        userId: userId,
        userDisplayName: userDisplayName,
        userPhotoUrl: userPhotoUrl,
        existingReview: existingReview,
      ),
    );
  }

  @override
  ConsumerState<ReviewFormModal> createState() => _ReviewFormModalState();
}

class _ReviewFormModalState extends ConsumerState<ReviewFormModal> {
  late int _rating;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final List<XFile> _selectedImages = [];
  List<String> _existingImageUrls = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 0;
    _titleController = TextEditingController(
      text: widget.existingReview?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existingReview?.content ?? '',
    );
    _existingImageUrls = widget.existingReview?.imageUrls.toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (images.isNotEmpty) {
      setState(() {
        // Limit to 3 total images
        final remaining = 3 - _existingImageUrls.length - _selectedImages.length;
        _selectedImages.addAll(images.take(remaining));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez donner une note')),
      );
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ecrire un avis')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload new images
      List<String> newImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final files = _selectedImages.map((xf) => File(xf.path)).toList();
        newImageUrls = await ImageUploadService().uploadMultipleImages(
          files: files,
          type: ImageUploadType.business,
          id: widget.businessId,
        );
      }

      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      final review = ReviewEntity(
        id: widget.existingReview?.id ?? '',
        businessId: widget.businessId,
        userId: widget.userId,
        userDisplayName: widget.userDisplayName,
        userPhotoUrl: widget.userPhotoUrl,
        rating: _rating,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        content: _contentController.text.trim(),
        imageUrls: allImageUrls,
      );

      final actionsNotifier = ref.read(reviewActionsNotifierProvider.notifier);

      bool success;
      if (widget.existingReview != null) {
        success = await actionsNotifier.updateReview(review);
      } else {
        final created = await actionsNotifier.createReview(review);
        success = created != null;
      }

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.existingReview != null
                    ? 'Avis modifie avec succes'
                    : 'Avis publie avec succes',
              ),
            ),
          );
        } else {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la soumission')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingReview != null;
    final totalImages = _existingImageUrls.length + _selectedImages.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                isEditing ? 'Modifier votre avis' : 'Ecrire un avis',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Star rating
              Center(
                child: Column(
                  children: [
                    Text(
                      'Votre note',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StarRatingInput(
                      rating: _rating,
                      onRatingChanged: (value) => setState(() => _rating = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Title field (optional)
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Titre (optionnel)',
                  hintText: 'Ex: Excellent service',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Content field
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Votre avis',
                  hintText: 'Partagez votre experience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Images section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Photos ($totalImages/3)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (totalImages < 3)
                    TextButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Ajouter'),
                    ),
                ],
              ),

              // Display images
              if (totalImages > 0) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Existing images
                      ..._existingImageUrls.asMap().entries.map((entry) {
                        return _ImageThumbnail(
                          imageUrl: entry.value,
                          onRemove: () => _removeExistingImage(entry.key),
                        );
                      }),
                      // New images
                      ..._selectedImages.asMap().entries.map((entry) {
                        return _ImageThumbnail(
                          file: File(entry.value.path),
                          onRemove: () => _removeNewImage(entry.key),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit button
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditing ? 'Modifier' : 'Publier'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String? imageUrl;
  final File? file;
  final VoidCallback onRemove;

  const _ImageThumbnail({
    this.imageUrl,
    this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    file!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
