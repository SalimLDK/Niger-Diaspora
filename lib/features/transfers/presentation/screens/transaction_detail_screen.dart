import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/support_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/recipient_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transfer_failure_kind.dart';
import '../providers/transfer_provider.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionStream = ref.watch(
      watchTransactionProvider(transactionId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details du transfert'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed:
                () => _shareTransaction(context, transactionStream.value),
          ),
        ],
      ),
      body: transactionStream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Erreur: $error'),
                ],
              ),
            ),
        data: (transaction) => _buildContent(context, ref, transaction),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity transaction,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(context, transaction),
          const SizedBox(height: 24),
          _buildAmountCard(context, transaction),
          const SizedBox(height: 24),
          _buildRecipientCard(context, transaction),
          const SizedBox(height: 24),
          _buildDetailsCard(context, transaction),
          if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildNotesCard(context, transaction),
          ],
          const SizedBox(height: 24),
          _buildActionsCard(context, ref, transaction),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, TransactionEntity transaction) {
    final statusInfo = _getStatusInfo(context, transaction);

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: statusInfo.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusInfo.icon, size: 40, color: statusInfo.color),
            ),
            const SizedBox(height: 16),
            Text(
              statusInfo.label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: statusInfo.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusInfo.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            // L'état du débit est ce que l'utilisateur cherche en premier :
            // il est affiché à part, pas noyé dans la description.
            if (statusInfo.debitNotice != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusInfo.debitNotice!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (transaction.status.isActive) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, TransactionEntity transaction) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: transaction.currency,
    );
    final xofFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: Currency.xof.code,
      decimalDigits: 0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Montant envoye'),
                Text(
                  currencyFormat.format(transaction.amount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Frais'),
                Text(
                  currencyFormat.format(transaction.fee),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total debite',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  currencyFormat.format(transaction.totalCharged),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Taux de change'),
                Text(
                  '1 ${transaction.currency} = ${transaction.exchangeRate.toStringAsFixed(2)} ${Currency.xof.code}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Montant recu',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    xofFormat.format(transaction.amountInXof),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientCard(
    BuildContext context,
    TransactionEntity transaction,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beneficiaire',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    _getInitials(transaction.recipientName ?? ''),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.recipientName ?? 'Inconnu',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (transaction.recipientPhone != null)
                        Text(
                          transaction.recipientPhone!,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    TransactionEntity transaction,
  ) {
    final dateFormat = DateFormat('dd MMMM yyyy a HH:mm', 'fr_FR');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              context,
              'Reference',
              transaction.id.substring(0, 8).toUpperCase(),
              canCopy: true,
              fullValue: transaction.id,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              'Mode de paiement',
              transaction.provider.label,
            ),
            if (transaction.paymentIntentId != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                'ID Stripe',
                '${transaction.paymentIntentId!.substring(0, 12)}...',
                canCopy: true,
                fullValue: transaction.paymentIntentId,
              ),
            ],
            if (transaction.mynitaReference != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                'Ref. MyNita',
                transaction.mynitaReference!,
                canCopy: true,
              ),
            ],
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              'Date',
              transaction.createdAt != null
                  ? dateFormat.format(transaction.createdAt!)
                  : 'Non disponible',
            ),
            if (transaction.completedAt != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                'Date de completion',
                dateFormat.format(transaction.completedAt!),
              ),
            ],
            if (transaction.failureReason != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                'Raison de l\'echec',
                transaction.failureReason!,
                isError: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool canCopy = false,
    String? fullValue,
    bool isError = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isError ? AppColors.error : null,
              ),
            ),
            if (canCopy) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: fullValue ?? value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copie dans le presse-papiers'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(
                  Icons.copy,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNotesCard(BuildContext context, TransactionEntity transaction) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              transaction.notes!,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity transaction,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // « Réessayer » n'est pas toujours le bon conseil : sur un doublon évité
    // il est inutile, et sur un débit incertain il peut débiter deux fois.
    final action = transaction.status == TransactionStatus.failed
        ? TransferFailureKind.fromReason(transaction.failureReason).action
        : null;

    return Column(
      children: [
        if (action == TransferFailureAction.retry) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _retryTransaction(context, ref, transaction),
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer le transfert'),
            ),
          ),
          const SizedBox(height: 12),
        ] else if (action == TransferFailureAction.fixRecipient) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/transfers/recipient'),
              icon: const Icon(Icons.person_search),
              label: Text(l10n.transferActionFixRecipient),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _contactSupport(context, transaction, ref),
            icon: const Icon(Icons.support_agent),
            label: const Text('Contacter le support'),
          ),
        ),
      ],
    );
  }

  /// Un échec n'est plus rendu de façon générique : le motif est classé, et
  /// l'écran dit ce qui est arrivé à l'argent. Voir [TransferFailureKind]
  /// pour la réserve importante — rien ne remplit `failureReason` aujourd'hui,
  /// donc en pratique on retombe sur le cas générique d'avant.
  _StatusInfo _failureInfo(BuildContext context, String? reason) {
    final l10n = AppLocalizations.of(context)!;
    final kind = TransferFailureKind.fromReason(reason);

    final debitNotice = switch (kind.debitState) {
      TransferDebitState.notCharged => l10n.transferDebitNotCharged,
      TransferDebitState.charged => l10n.transferDebitCharged,
      TransferDebitState.uncertain => l10n.transferDebitUncertain,
    };

    return switch (kind) {
      TransferFailureKind.operatorBlocked => _StatusInfo(
          icon: Icons.block,
          color: AppColors.error,
          label: l10n.transferFailOperatorBlockedTitle,
          description: l10n.transferFailOperatorBlockedDesc,
          debitNotice: debitNotice,
        ),
      TransferFailureKind.duplicatePrevented => _StatusInfo(
          icon: Icons.shield_outlined,
          color: AppColors.info,
          label: l10n.transferFailDuplicateTitle,
          description: l10n.transferFailDuplicateDesc,
          debitNotice: debitNotice,
        ),
      TransferFailureKind.invalidRecipient => _StatusInfo(
          icon: Icons.person_off_outlined,
          color: AppColors.warning,
          label: l10n.transferFailInvalidRecipientTitle,
          description: l10n.transferFailInvalidRecipientDesc,
          debitNotice: debitNotice,
        ),
      TransferFailureKind.paymentDeclined => _StatusInfo(
          icon: Icons.credit_card_off,
          color: AppColors.error,
          label: l10n.transferFailDeclinedTitle,
          description: l10n.transferFailDeclinedDesc,
          debitNotice: debitNotice,
        ),
      TransferFailureKind.insufficientFunds => _StatusInfo(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.warning,
          label: l10n.transferFailInsufficientTitle,
          description: l10n.transferFailInsufficientDesc,
          debitNotice: debitNotice,
        ),
      TransferFailureKind.networkTimeout => _StatusInfo(
          icon: Icons.wifi_off,
          color: AppColors.warning,
          label: l10n.transferFailTimeoutTitle,
          description: l10n.transferFailTimeoutDesc,
          debitNotice: debitNotice,
        ),
      // Comportement historique conservé tel quel.
      TransferFailureKind.unknown => _StatusInfo(
          icon: Icons.error,
          color: AppColors.error,
          label: 'Echoue',
          description: 'Le transfert a echoue. Veuillez reessayer.',
        ),
    };
  }

  _StatusInfo _getStatusInfo(
    BuildContext context,
    TransactionEntity transaction,
  ) {
    if (transaction.status == TransactionStatus.failed) {
      return _failureInfo(context, transaction.failureReason);
    }
    switch (transaction.status) {
      case TransactionStatus.pending:
        return _StatusInfo(
          icon: Icons.schedule,
          color: AppColors.warning,
          label: 'En attente',
          description: 'Votre transfert est en attente de traitement.',
        );
      case TransactionStatus.processing:
        return _StatusInfo(
          icon: Icons.sync,
          color: AppColors.info,
          label: 'En cours',
          description: 'Votre transfert est en cours de traitement.',
        );
      case TransactionStatus.completed:
        return _StatusInfo(
          icon: Icons.check_circle,
          color: AppColors.success,
          label: 'Termine',
          description: 'Votre transfert a ete effectue avec succes !',
        );
      case TransactionStatus.failed:
        return _StatusInfo(
          icon: Icons.error,
          color: AppColors.error,
          label: 'Echoue',
          description: 'Le transfert a echoue. Veuillez reessayer.',
        );
      case TransactionStatus.refunded:
        return _StatusInfo(
          icon: Icons.replay,
          color: AppColors.info,
          label: 'Rembourse',
          description: 'Le montant a ete rembourse sur votre compte.',
        );
      case TransactionStatus.cancelled:
        return _StatusInfo(
          icon: Icons.cancel,
          color: AppColors.textTertiary,
          label: 'Annule',
          description: 'Ce transfert a ete annule.',
        );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  void _shareTransaction(BuildContext context, TransactionEntity? transaction) {
    if (transaction != null) {
      SharePlus.instance.share(
        ShareParams(
          text:
              'Transfert vers ${transaction.recipientName ?? 'Inconnu'}\n'
              'Montant: ${transaction.amount} ${transaction.currency}\n'
              'Ref: ${transactionId.substring(0, 8).toUpperCase()}',
        ),
      );
    }
  }

  void _retryTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity transaction,
  ) {
    // Reset state
    ref.read(transferStateNotifierProvider.notifier).reset();

    // Reconstruct recipient (partial)
    final recipient = RecipientEntity(
      id: transaction.recipientId,
      userId: transaction.senderId,
      fullName: transaction.recipientName ?? 'Inconnu',
      phone: transaction.recipientPhone ?? '',
      type:
          RecipientType
              .mobileWallet, // Default used as transaction entity doesn't store recipient type
    );
    ref.read(transferStateNotifierProvider.notifier).selectRecipient(recipient);

    // Set amount and currency
    ref
        .read(transferStateNotifierProvider.notifier)
        .setAmount(transaction.amount);
    ref
        .read(transferStateNotifierProvider.notifier)
        .setCurrency(transaction.currency);

    // Set notes
    if (transaction.notes != null) {
      ref
          .read(transferStateNotifierProvider.notifier)
          .setNotes(transaction.notes!);
    }

    // Navigate to send screen
    context.push('/transfers/send');
  }

  /// Pré-remplit la description du ticket avec le contexte du transfert.
  String _supportPrefill(TransactionEntity transaction) {
    final recipient = transaction.recipientName ??
        transaction.recipientPhone ??
        'bénéficiaire inconnu';
    return 'Concernant le transfert #${transaction.id}\n'
        'Bénéficiaire : $recipient\n'
        'Montant : ${transaction.amount.toStringAsFixed(2)} ${transaction.currency}\n'
        'Statut : ${transaction.status.label}\n\n'
        'Décrivez votre problème : ';
  }

  void _contactSupport(BuildContext context, TransactionEntity transaction, WidgetRef ref) {
    final supportService = ref.read(supportServiceProvider);
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Contacter le support',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // Ticket in-app qui embarque le transfert concerné (§11) :
                // la demande arrive au support avec la transaction liée.
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Ouvrir un ticket'),
                  subtitle: const Text('Le transfert est joint · réponse dans l\'app'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                      '/support/new',
                      extra: {
                        'transactionId': transaction.id,
                        'subject': 'Souci avec un transfert',
                        'description': _supportPrefill(transaction),
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(supportService.supportEmail),
                  onTap: () {
                    Navigator.pop(context);
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: supportService.supportEmail,
                      query: 'subject=Support Transaction ${transaction.id}',
                    );
                    launchUrl(emailLaunchUri);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Telephone'),
                  subtitle: const Text('+33 1 XX XX XX XX'),
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('tel:+33100000000'));
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String label;
  final String description;

  /// Phrase dédiée à l'état du débit — renseignée uniquement pour les échecs
  /// dont le motif a pu être classé.
  final String? debitNotice;

  _StatusInfo({
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
    this.debitNotice,
  });
}
