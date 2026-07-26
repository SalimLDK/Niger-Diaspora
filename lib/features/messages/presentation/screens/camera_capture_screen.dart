import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';

import 'gallery_picker_screen.dart';
import 'media_preview_screen.dart';

/// Un média capturé/choisi renvoyé au composer.
class CameraMedia {
  final File file;
  final bool isVideo;
  const CameraMedia({required this.file, required this.isVideo});
}

/// Caméra unifiée : on bascule Photo ↔ Vidéo dans le même écran, sans avoir
/// à choisir à l'avance. Après une capture, on passe par l'aperçu ; un retour
/// (back) revient directement à la caméra pour reprendre (retake).
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

enum _CaptureMode { photo, video }

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;
  _CaptureMode _mode = _CaptureMode.photo;
  FlashMode _flashMode = FlashMode.off;
  bool _isRecording = false;
  bool _initializing = true;
  String? _error;

  Timer? _recordTimer;
  int _recordSeconds = 0;

  // Vignette de la dernière photo/vidéo de la galerie (bouton galerie).
  Uint8List? _lastThumb;
  // Éclair blanc bref au déclenchement d'une photo.
  bool _flashOverlay = false;

  // Zoom (pincer pour zoomer)
  double _minZoom = 1;
  double _maxZoom = 1;
  double _baseZoom = 1;
  double _currentZoom = 1;

  // Mise au point (appui sur l'aperçu)
  Offset? _focusPoint;
  Timer? _focusTimer;

  // Grille de composition (règle des tiers)
  bool _showGrid = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = 'Aucune caméra disponible';
          _initializing = false;
        });
        return;
      }
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _initController();
      _loadLatestThumb();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Caméra indisponible';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _initController() async {
    final previous = _controller;
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
        _currentZoom = _minZoom;
        _baseZoom = _minZoom;
      } catch (_) {}
      await previous?.dispose();
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impossible d\'ouvrir la caméra';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _loadLatestThumb() async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) return;
      final albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common,
      );
      if (albums.isEmpty) return;
      final assets = await albums.first.getAssetListPaged(page: 0, size: 1);
      if (assets.isEmpty) return;
      final thumb =
          await assets.first.thumbnailDataWithSize(const ThumbnailSize.square(200));
      if (mounted) setState(() => _lastThumb = thumb);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _focusTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ----- Zoom (pincer) -----
  void _onScaleStart(ScaleStartDetails _) => _baseZoom = _currentZoom;

  Future<void> _onScaleUpdate(ScaleUpdateDetails d) async {
    final controller = _controller;
    if (controller == null || d.pointerCount < 2) return;
    final z = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
    if ((z - _currentZoom).abs() < 0.01) return;
    _currentZoom = z;
    try {
      await controller.setZoomLevel(z);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  // ----- Mise au point (appui) -----
  Future<void> _focusAt(Offset local, Size size) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final point = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (_) {}
    _focusTimer?.cancel();
    setState(() => _focusPoint = local);
    _focusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  /// Sélection depuis la galerie intégrée : un seul média passe par l'aperçu ;
  /// plusieurs sont renvoyés d'un coup pour envoi groupé.
  Future<void> _pickFromGallery() async {
    if (_isRecording || !mounted) return;
    final picks = await Navigator.push<List<GalleryPick>>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryPickerScreen()),
    );
    if (picks == null || picks.isEmpty || !mounted) return;
    if (picks.length == 1) {
      await _confirmMedia(picks.first.file, isVideo: picks.first.isVideo);
    } else {
      Navigator.pop(context, <CameraMedia>[
        for (final p in picks) CameraMedia(file: p.file, isVideo: p.isVideo),
      ]);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    await _initController();
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = _mode == _CaptureMode.video
        ? (_flashMode == FlashMode.torch ? FlashMode.off : FlashMode.torch)
        : (_flashMode == FlashMode.off
            ? FlashMode.auto
            : _flashMode == FlashMode.auto
                ? FlashMode.torch
                : FlashMode.off);
    _flashMode = next;
    await controller.setFlashMode(next);
    if (mounted) setState(() {});
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.torch:
      case FlashMode.always:
        return Icons.flash_on;
    }
  }

  void _setMode(_CaptureMode mode) {
    if (_isRecording || _mode == mode) return;
    setState(() => _mode = mode);
  }

  Future<void> _onShutter() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (_mode == _CaptureMode.photo) {
      try {
        HapticFeedback.lightImpact();
        setState(() => _flashOverlay = true);
        final xfile = await controller.takePicture();
        if (mounted) setState(() => _flashOverlay = false);
        if (!mounted) return;
        await _confirmMedia(File(xfile.path), isVideo: false);
      } catch (_) {
        if (mounted) setState(() => _flashOverlay = false);
      }
      return;
    }

    // Mode vidéo
    if (!_isRecording) {
      await Permission.microphone.request();
      try {
        await controller.startVideoRecording();
        HapticFeedback.mediumImpact();
        _recordSeconds = 0;
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordSeconds++);
        });
        setState(() => _isRecording = true);
      } catch (_) {}
    } else {
      try {
        final xfile = await controller.stopVideoRecording();
        _recordTimer?.cancel();
        HapticFeedback.mediumImpact();
        if (mounted) setState(() => _isRecording = false);
        if (!mounted) return;
        await _confirmMedia(File(xfile.path), isVideo: true);
      } catch (_) {
        _recordTimer?.cancel();
        if (mounted) setState(() => _isRecording = false);
      }
    }
  }

  /// Passe par l'aperçu. Si l'utilisateur envoie → on renvoie le média au
  /// composer ; s'il revient (back) → on reste sur la caméra (retake).
  Future<void> _confirmMedia(File file, {required bool isVideo}) async {
    final result = await Navigator.push<MediaPreviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(
          file: file,
          type: isVideo ? MediaType.video : MediaType.image,
          conversationId: '',
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.pop(context, <CameraMedia>[
        CameraMedia(file: result.file, isVideo: !result.isImage),
      ]);
    }
    // sinon : on reste sur la caméra (retake).
  }

  String get _timerText {
    final m = _recordSeconds ~/ 60;
    final s = _recordSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = !_initializing &&
        _error == null &&
        controller != null &&
        controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            Center(child: CameraPreview(controller))
          else if (_error != null)
            Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Gestes sur l'aperçu : appui = mise au point, pincer = zoom
          if (ready)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onTapUp: (d) => _focusAt(d.localPosition, size),
                  );
                },
              ),
            ),

          if (ready && _showGrid)
            const Positioned.fill(child: IgnorePointer(child: _GridOverlay())),

          if (_focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 32,
              top: _focusPoint!.dy - 32,
              child: const IgnorePointer(child: _FocusRing()),
            ),

          // Éclair blanc bref au déclenchement d'une photo
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _flashOverlay ? 0.7 : 0.0,
                duration: const Duration(milliseconds: 120),
                child: Container(color: Colors.white),
              ),
            ),
          ),

          // Barre du haut : fermer · timer · grille · flash
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _RoundIconButton(
                            icon: const AppIcon(
                              AppIcon.close,
                              color: Colors.white,
                              size: 24,
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        if (_isRecording)
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _timerText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (ready)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RoundIconButton(
                                  icon: Icon(
                                    _showGrid
                                        ? Icons.grid_on
                                        : Icons.grid_off,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onTap: () =>
                                      setState(() => _showGrid = !_showGrid),
                                ),
                                const SizedBox(width: 8),
                                _RoundIconButton(
                                  icon: Icon(
                                    _flashIcon,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onTap: _cycleFlash,
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
          ),

          // Contrôles du bas
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentZoom > _minZoom + 0.05) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentZoom.toStringAsFixed(1)}×',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (!_isRecording)
                        _ModeToggle(mode: _mode, onChanged: _setMode),
                      if (_mode == _CaptureMode.photo && !_isRecording) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Appui : photo · Maintien : vidéo',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: _GalleryButton(
                                thumb: _lastThumb,
                                onTap: _isRecording ? null : _pickFromGallery,
                              ),
                            ),
                          ),
                          _ShutterButton(
                            mode: _mode,
                            isRecording: _isRecording,
                            onTap: ready ? _onShutter : null,
                          ),
                          Expanded(
                            child: Center(
                              child: _RoundIconButton(
                                icon: Icon(
                                  Icons.cameraswitch,
                                  color: _isRecording
                                      ? Colors.white38
                                      : Colors.white,
                                  size: 24,
                                ),
                                onTap: _isRecording ? null : _flipCamera,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: icon,
        ),
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  final Uint8List? thumb;
  final VoidCallback? onTap;
  const _GalleryButton({required this.thumb, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white70, width: 1.5),
          color: Colors.black38,
        ),
        clipBehavior: Clip.antiAlias,
        child: thumb != null
            ? Image.memory(thumb!, fit: BoxFit.cover)
            : const Icon(Icons.photo_library, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final _CaptureMode mode;
  final ValueChanged<_CaptureMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget item(_CaptureMode m, String label) {
      final active = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(_CaptureMode.photo, 'PHOTO'),
          item(_CaptureMode.video, 'VIDÉO'),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final _CaptureMode mode;
  final bool isRecording;
  final VoidCallback? onTap;
  const _ShutterButton({
    required this.mode,
    required this.isRecording,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = mode == _CaptureMode.video;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isRecording ? 30 : 60,
            height: isRecording ? 30 : 60,
            decoration: BoxDecoration(
              color: isVideo ? Colors.red : Colors.white,
              borderRadius: BorderRadius.circular(isRecording ? 8 : 40),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusRing extends StatelessWidget {
  const _FocusRing();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.4, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter());
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
