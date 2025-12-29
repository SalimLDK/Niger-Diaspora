import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/group_entity.dart';

class ShareGroupDialog extends ConsumerStatefulWidget {
  final String groupName;
  final String? groupImageUrl;
  final String groupId;
  final GroupCategory category;

  const ShareGroupDialog({
    super.key,
    required this.groupName,
    this.groupImageUrl,
    required this.groupId,
    required this.category,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupName,
    String? groupImageUrl,
    required String groupId,
    required GroupCategory category,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => ShareGroupDialog(
            groupName: groupName,
            groupImageUrl: groupImageUrl,
            groupId: groupId,
            category: category,
          ),
    );
  }

  @override
  ConsumerState<ShareGroupDialog> createState() => _ShareGroupDialogState();
}

class _ShareGroupDialogState extends ConsumerState<ShareGroupDialog>
    with SingleTickerProviderStateMixin {
  late String _shareUrl;
  bool _copied = false;
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
    _shareUrl = 'https://diaspo-niger.web.app/g/${widget.groupId}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;

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
                  _buildHeader(isDark, l10n),

                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      children: [
                        // QR Code
                        _buildQRCode(isDark, l10n),
                        const SizedBox(height: 20),

                        // Link display
                        _buildLinkDisplay(isDark),
                        const SizedBox(height: 20),

                        // Share buttons
                        _buildShareButtons(isDark, l10n),
                        const SizedBox(height: 16),

                        // TODO: Scan QR code button - disabled temporarily
                        // _buildScanButton(isDark, l10n),
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

  Widget _buildHeader(bool isDark, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.adaptiveSecondaryColor,
            context.adaptiveSecondaryColor.withValues(alpha: 0.8),
          ],
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
                'Partager le groupe',
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

          // Group icon
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
                    widget.groupImageUrl != null
                        ? Image.network(
                          widget.groupImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Icon(
                                Icons.groups,
                                color: context.adaptiveSecondaryColor,
                                size: 28,
                              ),
                        )
                        : Icon(
                          Icons.groups,
                          color: context.adaptiveSecondaryColor,
                          size: 28,
                        ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Group name
          Text(
            widget.groupName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          // Category
          Text(
            widget.category.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.adaptiveSecondaryColor.withValues(alpha: 0.15),
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
                data: _shareUrl,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: context.adaptiveSecondaryColor,
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
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.adaptiveSecondaryColor,
                        context.adaptiveSecondaryColor.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
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
              color: context.adaptiveSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 14,
                  color: context.adaptiveSecondaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Scannez pour rejoindre',
                  style: TextStyle(
                    color: context.adaptiveSecondaryColor,
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
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.08)
                : context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.adaptiveSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.link_rounded,
              size: 18,
              color: context.adaptiveSecondaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _shareUrl,
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
                              Colors.green,
                              Colors.green.withValues(alpha: 0.8),
                            ],
                          )
                          : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.adaptiveSecondaryColor,
                              context.adaptiveSecondaryColor.withValues(
                                alpha: 0.8,
                              ),
                            ],
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
                      _copied ? 'Copié!' : 'Copier',
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

  Widget _buildShareButtons(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Partager via',
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
              label: 'WhatsApp',
              onTap: _shareViaWhatsApp,
            ),
            const SizedBox(width: 12),
            _ShareIconButton(
              icon: Icons.facebook_rounded,
              color: const Color(0xFF1877F2),
              label: 'Facebook',
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
              color: context.adaptiveSecondaryColor,
              label: 'Plus',
              onTap: _shareViaSystem,
            ),
          ],
        ),
      ],
    );
  }

  void _copyLink() {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: _shareUrl));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  Future<void> _shareViaWhatsApp() async {
    HapticFeedback.lightImpact();
    final message =
        'Rejoignez le groupe "${widget.groupName}" sur Diaspo Niger: $_shareUrl';
    final url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaFacebook() async {
    HapticFeedback.lightImpact();
    final url = Uri.parse(
      'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_shareUrl)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaTwitter() async {
    HapticFeedback.lightImpact();
    final message =
        'Rejoignez le groupe "${widget.groupName}" sur Diaspo Niger: $_shareUrl';
    final url = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaSystem() async {
    HapticFeedback.lightImpact();
    await Share.share(
      'Rejoignez le groupe "${widget.groupName}" sur Diaspo Niger: $_shareUrl',
      subject: widget.groupName,
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
