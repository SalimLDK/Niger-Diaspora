import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Un média choisi dans la galerie intégrée.
class GalleryPick {
  final File file;
  final bool isVideo;
  const GalleryPick(this.file, this.isVideo);
}

/// Sélecteur de galerie intégré (grille de vignettes) basé sur photo_manager.
/// Fiable sur tous les appareils : n'ouvre pas le gestionnaire de fichiers.
class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  final ScrollController _scroll = ScrollController();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];

  AssetPathEntity? _album;
  int _page = 0;
  static const int _pageSize = 60;
  bool _loading = true;
  bool _hasMore = true;
  bool _denied = false;
  RequestType _filter = RequestType.common;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: _filter,
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _album = albums.first;
    await _loadMore();
  }

  Future<void> _setFilter(RequestType t) async {
    if (t == _filter) return;
    HapticFeedback.selectionClick();
    setState(() {
      _filter = t;
      _assets.clear();
      _page = 0;
      _hasMore = true;
      _loading = true;
    });
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: _filter,
    );
    _album = albums.isNotEmpty ? albums.first : null;
    if (_album == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_album == null || !_hasMore) return;
    final page = await _album!.getAssetListPaged(page: _page, size: _pageSize);
    if (mounted) {
      setState(() {
        _assets.addAll(page);
        _page++;
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  void _toggle(AssetEntity a) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(a)) {
        _selected.remove(a);
      } else {
        _selected.add(a);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty) return;
    final picks = <GalleryPick>[];
    for (final a in _selected) {
      final f = await a.file;
      if (f != null) picks.add(GalleryPick(f, a.type == AssetType.video));
    }
    if (mounted) Navigator.pop(context, picks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Galerie'),
        leading: IconButton(
          icon: const AppIcon(AppIcon.close),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterBar(),
        ),
      ),
      body: _denied
          ? _buildDenied()
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _assets.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun média',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : GridView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: _assets.length,
                      itemBuilder: (context, i) => _buildCell(_assets[i]),
                    ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const AppIcon(AppIcon.send),
                    label: Text('Envoyer (${_selected.length})'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterBar() {
    Widget chip(String label, RequestType t) {
      final sel = _filter == t;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => _setFilter(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? Colors.blue : Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip('Tout', RequestType.common),
          chip('Photos', RequestType.image),
          chip('Vidéos', RequestType.video),
        ],
      ),
    );
  }

  Widget _buildDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Accès à la galerie refusé',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('Ouvrir les réglages'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(AssetEntity a) {
    final index = _selected.indexOf(a);
    final isSelected = index >= 0;
    return GestureDetector(
      onTap: () => _toggle(a),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedScale(
            scale: isSelected ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Image(
              image: AssetEntityImageProvider(
                a,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(250),
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          if (a.type == AssetType.video)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _fmtDuration(a.videoDuration),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          if (isSelected)
            Container(color: Colors.black.withValues(alpha: 0.35)),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.blue : Colors.black26,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: isSelected
                  ? Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
