import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../domain/entities/account_deletion_status.dart';
import '../providers/account_deletion_provider.dart';
import '../providers/auth_provider.dart';

/// Porte d'un compte dont la suppression est en cours (voir la migration
/// 20260918224100). Le routeur y envoie toute personne connectée dont
/// `account_deletion_requests` a une ligne `pending`, `blocked` ou `deleting` :
/// seules l'annulation et la déconnexion restent possibles.
class AccountDeletionPendingScreen extends ConsumerStatefulWidget {
  const AccountDeletionPendingScreen({super.key});

  @override
  ConsumerState<AccountDeletionPendingScreen> createState() =>
      _AccountDeletionPendingScreenState();
}

class _AccountDeletionPendingScreenState
    extends ConsumerState<AccountDeletionPendingScreen> {
  bool _busy = false;

  Future<void> _annuler(AppLocalizations l10n) async {
    setState(() => _busy = true);
    // Le messager est pris AVANT l'annulation : dès qu'elle aboutit, le
    // routeur emmène la personne sur l'accueil et détruit cet écran.
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(accountDeletionStatusProvider.notifier).cancel();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.accountDeletionCancelled : l10n.accountDeletionCancelFailed,
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // `valueOrNull` et non `.value` : ce dernier relance l'erreur en Riverpod 2.
    final status = ref.watch(accountDeletionStatusProvider).valueOrNull;
    // Entre l'annulation et la redirection du routeur : rien à montrer.
    if (status == null) return const Scaffold(body: SizedBox.shrink());

    final enCours = status.phase == AccountDeletionPhase.deleting;
    final date = LocaleHelper.formatFullDate(context, status.executeAt);

    return Scaffold(
      backgroundColor: context.surfaceVariantColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Icon(
                        enCours
                            ? Icons.hourglass_top_rounded
                            : Icons.delete_sweep_rounded,
                        size: 64,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    enCours
                        ? l10n.accountDeletionInProgressTitle
                        : l10n.accountDeletionPendingTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    enCours
                        ? l10n.accountDeletionInProgressBody
                        : l10n.accountDeletionPendingBody(date),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (status.cancellable)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _annuler(l10n),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            _busy
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                                : Text(l10n.accountDeletionCancelAction),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _busy
                            ? null
                            : () =>
                                ref
                                    .read(authNotifierProvider.notifier)
                                    .signOut(),
                    child: Text(l10n.logout),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
