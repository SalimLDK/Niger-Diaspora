import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../providers/legal_provider.dart';

class LegalUpdateDialog extends ConsumerStatefulWidget {
  const LegalUpdateDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LegalUpdateDialog(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<LegalUpdateDialog> createState() => _LegalUpdateDialogState();
}

class _LegalUpdateDialogState extends ConsumerState<LegalUpdateDialog> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final termsAsync = ref.watch(termsProvider);
    // Watch privacy policy provider to trigger reload when needed
    ref.watch(privacyPolicyProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.policy_outlined,
              color: context.adaptivePrimaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.legalUpdateTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.legalUpdateDescription,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Résumé des changements (si disponible)
            termsAsync.when(
              data: (terms) {
                if (terms.summary != null && terms.summary!.isNotEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.surfaceVariantColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.summaryOfChanges,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          terms.summary!,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Checkbox CGU
            CheckboxListTile(
              value: _termsAccepted,
              onChanged: (value) {
                setState(() => _termsAccepted = value ?? false);
              },
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.iAcceptThe,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/settings/terms'),
                    child: Text(
                      l10n.termsOfService,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.adaptivePrimaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: context.adaptivePrimaryColor,
            ),

            // Checkbox Politique de confidentialité
            CheckboxListTile(
              value: _privacyAccepted,
              onChanged: (value) {
                setState(() => _privacyAccepted = value ?? false);
              },
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.iAccept,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/settings/privacy'),
                    child: Text(
                      l10n.privacyPolicy,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.adaptivePrimaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: context.adaptivePrimaryColor,
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                (_termsAccepted && _privacyAccepted && !_isLoading)
                    ? _acceptTerms
                    : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      l10n.acceptAndContinue,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    );
  }

  Future<void> _acceptTerms() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      await ref.read(legalAcceptanceNotifierProvider.notifier).acceptTerms();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: context.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
