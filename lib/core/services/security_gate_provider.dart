import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'security_gate_service.dart';

part 'security_gate_provider.g.dart';

/// Provider pour le service SecurityGate
@riverpod
SecurityGateService securityGate(Ref ref) {
  return SecurityGateService();
}

/// Provider pour vérifier si les paiements sont autorisés
@riverpod
Future<SecurityCheckResult> canMakePayment(Ref ref) async {
  final service = ref.read(securityGateProvider);
  return service.canMakePayment();
}

/// Provider pour vérifier si les transferts sont autorisés
@riverpod
Future<SecurityCheckResult> canMakeTransfer(Ref ref) async {
  final service = ref.read(securityGateProvider);
  return service.canMakeTransfer();
}

/// Provider pour vérifier l'accès au marketplace
@riverpod
Future<SecurityCheckResult> canUseMarketplace(Ref ref) async {
  final service = ref.read(securityGateProvider);
  return service.canUseMarketplace();
}
