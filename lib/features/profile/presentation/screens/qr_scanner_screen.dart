import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_share_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late MobileScannerController _controller;

  bool _isProcessing = false;
  bool _flashOn = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
      autoStart: false,
    );

    // Start camera after first frame to avoid "widget tree locked" errors
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          await _controller.start();
          // debugPrint('Camera started successfully');
        } catch (e) {
          // debugPrint('Error starting camera: $e');
        }
      }
    });

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // debugPrint('QrScanner lifecycle: $state');

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        return;
      case AppLifecycleState.paused:
        // Only stop camera when fully paused (app in background)
        if (mounted && _controller.value.isInitialized) {
          _controller.stop();
        }
        break;
      case AppLifecycleState.resumed:
        // Restart camera when app comes back to foreground
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted && !_controller.value.isRunning) {
              try {
                await _controller.start();
              } catch (e) {
                // debugPrint('Error restarting camera: $e');
              }
            }
          });
        }
        break;
      case AppLifecycleState.inactive:
        // Don't stop camera on inactive - it's too aggressive
        // (triggers on notifications, app switcher, etc.)
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose controller which internally handles stopping
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? code = barcode.rawValue;

    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    // Parse the URL to extract userId
    _processQrCode(code);
  }

  Future<void> _processQrCode(String code) async {
    // Expected format: https://diasponiger.com/p/{userId}
    final uri = Uri.tryParse(code);

    if (uri == null) {
      _showError(l10n.invalidQRCode);
      return;
    }

    // Extract userId from URL
    String? userId;
    String? shortCode;

    if ((uri.host.contains('diasponiger.com') ||
            uri.host.contains('diaspo-niger.web.app')) &&
        uri.pathSegments.length >= 2) {
      if (uri.pathSegments[0] == 'p') {
        if (uri.pathSegments.length > 2 && uri.pathSegments[1] == 'u') {
          userId = uri.pathSegments[2];
        } else {
          shortCode = uri.pathSegments[1];
        }
      }
    }

    if (userId != null && userId.isNotEmpty) {
      await _navigateToProfile(userId);
      return;
    }

    if (shortCode != null && shortCode.isNotEmpty) {
      try {
        final resolvedId = await ref.read(
          profileUserIdFromShareCodeProvider(shortCode).future,
        );
        if (mounted) {
          if (resolvedId != null) {
            await _navigateToProfile(resolvedId);
          } else {
            _showError(l10n.linkExpiredOrNotFound);
          }
        }
      } catch (e) {
        if (mounted) _showError(l10n.connectionError);
      }
      return;
    }

    _showError(l10n.invalidQrCodeFormat);
  }

  Future<void> _navigateToProfile(String userId) async {
    // Stop camera before navigating to prevent BufferQueue errors
    await _controller.stop();

    if (!mounted) return;

    // Close scanner and navigate to profile
    context.pop();
    context.push('/profile/$userId');

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.white),
            const SizedBox(width: 12),
            Text(l10n.profileQRScanned),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    setState(() => _isProcessing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    _controller.toggleTorch();
    HapticFeedback.lightImpact();
  }

  void _switchCamera() {
    _controller.switchCamera();
    HapticFeedback.lightImpact();
  }

  bool _canPop = false;

  void _onBack() async {
    // If already processing back, ignore
    if (_canPop) return;

    setState(() => _isProcessing = true);

    try {
      if (_controller.value.isInitialized) {
        await _controller.stop();
      }
    } catch (e) {
      // debugPrint('Error stopping camera: $e');
    }

    if (mounted) {
      setState(() => _canPop = true);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera view - always mount, just overlay loading when not ready
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              fit: BoxFit.cover,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur caméra: ${error.errorCode.name}',
                        style: TextStyle(color: AppColors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Loading overlay while camera initializes
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                if (!state.isInitialized || !state.isRunning) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Overlay with scanning frame
            _buildOverlay(),

            // Top bar
            _buildTopBar(),

            // Bottom controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Scanning frame decoration
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary, width: 3),
              ),
              child: Stack(
                children: [
                  // Corner decorations
                  _buildCorner(Alignment.topLeft, true, true),
                  _buildCorner(Alignment.topRight, false, true),
                  _buildCorner(Alignment.bottomLeft, true, false),
                  _buildCorner(Alignment.bottomRight, false, false),

                  // Animated scanning line
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Positioned(
                        top: _animation.value * 260 + 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Instruction text
          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                l10n.placeQrCodeInFrame,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment, bool isLeft, bool isTop) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            left:
                isLeft
                    ? BorderSide(color: AppColors.white, width: 4)
                    : BorderSide.none,
            right:
                !isLeft
                    ? BorderSide(color: AppColors.white, width: 4)
                    : BorderSide.none,
            top:
                isTop
                    ? BorderSide(color: AppColors.white, width: 4)
                    : BorderSide.none,
            bottom:
                !isTop
                    ? BorderSide(color: AppColors.white, width: 4)
                    : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            Material(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _onBack,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.scanProfile,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Placeholder for symmetry
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Flash toggle
              _buildControlButton(
                icon: _flashOn ? Icons.flash_on : Icons.flash_off,
                label: _flashOn ? l10n.flashActive : l10n.flash,
                onTap: _toggleFlash,
                isActive: _flashOn,
              ),

              // Switch camera
              _buildControlButton(
                icon: Icons.cameraswitch_rounded,
                label: l10n.changeCard,
                onTap: _switchCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color:
                isActive
                    ? AppColors.primary.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isActive
                      ? AppColors.primary
                      : AppColors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
