import '../../features/businesses/domain/entities/business_entity.dart';

extension BusinessEntityCompat on BusinessEntity {
  bool get isBoostActive {
    if (!isBoosted) return false;
    if (boostExpiresAt == null) return true;
    return boostExpiresAt!.isAfter(DateTime.now());
  }

  String? get fullLocation {
    final parts = [city, country]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}
