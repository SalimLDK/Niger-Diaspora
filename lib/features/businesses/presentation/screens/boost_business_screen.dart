import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_boost_entity.dart';
import '../providers/business_provider.dart';
import '../../../../core/services/currency_service.dart';

class BoostBusinessScreen extends ConsumerStatefulWidget {
  final String businessId;
  final BusinessEntity? business;

  const BoostBusinessScreen({
    super.key,
    required this.businessId,
    this.business,
  });

  @override
  ConsumerState<BoostBusinessScreen> createState() =>
      _BoostBusinessScreenState();
}

class _BoostBusinessScreenState extends ConsumerState<BoostBusinessScreen> {
  BoostType _selectedType = BoostType.standard;
  BoostDuration _selectedDuration = BoostDuration.days7;
  bool _isLoading = false;

  double get _totalPrice => _selectedType.getPrice(_selectedDuration);

  Future<void> _purchaseBoost() async {
    setState(() => _isLoading = true);

    try {
      final success = await ref
          .read(boostNotifierProvider.notifier)
          .purchaseBoost(
            businessId: widget.businessId,
            type: _selectedType,
            duration: _selectedDuration,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boost active avec succes!')),
        );
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'achat du boost')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatPrice(double amount) {
    return CurrencyService.instance.format(amount, Currency.xof);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Booster votre entreprise')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.rocket_launch, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  'Augmentez votre visibilite',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apparaissez en premier dans les resultats de recherche et attirez plus de clients.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Boost type selection
          Text(
            'Type de boost',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<BoostType>(
            groupValue: _selectedType,
            onChanged: (value) {
              if (value != null) setState(() => _selectedType = value);
            },
            child: Column(
              children: BoostType.values.map((type) {
            final isSelected = _selectedType == type;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color:
                      isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                  width: 2,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _selectedType = type),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Radio<BoostType>(value: type),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  type.label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (type == BoostType.premium) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Recommande',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A partir de ${_formatPrice(type.basePrice)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Duration selection
          Text(
            'Duree',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                BoostDuration.values.map((duration) {
                  final isSelected = _selectedDuration == duration;
                  final price = _selectedType.getPrice(duration);
                  final savings =
                      duration == BoostDuration.days30
                          ? '~25% economise'
                          : duration == BoostDuration.days90
                          ? '~42% economise'
                          : null;

                  return ChoiceChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(duration.label),
                        Text(
                          _formatPrice(price),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                          ),
                        ),
                        if (savings != null)
                          Text(
                            savings,
                            style: TextStyle(
                              fontSize: 8,
                              color: isSelected ? Colors.white70 : Colors.green,
                            ),
                          ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected:
                        (_) => setState(() => _selectedDuration = duration),
                  );
                }).toList(),
          ),
          const SizedBox(height: 32),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Type:'),
                    Text(
                      _selectedType.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duree:'),
                    Text(
                      _selectedDuration.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:', style: theme.textTheme.titleMedium),
                    Text(
                      _formatPrice(_totalPrice),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Purchase button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _purchaseBoost,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt),
                          const SizedBox(width: 8),
                          Text(
                            'Acheter pour ${_formatPrice(_totalPrice)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 16),

          // Note
          Text(
            'Note: Le boost sera actif immediatement apres le paiement.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
