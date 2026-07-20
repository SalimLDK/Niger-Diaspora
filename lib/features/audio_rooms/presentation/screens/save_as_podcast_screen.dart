import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// /audio-rooms/:roomId/podcast — save a recorded room as a podcast episode.
class SaveAsPodcastScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? roomTitle;
  final Duration? duration;
  final bool isVideoReplay;
  final String? videoUrl;

  const SaveAsPodcastScreen({
    super.key,
    required this.roomId,
    this.roomTitle,
    this.duration,
    this.isVideoReplay = false,
    this.videoUrl,
  });

  @override
  ConsumerState<SaveAsPodcastScreen> createState() =>
      _SaveAsPodcastScreenState();
}

class _SaveAsPodcastScreenState extends ConsumerState<SaveAsPodcastScreen> {
  final _titleCtrl = TextEditingController();
  bool _tipsEnabled = true;
  String _visibility = 'public';
  bool _isPublishing = false;

  static const _chapters = [
    (Duration(seconds: 0), 'Introduction'),
    (Duration(minutes: 8), 'Actualités Niger'),
    (Duration(minutes: 22), 'Diaspora & politique'),
    (Duration(minutes: 45), 'Questions / Réponses'),
    (Duration(minutes: 68), 'Conclusion'),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.roomTitle ?? AppLocalizations.of(context)!.sessionRecorded;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final l10n = AppLocalizations.of(context)!;
    final durStr = widget.duration != null
        ? '${widget.duration!.inHours}h ${widget.duration!.inMinutes % 60}min'
        : '1h 14min';

    return Scaffold(
      backgroundColor: dn.surface,
      appBar: AppBar(
        backgroundColor: dn.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.saveAsPodcastTitle,
                style: DNText.serif(size: 16, color: dn.onSurface),),
            Text(l10n.saveAsPodcastSubtitle,
                style: DNText.mono(size: 9, color: dn.onSurface3),),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Recording card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dn.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: DNColors.terra,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppIcon(widget.isVideoReplay ? AppIcon.video : AppIcon.mic,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roomTitle ?? 'Session audio',
                        style: DNText.sans(
                            size: 13, w: FontWeight.w600, color: dn.onSurface,),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$durStr · ${widget.isVideoReplay ? l10n.podcastVideoEpisodeLabel : '~142 MB'}',
                        style: DNText.mono(size: 9, color: dn.onSurface3),
                      ),
                      if (widget.isVideoReplay && widget.videoUrl == null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.podcastVideoProcessing,
                              style: DNText.mono(size: 8, color: DNColors.terra),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _Label(l10n.podcastEpisodeTitleLabel),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: DNText.sans(size: 14, w: FontWeight.w600, color: dn.onSurface),
            decoration: _inputDeco(l10n.podcastEpisodeTitleLabel, dn),
          ),
          const SizedBox(height: 14),

          _Label(l10n.podcastCoverLabel),
          const SizedBox(height: 6),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: dn.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dn.onSurface4, style: BorderStyle.none),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: DNColors.teal, size: 20),
                const SizedBox(width: 8),
                Text(l10n.kenteMotifAuto,
                    style: DNText.mono(size: 9, color: dn.onSurface3),),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              _Label(l10n.podcastAiChaptersLabel),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DNColors.teal,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(l10n.autoLabel,
                    style: DNText.mono(size: 8, color: DNColors.paper),),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._chapters.map((c) => _ChapterRow(ts: c.$1, label: c.$2)),
          const SizedBox(height: 14),

          _Label(l10n.podcastVisibilityLabel),
          const SizedBox(height: 6),
          Row(
            children: [
              ('public', 'Public'),
              ('followers', l10n.podcastFollowersVisibility),
              ('private', l10n.podcastPrivateVisibility),
            ].map((v) {
              final sel = _visibility == v.$1;
              return GestureDetector(
                onTap: () => setState(() => _visibility = v.$1),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? dn.onSurface : dn.surface2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(v.$2,
                      style: DNText.mono(
                          size: 9,
                          color: sel ? dn.surface : dn.onSurface3,),),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.postPublicationTips,
                  style: DNText.sans(size: 13, color: dn.onSurface),),
              Switch.adaptive(
                value: _tipsEnabled,
                onChanged: (v) => setState(() => _tipsEnabled = v),
                activeThumbColor: DNColors.terra,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: dn.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: dn.onSurface,
                  side: BorderSide(color: dn.onSurface4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                ),
                child: Text(l10n.keepPrivate,
                    style: DNText.sans(size: 14, color: dn.onSurface),),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isPublishing
                    ? null
                    : () => setState(() => _isPublishing = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DNColors.terra,
                  foregroundColor: DNColors.paper,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                  elevation: 0,
                ),
                child: _isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2,),
                      )
                    : Text('📤 ${l10n.podcastPublish}',
                        style: DNText.sans(
                            size: 14,
                            w: FontWeight.w600,
                            color: DNColors.paper,),),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, DNTheme dn) => InputDecoration(
        hintText: hint,
        hintStyle: DNText.sans(size: 13, color: dn.onSurface4),
        filled: true,
        fillColor: dn.surface2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dn.onSurface4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DNColors.terra, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(),
          style: DNText.mono(size: 9, color: context.dn.onSurface3),);
}

class _ChapterRow extends StatelessWidget {
  final Duration ts;
  final String label;

  const _ChapterRow({required this.ts, required this.label});

  String get _fmtTs {
    final m = ts.inMinutes.toString().padLeft(2, '0');
    final s = (ts.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(
              width: 44,
              alignment: Alignment.centerRight,
              child: Text(_fmtTs,
                  style: DNText.mono(size: 9, color: DNColors.terra),),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: DNText.sans(size: 13, color: context.dn.onSurface),),
            ),
          ],
        ),
      );
}
