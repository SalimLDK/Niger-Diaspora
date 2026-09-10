import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/feature_flag_service.dart';
import '../../../../core/services/qr_code_parser.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/profile_share_provider.dart';
import '../widgets/qr_scanner_control_bar.dart';
import '../widgets/share_profile_modal.dart';
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
  bool _myQrOpen = false;
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

  /// Ouvre ce que désigne le QR, quel que soit son type.
  ///
  /// Ce scanner est le seul de l'app à être atteignable depuis l'accueil : il
  /// doit reconnaître tous les QR du projet — profil, groupe, et les liens
  /// profonds partagés par le site — et pas seulement le profil.
  Future<void> _processQrCode(String code) async {
    final target = QrCodeParser.parse(code);

    if (target == null) {
      _showError(l10n.invalidQrCodeFormat);
      return;
    }

    switch (target.kind) {
      // Le rendez-vous de transfert se revendique sur son écran dédié : lui
      // seul sait gérer le cas « pas encore connecté », qui est la situation
      // normale d'un téléphone neuf.
      case QrCodeKind.keyTransfer:
        await _leaveFor(
          '/settings/security/transfer/receive',
          message: l10n.qrKeyTransferDetected,
        );
        return;

      case QrCodeKind.profileShortCode:
        await _openShortCode(target.shortCode!);
        return;

      default:
        final feature = _featureOf(target.kind);
        if (feature != null) {
          // Sans cette garde, le routeur renverrait silencieusement sur
          // /home (redirection des drapeaux phase 2) après un message de
          // succès : un scan qui « marche » et n'ouvre rien.
          final flags = ref.read(loadedFeatureFlagsProvider);
          if (flags != null &&
              !FeatureFlagService.isFeatureEnabled(flags, feature)) {
            _showError(l10n.comingSoonShort);
            return;
          }
        }
        await _leaveFor(target.routePath!, message: l10n.profileQRScanned);
    }
  }

  /// Fonctionnalité à vérifier avant d'ouvrir la route, ou `null` si la
  /// destination est toujours accessible.
  AppFeature? _featureOf(QrCodeKind kind) => switch (kind) {
    QrCodeKind.product => AppFeature.marketplace,
    QrCodeKind.podcast || QrCodeKind.episode => AppFeature.podcasts,
    QrCodeKind.audioRoom => AppFeature.audioRooms,
    _ => null,
  };

  /// Résout le code court `/p/<code>` en identifiant avant de naviguer.
  Future<void> _openShortCode(String shortCode) async {
    try {
      final resolvedId = await ref.read(
        profileUserIdFromShareCodeProvider(shortCode).future,
      );
      if (!mounted) return;
      if (resolvedId == null) {
        _showError(l10n.linkExpiredOrNotFound);
        return;
      }
      await _leaveFor('/profile/$resolvedId', message: l10n.profileQRScanned);
    } catch (e) {
      if (mounted) _showError(l10n.connectionError);
    }
  }

  Future<void> _leaveFor(String routePath, {required String message}) async {
    // Stop camera before navigating to prevent BufferQueue errors
    await _controller.stop();

    if (!mounted) return;

    // Close scanner and navigate to the scanned destination
    context.pop();
    context.push(routePath);

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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

  /// Affiche le QR de l'utilisateur courant sans quitter le scanner.
  ///
  /// La caméra est arrêtée le temps du dialogue : on montre son écran à
  /// quelqu'un, il n'y a aucune raison de continuer à filmer — et cela évite
  /// que la détection se déclenche derrière le dialogue.
  Future<void> _showMyQrCode() async {
    if (_myQrOpen || _isProcessing) return;

    setState(() => _myQrOpen = true);
    HapticFeedback.lightImpact();

    try {
      if (_controller.value.isRunning) {
        await _controller.stop();
      }
    } catch (_) {
      // Caméra déjà arrêtée : rien à faire.
    }

    try {
      // `.future` et non `.valueOrNull` : le provider est autoDispose, la
      // première lecture rendrait null et le dialogue s'ouvrirait sur
      // « Utilisateur non connecté ».
      //
      // Le délai borne cette attente : la caméra est déjà arrêtée, un stream
      // qui n'émet pas laisserait l'écran noir et le bouton sans effet. Le
      // `catch` ci-dessous le signale, le `finally` relance la caméra.
      final currentUser = await ref
          .read(currentUserAsyncProvider.future)
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;

      if (currentUser == null) {
        _showError(l10n.errorOccurred);
        return;
      }

      final profile =
          ref.read(profileNotifierProvider(currentUser.id)).valueOrNull;

      await ShareProfileDialog.show(
        context,
        userName: profile?.displayName ?? currentUser.displayName,
        userPhotoUrl: profile?.photoUrl ?? currentUser.photoUrl,
        userId: profile?.id ?? currentUser.id,
        showScanButton: false,
      );
    } catch (e) {
      if (mounted) _showError(l10n.connectionError);
    } finally {
      if (mounted) {
        setState(() => _myQrOpen = false);
        // Relance la caméra pour reprendre le scan là où on l'avait laissé.
        if (!_canPop && !_controller.value.isRunning) {
          try {
            await _controller.start();
          } catch (_) {
            // L'errorBuilder de MobileScanner rendra l'échec visible.
          }
        }
      }
    }
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
              // mobile_scanner 7.x a retire le troisieme parametre `child` de
              // `errorBuilder` : il n'etait jamais fourni. Signature a deux
              // arguments desormais.
              errorBuilder: (context, error) {
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
                    // Caméra arrêtée volontairement pour afficher « Mon QR
                    // Code » : un spinner ferait croire à une attente.
                    child:
                        _myQrOpen
                            ? null
                            : const Center(
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
                l10n.scanQrCode,
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
      child: QrScannerControlBar(
        flashOn: _flashOn,
        onToggleFlash: _toggleFlash,
        onSwitchCamera: _switchCamera,
        onShowMyQrCode: _showMyQrCode,
      ),
    );
  }
}
