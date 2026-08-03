import 'dart:io';

import 'package:flutter/material.dart';
import '../../../kit/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/support/domain/entities/support_ticket_entity.dart';
import '../../../../features/support/presentation/providers/support_ticket_provider.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  final String? relatedTransactionId;
  final String? prefillSubject;
  final String? prefillDescription;
  final TicketCategory? initialCategory;

  const CreateTicketScreen({
    super.key,
    this.relatedTransactionId,
    this.prefillSubject,
    this.prefillDescription,
    this.initialCategory,
  });

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;
  TicketCategory _category = TicketCategory.other;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _subjectController =
        TextEditingController(text: widget.prefillSubject ?? '');
    _descriptionController =
        TextEditingController(text: widget.prefillDescription ?? '');
    if (widget.initialCategory != null) {
      _category = widget.initialCategory!;
    } else if (widget.relatedTransactionId != null) {
      _category = TicketCategory.transaction;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(supportTicketNotifierProvider.notifier);
      await notifier.createTicket(
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        relatedTransactionId: widget.relatedTransactionId,
      );

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supportTicketCreated)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: DesignTitle(l10n.newSupportTicket, size: 22),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category selector
              Text(
                l10n.ticketCategory,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TicketCategory.values.map((cat) {
                  final isSelected = cat == _category;
                  return ChoiceChip(
                    label: Text(_categoryLabel(cat, l10n)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : context.textSecondaryColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: l10n.ticketSubject,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.ticketSubject;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.ticketDescription,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.ticketDescriptionRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Contexte technique joint automatiquement (§11) : évite un
              // aller-retour où le support demande version/OS/langue.
              _buildAutoAttachedBlock(context, l10n),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.sendReply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(TicketCategory category, AppLocalizations l10n) {
    return switch (category) {
      TicketCategory.transaction => l10n.ticketCategoryTransaction,
      TicketCategory.account => l10n.ticketCategoryAccount,
      TicketCategory.technical => l10n.ticketCategoryTechnical,
      TicketCategory.other => l10n.ticketCategoryOther,
    };
  }

  Widget _buildAutoAttachedBlock(BuildContext context, AppLocalizations l10n) {
    final os = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iOS'
            : Platform.operatingSystem;
    final lang = Localizations.localeOf(context).languageCode.toUpperCase();
    // NB : version d'app non affichée (pas de package_info_plus au projet) ;
    // à compléter (version + modèle via device_info_plus) si besoin.
    final context_ = 'Diaspo Niger · $os · $lang';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: context.textTertiaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.supportAutoAttached,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context_,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
