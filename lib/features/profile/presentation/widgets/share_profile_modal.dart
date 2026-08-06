import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../providers/profile_provider.dart';
import '../providers/profile_share_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class ShareProfileDialog extends ConsumerStatefulWidget {
  final String? userName;
  final String? userPhotoUrl;
  final String? userId;

  const ShareProfileDialog({
    super.key,
    this.userName,
    this.userPhotoUrl,
    this.userId,
  });

  static Future<void> show(
    BuildContext context, {
    String? userName,
    String? userPhotoUrl,
    String? userId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => ShareProfileDialog(
            userName: userName,
            userPhotoUrl: userPhotoUrl,
            userId: userId,
          ),
    );
  }

  @override
  ConsumerState<ShareProfileDialog> createState() => _ShareProfileDialogState();
}

class _ShareProfileDialogState extends ConsumerState<ShareProfileDialog>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String? _shareUrl;
  bool _isLoading = true;
  bool _copied = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
    _generateLink();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateLink() async {
    // Si on a un userId, générer directement l'URL sans Firebase
    if (widget.userId != null) {
      setState(() {
        _shareUrl = 'https://diasponiger.com/p/u/${widget.userId}';
        _isLoading = false;
      });
      return;
    }

    // Sinon, essayer via le provider
    try {
      final url =
          await ref
              .read(profileShareNotifierProvider.notifier)
              .generateShareLink();
      if (mounted) {
        setState(() {
          _shareUrl = url;
          _isLoading = false;
          if (url == null) {
            _errorMessage = l10n.unableToGenerateLink;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur: $e';
        });
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header gradient
                  _buildHeader(isDark),

                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      children: [
                        if (_isLoading)
                          _buildLoadingState()
                        else if (_errorMessage != null)
                          _buildErrorState(isDark)
                        else if (_shareUrl != null) ...[
                          // QR Code
                          _buildQRCode(isDark),
                          const SizedBox(height: 20),

                          // Link display
                          _buildLinkDisplay(isDark),
                          const SizedBox(height: 20),

                          // Share buttons
                          _buildShareButtons(isDark),
                          const SizedBox(height: 16),

                          // Scan QR code button
                          _buildScanButton(isDark),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Column(
        children: [
          // Close button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32),
              Text(
                l10n.shareMyProfile,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Avatar
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child:
                    widget.userPhotoUrl != null
                        ? CachedNetworkImage(
                          imageUrl: widget.userPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: Center(
                                  child: Text(
                                    _getInitials(widget.userName ?? 'U'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: Center(
                                  child: Text(
                                    _getInitials(widget.userName ?? 'U'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                        )
                        : Container(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: Center(
                            child: Text(
                              _getInitials(widget.userName ?? 'U'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // User name
          if (widget.userName != null)
            Text(
              widget.userName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          // Métier · ville, si le profil est disponible (§21a).
          if (widget.userId != null)
            Builder(
              builder: (context) {
                final profile =
                    ref
                        .watch(profileNotifierProvider(widget.userId!))
                        .valueOrNull;
                final parts =
                    [profile?.profession, profile?.currentCity]
                        .where((e) => e != null && e.trim().isNotEmpty)
                        .cast<String>();
                if (parts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    parts.join(' · '),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.adaptivePrimaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.generatingLink,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: context.errorColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Oups!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? l10n.errorOccurred,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _generateLink();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
            style: TextButton.styleFrom(
              foregroundColor: context.adaptivePrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: _shareUrl!,
                version: QrVersions.auto,
                size: 196,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: const Color(0xFF1A1A2E),
                ),
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
              // Center logo
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Brand
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.scanToFindMe,
                  style: TextStyle(
                    color: context.adaptivePrimaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkDisplay(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _shareUrl!,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _copyLink,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient:
                      _copied
                          ? LinearGradient(
                            colors: [
                              AppColors.success,
                              AppColors.success.withValues(alpha: 0.8),
                            ],
                          )
                          : LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _copied ? 'Copié!' : l10n.copy,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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

  Widget _buildShareButtons(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shareVia,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ShareIconButton(
              icon: Icons.message_rounded,
              color: const Color(0xFF25D366),
              label: l10n.whatsApp,
              onTap: _shareViaWhatsApp,
            ),
            const SizedBox(width: 12),
            _ShareIconButton(
              icon: Icons.facebook_rounded,
              color: const Color(0xFF1877F2),
              label: l10n.facebook,
              onTap: _shareViaFacebook,
            ),
            const SizedBox(width: 12),
            _ShareIconButton(
              icon: Icons.close_rounded,
              color: isDark ? Colors.white : const Color(0xFF14171A),
              iconColor: isDark ? const Color(0xFF14171A) : Colors.white,
              label: 'X',
              onTap: _shareViaTwitter,
            ),
            const SizedBox(width: 12),
            _ShareIconButton(
              icon: Icons.more_horiz_rounded,
              color: AppColors.primary,
              label: l10n.more,
              onTap: _shareViaSystem,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          context.push('/qr-scanner');
        },
        icon: Icon(
          Icons.qr_code_scanner_rounded,
          color: context.adaptiveSecondaryColor,
        ),
        label: Text(
          l10n.scanQRCode,
          style: TextStyle(
            color: context.adaptiveSecondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: context.adaptiveSecondaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _copyLink() {
    if (_shareUrl != null) {
      HapticFeedback.mediumImpact();
      Clipboard.setData(ClipboardData(text: _shareUrl!));
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _copied = false);
        }
      });
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (_shareUrl == null) return;
    HapticFeedback.lightImpact();
    final message = 'Découvrez mon profil sur Diaspo Niger: $_shareUrl';
    final url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaFacebook() async {
    if (_shareUrl == null) return;
    HapticFeedback.lightImpact();
    final url = Uri.parse(
      'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_shareUrl!)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaTwitter() async {
    if (_shareUrl == null) return;
    HapticFeedback.lightImpact();
    final message = 'Découvrez mon profil sur Diaspo Niger: $_shareUrl';
    final url = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaSystem() async {
    if (_shareUrl == null) return;
    HapticFeedback.lightImpact();
    await SharePlus.instance.share(
      ShareParams(
        text: 'Découvrez mon profil sur Diaspo Niger: $_shareUrl',
        subject: l10n.myProfileOnDiaspoNiger,
      ),
    );
  }
}

class _ShareIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _ShareIconButton({
    required this.icon,
    required this.color,
    this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor ?? Colors.white, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Keep backward compatibility with old name
class ShareProfileModal extends ShareProfileDialog {
  const ShareProfileModal({
    super.key,
    super.userName,
    super.userPhotoUrl,
    super.userId,
  });

  static Future<void> show(
    BuildContext context, {
    String? userName,
    String? userPhotoUrl,
    String? userId,
  }) {
    return ShareProfileDialog.show(
      context,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      userId: userId,
    );
  }
}
