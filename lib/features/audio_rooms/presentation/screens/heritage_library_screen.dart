import 'package:flutter/material.dart';

import '../../../../shared/widgets/dn_sheet_handle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/heritage_recording_entity.dart';
import '../providers/heritage_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Screen for browsing the cultural heritage library
class HeritageLibraryScreen extends ConsumerStatefulWidget {
  const HeritageLibraryScreen({super.key});

  @override
  ConsumerState<HeritageLibraryScreen> createState() =>
      _HeritageLibraryScreenState();
}

class _HeritageLibraryScreenState extends ConsumerState<HeritageLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  HeritageContentType? _selectedType;
  String? _selectedLanguage;
  String? _selectedRegion;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  List<({HeritageContentType type, String label, IconData icon})> _getContentTypes(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      (
        type: HeritageContentType.story,
        label: l10n.heritageStories,
        icon: Icons.auto_stories_rounded,
      ),
      (
        type: HeritageContentType.proverb,
        label: l10n.heritageProverbs,
        icon: Icons.format_quote_rounded,
      ),
      (
        type: HeritageContentType.history,
        label: l10n.heritageHistory,
        icon: Icons.history_edu_rounded,
      ),
      (
        type: HeritageContentType.ceremony,
        label: l10n.heritageCeremonies,
        icon: Icons.celebration_rounded,
      ),
      (
        type: HeritageContentType.language,
        label: l10n.heritageLanguageType,
        icon: Icons.translate_rounded,
      ),
      (
        type: HeritageContentType.craft,
        label: l10n.heritageCraft,
        icon: Icons.handyman_rounded,
      ),
      (
        type: HeritageContentType.recipe,
        label: l10n.heritageRecipes,
        icon: Icons.restaurant_rounded,
      ),
      (
        type: HeritageContentType.medicine,
        label: l10n.heritageMedicine,
        icon: Icons.healing_rounded,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = ref.watch(isHeritageEnabledProvider);
    final languages = ref.watch(heritageLanguagesProvider);
    final regions = ref.watch(heritageRegionsProvider);

    if (!isEnabled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.heritageLibraryTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.library_music_rounded,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.heritageLibraryNotAvailable,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder:
            (context, innerBoxIsScrolled) => [
              _buildAppBar(context, l10n, languages, regions),
            ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDiscoverTab(),
            _buildCategoriesTab(),
            _buildSavedTab(),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    List<String> languages,
    List<String> regions,
  ) {
    return SliverAppBar(
      expandedHeight: _isSearching ? 120 : 180,
      floating: true,
      pinned: true,
      backgroundColor: AppColors.secondary,
      leading: IconButton(
        icon: const AppIcon(AppIcon.arrowBack, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: AppIcon(_isSearching ? AppIcon.close : AppIcon.search,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
              }
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onSelected: (value) {
            final parts = value.split(':');
            setState(() {
              if (parts[0] == 'lang') {
                _selectedLanguage = parts[1] == 'all' ? null : parts[1];
              } else if (parts[0] == 'region') {
                _selectedRegion = parts[1] == 'all' ? null : parts[1];
              }
            });
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    l10n.heritageLibraryLanguageFilter,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuItem(
                  value: 'lang:all',
                  child: Text(l10n.heritageLibraryAllLanguages),
                ),
                ...languages.map(
                  (lang) =>
                      PopupMenuItem(value: 'lang:$lang', child: Text(lang)),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    l10n.heritageLibraryRegionFilter,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuItem(
                  value: 'region:all',
                  child: Text(l10n.heritageLibraryAllRegions),
                ),
                ...regions.map(
                  (region) => PopupMenuItem(
                    value: 'region:$region',
                    child: Text(region),
                  ),
                ),
              ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.secondary,
                AppColors.secondary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isSearching) ...[
                    Text(
                      l10n.heritageLibraryTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.heritageLibraryPreserve,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.heritageLibrarySearch,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        prefixIcon: const AppIcon(AppIcon.search,
                          color: Colors.white70,
                        ),
                      ),
                      onSubmitted: (query) {
                        // Trigger search
                      },
                    ),
                  ],
                  if (_selectedLanguage != null || _selectedRegion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_selectedLanguage != null)
                            Chip(
                              label: Text(_selectedLanguage!),
                              onDeleted:
                                  () =>
                                      setState(() => _selectedLanguage = null),
                              backgroundColor: Colors.white24,
                              labelStyle: const TextStyle(color: Colors.white),
                              deleteIconColor: Colors.white70,
                            ),
                          if (_selectedRegion != null)
                            Chip(
                              label: Text(_selectedRegion!),
                              onDeleted:
                                  () => setState(() => _selectedRegion = null),
                              backgroundColor: Colors.white24,
                              labelStyle: const TextStyle(color: Colors.white),
                              deleteIconColor: Colors.white70,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: [
          Tab(text: l10n.heritageLibraryDiscoverTab),
          Tab(text: l10n.heritageLibraryCategoriesTab),
          Tab(text: l10n.heritageLibrarySavedTab),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final l10n = AppLocalizations.of(context)!;
    final featuredAsync = ref.watch(featuredHeritageRecordingsProvider);
    final recordingsAsync = ref.watch(
      heritageRecordingsProvider(
        HeritageRecordingsParams(
          contentType: _selectedType,
          language: _selectedLanguage,
          region: _selectedRegion,
        ),
      ),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(featuredHeritageRecordingsProvider);
        ref.invalidate(heritageRecordingsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Featured section
          Text(
            l10n.heritageLibraryPopular,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          featuredAsync.when(
            data:
                (recordings) =>
                    recordings.isEmpty
                        ? _buildEmptyState(
                          l10n.heritageLibraryNoPopularRecordings,
                        )
                        : SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recordings.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 12),
                            itemBuilder:
                                (context, index) =>
                                    _buildFeaturedCard(recordings[index]),
                          ),
                        ),
            loading:
                () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (e, _) => _buildErrorState(
              l10n,
              ErrorHandler.instance.getShortMessage(
                ErrorHandler.instance.handleException(e),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent recordings
          Text(
            l10n.heritageLibraryRecent,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          recordingsAsync.when(
            data:
                (recordings) =>
                    recordings.isEmpty
                        ? _buildEmptyState(
                          l10n.heritageLibraryNoRecordingsFound,
                        )
                        : Column(
                          children:
                              recordings
                                  .map((r) => _buildRecordingTile(r))
                                  .toList(),
                        ),
            loading:
                () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
            error: (e, _) => _buildErrorState(
              l10n,
              ErrorHandler.instance.getShortMessage(
                ErrorHandler.instance.handleException(e),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final l10n = AppLocalizations.of(context)!;
    final contentTypes = _getContentTypes(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: contentTypes.length,
          itemBuilder: (context, index) {
            final item = contentTypes[index];
            final isSelected = _selectedType == item.type;
            return _buildCategoryCard(
              item.type,
              _getContentTypeLabel(l10n, item.type),
              item.icon,
              isSelected,
            );
          },
        ),
        if (_selectedType != null) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getContentTypeLabel(l10n, _selectedType!),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedType = null),
                child: Text(l10n.heritageLibrarySeeAll),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final recordingsAsync = ref.watch(
                recordingsByTypeProvider(_selectedType!),
              );
              return recordingsAsync.when(
                data:
                    (recordings) =>
                        recordings.isEmpty
                            ? _buildEmptyState(
                              l10n.heritageLibraryNoCategoryRecordings,
                            )
                            : Column(
                              children:
                                  recordings
                                      .map((r) => _buildRecordingTile(r))
                                      .toList(),
                            ),
                loading:
                    () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                error: (e, _) => _buildErrorState(
              l10n,
              ErrorHandler.instance.getShortMessage(
                ErrorHandler.instance.handleException(e),
              ),
            ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSavedTab() {
    final l10n = AppLocalizations.of(context)!;
    final savedAsync = ref.watch(savedRecordingsProvider);

    return savedAsync.when(
      data:
          (recordings) =>
              recordings.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.heritageLibraryNoSavedRecordings,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.heritageLibrarySaveHint,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: recordings.length,
                    itemBuilder:
                        (context, index) =>
                            _buildRecordingTile(recordings[index]),
                  ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(
        l10n,
        ErrorHandler.instance.getShortMessage(
          ErrorHandler.instance.handleException(e),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(HeritageRecordingEntity recording) {
    return GestureDetector(
      onTap: () => _openRecording(recording),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getContentTypeColor(recording.contentType),
              _getContentTypeColor(
                recording.contentType,
              ).withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _getContentTypeColor(
                recording.contentType,
              ).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getContentTypeIcon(recording.contentType),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Text(
                recording.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                recording.contributorName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${recording.playCount}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppIcon(AppIcon.clock,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    recording.formattedDuration,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    HeritageContentType type,
    String label,
    IconData icon,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = isSelected ? null : type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? _getContentTypeColor(type) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _getContentTypeColor(type) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: _getContentTypeColor(type).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : _getContentTypeColor(type),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingTile(HeritageRecordingEntity recording) {
    final userData = ref.watch(heritageUserDataProvider).valueOrNull;
    final isLiked = userData?.likedRecordingIds.contains(recording.id) ?? false;
    final isSaved = userData?.savedRecordingIds.contains(recording.id) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openRecording(recording),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getContentTypeColor(
                    recording.contentType,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getContentTypeIcon(recording.contentType),
                  color: _getContentTypeColor(recording.contentType),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recording.contributorName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getContentTypeColor(
                              recording.contentType,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recording.contentTypeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getContentTypeColor(
                                recording.contentType,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppIcon(AppIcon.clock,
                          size: 12,
                          color: Colors.grey[500]!,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          recording.formattedDuration,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (recording.language.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            recording.language,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                children: [
                  IconButton(
                    icon: AppIcon(
                      isLiked
                          ? AppIcon.heart
                          : AppIcon.favoriteBorder,
                      color: isLiked ? Colors.red : Colors.grey[400],
                      size: 22,
                    ),
                    onPressed: () {
                      if (isLiked) {
                        ref
                            .read(heritageNotifierProvider.notifier)
                            .unlikeRecording(recording.id);
                      } else {
                        ref
                            .read(heritageNotifierProvider.notifier)
                            .likeRecording(recording.id);
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isSaved ? AppColors.secondary : Colors.grey[400],
                      size: 22,
                    ),
                    onPressed: () {
                      if (isSaved) {
                        ref
                            .read(heritageNotifierProvider.notifier)
                            .unsaveRecording(recording.id);
                      } else {
                        ref
                            .read(heritageNotifierProvider.notifier)
                            .saveRecording(recording.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, String error) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcon.error, size: 48, color: Colors.red[300]!),
          const SizedBox(height: 12),
          Text(
            '${l10n.error}: $error',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openRecording(HeritageRecordingEntity recording) {
    // Navigate to recording detail or show player bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordingPlayerSheet(recording: recording),
    );
  }

  String _getContentTypeLabel(AppLocalizations l10n, HeritageContentType type) {
    return switch (type) {
      HeritageContentType.story => l10n.heritageContentTypeStories,
      HeritageContentType.proverb => l10n.heritageContentTypeProverbs,
      HeritageContentType.history => l10n.heritageContentTypeHistory,
      HeritageContentType.ceremony => l10n.heritageContentTypeCeremonies,
      HeritageContentType.language => l10n.heritageContentTypeLanguage,
      HeritageContentType.craft => l10n.heritageContentTypeCraft,
      HeritageContentType.recipe => l10n.heritageContentTypeRecipes,
      HeritageContentType.medicine => l10n.heritageContentTypeMedicine,
      HeritageContentType.other => l10n.heritageContentTypeOther,
    };
  }

  Color _getContentTypeColor(HeritageContentType type) {
    return switch (type) {
      HeritageContentType.story => const Color(0xFF6366F1),
      HeritageContentType.proverb => const Color(0xFFF59E0B),
      HeritageContentType.history => const Color(0xFF8B5CF6),
      HeritageContentType.ceremony => const Color(0xFFEF4444),
      HeritageContentType.language => const Color(0xFF10B981),
      HeritageContentType.craft => const Color(0xFF3B82F6),
      HeritageContentType.recipe => const Color(0xFFF97316),
      HeritageContentType.medicine => const Color(0xFF14B8A6),
      HeritageContentType.other => Colors.grey,
    };
  }

  IconData _getContentTypeIcon(HeritageContentType type) {
    return switch (type) {
      HeritageContentType.story => Icons.auto_stories_rounded,
      HeritageContentType.proverb => Icons.format_quote_rounded,
      HeritageContentType.history => Icons.history_edu_rounded,
      HeritageContentType.ceremony => Icons.celebration_rounded,
      HeritageContentType.language => Icons.translate_rounded,
      HeritageContentType.craft => Icons.handyman_rounded,
      HeritageContentType.recipe => Icons.restaurant_rounded,
      HeritageContentType.medicine => Icons.healing_rounded,
      HeritageContentType.other => Icons.library_music_rounded,
    };
  }
}

/// Bottom sheet for playing a heritage recording
class _RecordingPlayerSheet extends ConsumerStatefulWidget {
  final HeritageRecordingEntity recording;

  const _RecordingPlayerSheet({required this.recording});

  @override
  ConsumerState<_RecordingPlayerSheet> createState() =>
      _RecordingPlayerSheetState();
}

class _RecordingPlayerSheetState extends ConsumerState<_RecordingPlayerSheet> {
  bool _isPlaying = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    // Record play when opened
    ref.read(heritageNotifierProvider.notifier).recordPlay(widget.recording.id);
  }

  Color _getContentTypeColor(HeritageContentType type) {
    return switch (type) {
      HeritageContentType.story => const Color(0xFF6366F1),
      HeritageContentType.proverb => const Color(0xFFF59E0B),
      HeritageContentType.history => const Color(0xFF8B5CF6),
      HeritageContentType.ceremony => const Color(0xFFEF4444),
      HeritageContentType.language => const Color(0xFF10B981),
      HeritageContentType.craft => const Color(0xFF3B82F6),
      HeritageContentType.recipe => const Color(0xFFF97316),
      HeritageContentType.medicine => const Color(0xFF14B8A6),
      HeritageContentType.other => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.recording;
    final color = _getContentTypeColor(recording.contentType);
    final userData = ref.watch(heritageUserDataProvider).valueOrNull;
    final isLiked = userData?.likedRecordingIds.contains(recording.id) ?? false;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: DnSheetHandle(),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Album art placeholder
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title and contributor
                  Text(
                    recording.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recording.contributorName,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 8),

                  // Tags
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        label: Text(recording.contentTypeLabel),
                        backgroundColor: color.withValues(alpha: 0.1),
                        labelStyle: TextStyle(color: color, fontSize: 12),
                      ),
                      if (recording.language.isNotEmpty)
                        Chip(
                          label: Text(recording.language),
                          backgroundColor: Colors.grey[100],
                          labelStyle: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Progress bar
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: _progress,
                          onChanged: (value) {
                            setState(() => _progress = value);
                          },
                          activeColor: color,
                          inactiveColor: color.withValues(alpha: 0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0:00',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            Text(
                              recording.formattedDuration,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: AppIcon(
                          isLiked
                              ? AppIcon.heart
                              : AppIcon.favoriteBorder,
                          color: isLiked ? Colors.red : Colors.grey[600],
                        ),
                        iconSize: 28,
                        onPressed: () {
                          if (isLiked) {
                            ref
                                .read(heritageNotifierProvider.notifier)
                                .unlikeRecording(recording.id);
                          } else {
                            ref
                                .read(heritageNotifierProvider.notifier)
                                .likeRecording(recording.id);
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.replay_10, color: Colors.grey[600]),
                        iconSize: 32,
                        onPressed: () {
                          // Rewind 10 seconds
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _isPlaying = !_isPlaying);
                        },
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.forward_10, color: Colors.grey[600]),
                        iconSize: 32,
                        onPressed: () {
                          // Forward 10 seconds
                        },
                      ),
                      IconButton(
                        icon: AppIcon(
                          AppIcon.share,
                          color: Colors.grey[600],
                        ),
                        iconSize: 28,
                        onPressed: () {
                          ref
                              .read(heritageNotifierProvider.notifier)
                              .shareRecording(recording.id);
                          // Share functionality
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
