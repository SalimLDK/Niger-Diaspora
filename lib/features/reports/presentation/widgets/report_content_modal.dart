import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../domain/entities/report_entity.dart';
import '../providers/report_provider.dart';

/// Modal réutilisable pour signaler du contenu
class ReportContentModal extends ConsumerStatefulWidget {
  final ReportTargetType targetType;
  final String targetId;
  final String? targetName;
  final String? targetPreview;
  final String? conversationId;
  /// Snapshot du contenu pour préservation
  final ContentSnapshot? contentSnapshot;
  /// ID de l'utilisateur propriétaire du contenu signalé
  final String? reportedUserId;

  const ReportContentModal({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.targetPreview,
    this.conversationId,
    this.contentSnapshot,
    this.reportedUserId,
  });

  /// Affiche le modal de signalement
  static Future<bool?> show(
    BuildContext context, {
    required ReportTargetType targetType,
    required String targetId,
    String? targetName,
    String? targetPreview,
    String? conversationId,
    ContentSnapshot? contentSnapshot,
    String? reportedUserId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportContentModal(
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        targetPreview: targetPreview,
        conversationId: conversationId,
        contentSnapshot: contentSnapshot,
        reportedUserId: reportedUserId,
      ),
    );
  }

  /// Crée un snapshot pour un message texte
  static ContentSnapshot textMessageSnapshot(String content) {
    return ContentSnapshot(
      text: content,
      contentType: 'text',
      capturedAt: DateTime.now(),
    );
  }

  /// Crée un snapshot pour une image
  static ContentSnapshot imageSnapshot(String imageUrl, {String? caption}) {
    return ContentSnapshot(
      imageUrl: imageUrl,
      text: caption,
      contentType: 'image',
      capturedAt: DateTime.now(),
    );
  }

  /// Crée un snapshot pour une vidéo
  static ContentSnapshot videoSnapshot(String videoUrl, {String? caption}) {
    return ContentSnapshot(
      videoUrl: videoUrl,
      text: caption,
      contentType: 'video',
      capturedAt: DateTime.now(),
    );
  }

  /// Crée un snapshot pour un fichier/document
  static ContentSnapshot fileSnapshot(String fileUrl, String fileName) {
    return ContentSnapshot(
      fileUrl: fileUrl,
      fileName: fileName,
      contentType: 'file',
      capturedAt: DateTime.now(),
    );
  }

  /// Crée un snapshot pour un produit
  static ContentSnapshot productSnapshot({
    required String title,
    String? description,
    String? imageUrl,
    double? price,
    String? currency,
  }) {
    return ContentSnapshot(
      text: title,
      imageUrl: imageUrl,
      contentType: 'product',
      metadata: {
        'description': description,
        'price': price,
        'currency': currency,
      },
      capturedAt: DateTime.now(),
    );
  }

  /// Crée un snapshot pour un profil utilisateur
  static ContentSnapshot userProfileSnapshot({
    required String displayName,
    String? photoUrl,
    String? bio,
  }) {
    return ContentSnapshot(
      text: displayName,
      imageUrl: photoUrl,
      contentType: 'user',
      metadata: {
        'bio': bio,
      },
      capturedAt: DateTime.now(),
    );
  }

  /// Crée un snapshot pour un groupe
  static ContentSnapshot groupSnapshot({
    required String name,
    String? description,
    String? photoUrl,
  }) {
    return ContentSnapshot(
      text: name,
      imageUrl: photoUrl,
      contentType: 'group',
      metadata: {
        'description': description,
      },
      capturedAt: DateTime.now(),
    );
  }

  @override
  ConsumerState<ReportContentModal> createState() => _ReportContentModalState();
}

class _ReportContentModalState extends ConsumerState<ReportContentModal> {
  ReportReason? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _hasAlreadyReported = false;
  bool _alsoBlock = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyReported();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyReported() async {
    final hasReported = await ref
        .read(submitReportNotifierProvider.notifier)
        .hasAlreadyReported(
          targetType: widget.targetType,
          targetId: widget.targetId,
        );
    if (mounted) {
      setState(() => _hasAlreadyReported = hasReported);
    }
  }

  String get _targetTypeLabel {
    switch (widget.targetType) {
      case ReportTargetType.user:
        return 'cet utilisateur';
      case ReportTargetType.message:
        return 'ce message';
      case ReportTargetType.conversation:
        return 'cette conversation';
      case ReportTargetType.group:
        return 'ce groupe';
      case ReportTargetType.event:
        return 'cet événement';
      case ReportTargetType.business:
        return 'ce commerce';
      case ReportTargetType.product:
        return 'ce produit';
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(submitReportNotifierProvider.notifier)
        .submitReport(
          targetType: widget.targetType,
          targetId: widget.targetId,
          targetName: widget.targetName,
          targetPreview: widget.targetPreview,
          conversationId: widget.conversationId,
          reason: _selectedReason!,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          contentSnapshot: widget.contentSnapshot,
          reportedUserId: widget.reportedUserId,
        );

    // Bloquer aussi l'auteur si demandé (§27c).
    if (success && _alsoBlock && widget.reportedUserId != null) {
      await ref
          .read(blockUserNotifierProvider.notifier)
          .blockUser(
            targetUserId: widget.reportedUserId!,
            targetDisplayName: widget.targetName ?? 'Utilisateur',
          );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context, success);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Signalement envoyé. Merci pour votre aide.'
                : 'Erreur lors de l\'envoi du signalement',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poignée standardisée (§27/16).
            const SheetHandle(),
            const SizedBox(height: 20),

            // Title
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Signaler $_targetTypeLabel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Target name preview
            if (widget.targetName != null)
              Center(
                child: Text(
                  widget.targetName!,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),

            // Content preview (from snapshot)
            if (widget.contentSnapshot != null) ...[
              const SizedBox(height: 12),
              _buildContentPreview(),
            ],

            const SizedBox(height: 20),

            // Already reported warning
            if (_hasAlreadyReported) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vous avez déjà signalé ce contenu. Notre équipe examine votre signalement.',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    color: context.adaptivePrimaryColor,
                  ),
                ),
              )
            else if (!_hasAlreadyReported) ...[
              // Reason selection
              Text(
                'Pourquoi signalez-vous ce contenu ?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),

              // Reason chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReportReason.values.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return ChoiceChip(
                    label: Text(_getReasonLabel(reason)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedReason = selected ? reason : null;
                      });
                    },
                    selectedColor: context.adaptivePrimaryColor.withValues(alpha: 0.2),
                    checkmarkColor: context.adaptivePrimaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? context.adaptivePrimaryColor
                          : context.textSecondaryColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Description field
              Text(
                'Détails supplémentaires (optionnel)',
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Décrivez le problème...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.adaptivePrimaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bascule « bloquer aussi cet auteur » (§27c) — même modale.
              if (widget.reportedUserId != null)
                Container(
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    value: _alsoBlock,
                    onChanged: (v) => setState(() => _alsoBlock = v),
                    activeThumbColor: context.adaptivePrimaryColor,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      'Bloquer aussi cet auteur',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'Vous ne verrez plus ses messages ni sa position',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textTertiaryColor,
                      ),
                    ),
                  ),
                ),
              if (widget.reportedUserId != null) const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedReason != null ? _submitReport : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer le signalement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Info text : anonymat + délai d'examen annoncés (§27c).
              Text(
                'Votre signalement est anonyme et examiné par notre équipe sous '
                '48 h. Les faux signalements répétés peuvent entraîner des '
                'sanctions.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Close button if already reported
            if (_hasAlreadyReported)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Fermer'),
                ),
              ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildContentPreview() {
    final snapshot = widget.contentSnapshot!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getContentTypeIcon(snapshot.contentType),
                size: 16,
                color: context.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Contenu signalé',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Image preview
          if (snapshot.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                snapshot.imageUrl!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: context.dividerColor,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          // Text content
          if (snapshot.text != null && snapshot.text!.isNotEmpty) ...[
            if (snapshot.imageUrl != null) const SizedBox(height: 8),
            Text(
              snapshot.text!,
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimaryColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // File name
          if (snapshot.fileName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    snapshot.fileName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getContentTypeIcon(String? contentType) {
    switch (contentType) {
      case 'text':
        return Icons.chat_bubble_outline;
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'file':
        return Icons.attach_file;
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'user':
        return Icons.person_outline;
      case 'group':
        return Icons.group_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  String _getReasonLabel(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.harassment:
        return 'Harcèlement';
      case ReportReason.inappropriate:
        return 'Contenu inapproprié';
      case ReportReason.violence:
        return 'Violence';
      case ReportReason.hateSpeech:
        return 'Discours haineux';
      case ReportReason.scam:
        return 'Arnaque';
      case ReportReason.impersonation:
        return 'Usurpation d\'identité';
      case ReportReason.other:
        return 'Autre';
    }
  }
}
