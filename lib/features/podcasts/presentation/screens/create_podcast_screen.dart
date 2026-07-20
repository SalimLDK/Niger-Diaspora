import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/podcast_entity.dart';
import '../providers/podcast_provider.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Screen for creating a new podcast
class CreatePodcastScreen extends ConsumerStatefulWidget {
  const CreatePodcastScreen({super.key});

  @override
  ConsumerState<CreatePodcastScreen> createState() =>
      _CreatePodcastScreenState();
}

class _CreatePodcastScreenState extends ConsumerState<CreatePodcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _coverImage;
  PodcastCategory _category = PodcastCategory.other;
  String _language = 'fr';
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  bool _isExplicit = false;
  String? _episodeFrequency;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _coverImage = File(image.path));
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _createPodcast() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_coverImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pleaseAddCoverImage)));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final podcast = await ref
          .read(podcastNotifierProvider.notifier)
          .createPodcast(
            title: _titleController.text.trim(),
            description:
                _descriptionController.text.trim().isNotEmpty
                    ? _descriptionController.text.trim()
                    : null,
            coverImage: _coverImage!,
            category: _category,
            language: _language,
            tags: _tags,
            isExplicit: _isExplicit,
            episodeFrequency: _episodeFrequency,
          );

      if (podcast != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.podcastCreatedSuccess)));
        context.go('/podcasts/${podcast.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              ErrorHandler.instance.getShortMessage(
                ErrorHandler.instance.handleException(e),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPodcast)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cover image
            Center(
              child: GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    image:
                        _coverImage != null
                            ? DecorationImage(
                              image: FileImage(_coverImage!),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      _coverImage == null
                          ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.podcastsAddCover,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          )
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.podcastTitleLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.podcastsPodcastTitleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.podcastDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<PodcastCategory>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.podcastsCategoryRequired,
                border: const OutlineInputBorder(),
              ),
              items:
                  PodcastCategory.values.map((category) {
                    final label =
                        PodcastEntity(
                          id: '',
                          title: '',
                          coverImageUrl: '',
                          hostId: '',
                          hostName: '',
                          category: category,
                          language: 'fr',
                          createdAt: DateTime.now(),
                        ).categoryLabel;
                    return DropdownMenuItem(
                      value: category,
                      child: Text(label),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),

            // Language
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: InputDecoration(
                labelText: l10n.podcastsLanguageRequired,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'fr', child: Text(l10n.languageFrench)),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l10n.languageEnglish),
                ),
                DropdownMenuItem(value: 'ha', child: Text(l10n.languageHausa)),
                DropdownMenuItem(value: 'dj', child: Text(l10n.languageZarma)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _language = value);
              },
            ),
            const SizedBox(height: 16),

            // Episode frequency
            DropdownButtonFormField<String?>(
              initialValue: _episodeFrequency,
              decoration: InputDecoration(
                labelText: l10n.podcastsPublicationFrequency,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.frequencyNotDefined),
                ),
                DropdownMenuItem(
                  value: 'daily',
                  child: Text(l10n.frequencyDaily),
                ),
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text(l10n.frequencyWeekly),
                ),
                DropdownMenuItem(
                  value: 'biweekly',
                  child: Text(l10n.frequencyBiweekly),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text(l10n.frequencyMonthly),
                ),
              ],
              onChanged: (value) {
                setState(() => _episodeFrequency = value);
              },
            ),
            const SizedBox(height: 16),

            // Tags
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      labelText: l10n.podcastsTags,
                      hintText: l10n.podcastsAddTag,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        onDeleted: () {
                          setState(() => _tags.remove(tag));
                        },
                      );
                    }).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Explicit content
            SwitchListTile(
              title: Text(l10n.explicitContent),
              subtitle: Text(l10n.explicitContentDesc),
              value: _isExplicit,
              onChanged: (value) => setState(() => _isExplicit = value),
            ),
            const SizedBox(height: 24),

            // Create button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPodcast,
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(l10n.createThePodcast),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
