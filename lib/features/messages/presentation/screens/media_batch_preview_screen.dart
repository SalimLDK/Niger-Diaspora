import 'package:flutter/material.dart';

import '../../../../core/services/image_compressor_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'gallery_picker_screen.dart';

class MediaBatchPreviewResult {
  final List<GalleryPick> picks;
  final bool reducedQuality;

  const MediaBatchPreviewResult({
    required this.picks,
    required this.reducedQuality,
  });
}

/// Revue d'un envoi groupé (§27d) : pellicule horizontale avec case à cocher
/// par média, poids total annoncé, bascule « qualité réduite », CTA qui
/// nomme le nombre envoyé. Vient APRÈS la sélection dans [GalleryPickerScreen]
/// (grille) — ne remplace pas [MediaPreviewScreen] (édition mono-fichier,
/// Signal-style) : cet écran s'affiche seulement quand plusieurs médias sont
/// sélectionnés, l'édition fine reste réservée au cas 1 fichier.
class MediaBatchPreviewScreen extends StatefulWidget {
  final List<GalleryPick> picks;

  const MediaBatchPreviewScreen({super.key, required this.picks});

  @override
  State<MediaBatchPreviewScreen> createState() =>
      _MediaBatchPreviewScreenState();
}

class _MediaBatchPreviewScreenState extends State<MediaBatchPreviewScreen> {
  final _compressor = ImageCompressorService();
  late final List<bool> _checked;
  bool _reduceQuality = false;
  int _totalBytes = 0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.picks.length, true);
    _reduceQuality = PreferencesService.instance.dataSaverMode;
    _computeTotalSize();
  }

  int get _checkedCount => _checked.where((c) => c).length;

  Future<void> _computeTotalSize() async {
    var total = 0;
    for (var i = 0; i < widget.picks.length; i++) {
      if (!_checked[i]) continue;
      total += await _compressor.getFileSize(widget.picks[i].file);
    }
    if (mounted) setState(() => _totalBytes = total);
  }

  void _toggle(int index) {
    setState(() => _checked[index] = !_checked[index]);
    _computeTotalSize();
  }

  Future<void> _confirm() async {
    if (_checkedCount == 0 || _isSending) return;
    setState(() => _isSending = true);

    final selected = <GalleryPick>[];
    for (var i = 0; i < widget.picks.length; i++) {
      if (!_checked[i]) continue;
      final pick = widget.picks[i];
      if (_reduceQuality && !pick.isVideo) {
        final compressed = await _compressor.compressImage(
          pick.file,
          maxWidth: 1280,
          maxHeight: 1280,
          quality: 55,
        );
        selected.add(GalleryPick(compressed, false));
      } else {
        selected.add(pick);
      }
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      MediaBatchPreviewResult(picks: selected, reducedQuality: _reduceQuality),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _checkedCount;
    final label = count <= 1 ? 'Envoyer 1 photo' : 'Envoyer $count photos';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.picks.length} médias sélectionnés'),
        leading: IconButton(
          icon: const AppIcon(AppIcon.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                itemCount: widget.picks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _FilmstripTile(
                      pick: widget.picks[index],
                      checked: _checked[index],
                      onTap: () => _toggle(index),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Poids total : ${_compressor.formatFileSize(_totalBytes)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value: _reduceQuality,
              onChanged: (v) {
                setState(() => _reduceQuality = v);
              },
              activeThumbColor: Colors.white,
              title: const Text(
                'Qualité réduite',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Envoie les photos plus légères (mode données réduites)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: count == 0 || _isSending ? null : _confirm,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilmstripTile extends StatelessWidget {
  final GalleryPick pick;
  final bool checked;
  final VoidCallback onTap;

  const _FilmstripTile({
    required this.pick,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: checked ? 1 : 0.35,
            duration: const Duration(milliseconds: 150),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                pick.file,
                width: 84,
                height: 108,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (pick.isVideo)
            const Positioned(
              left: 6,
              bottom: 6,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 22,
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked
                    ? context.adaptivePrimaryColor
                    : Colors.black45,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
