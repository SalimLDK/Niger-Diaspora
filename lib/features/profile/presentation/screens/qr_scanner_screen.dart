import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/profile_share_provider.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  bool _flashOn = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
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
      _showError('QR code invalide');
      return;
    }

    // Extract userId from URL
    String? userId;
    String? shortCode;

    if (uri.host.contains('diasponiger.com') && uri.pathSegments.length >= 2) {
      if (uri.pathSegments[0] == 'p') {
        if (uri.pathSegments.length > 2 && uri.pathSegments[1] == 'u') {
          userId = uri.pathSegments[2];
        } else {
          shortCode = uri.pathSegments[1];
        }
      }
    }

    if (userId != null && userId.isNotEmpty) {
      _navigateToProfile(userId);
      return;
    }

    if (shortCode != null && shortCode.isNotEmpty) {
      try {
        final resolvedId = await ref.read(
          profileUserIdFromShareCodeProvider(shortCode).future,
        );
        if (mounted) {
          if (resolvedId != null) {
            _navigateToProfile(resolvedId);
          } else {
            _showError('Lien expiré ou introuvable');
          }
        }
      } catch (e) {
        if (mounted) _showError('Erreur de connexion');
      }
      return;
    }

    _showError('QR code invalide ou format non reconnu');
  }

  void _navigateToProfile(String userId) {
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
            Text('QR code scanné avec succès'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Overlay with scanning frame
          _buildOverlay(),

          // Top bar
          _buildTopBar(),

          // Bottom controls
          _buildBottomControls(),
        ],
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
                'Placez le QR code dans le cadre pour scanner',
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
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
                'Scanner un profil',
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
                label: _flashOn ? 'Flash actif' : 'Flash',
                onTap: _toggleFlash,
                isActive: _flashOn,
              ),

              // Switch camera
              _buildControlButton(
                icon: Icons.cameraswitch_rounded,
                label: 'Changer',
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
