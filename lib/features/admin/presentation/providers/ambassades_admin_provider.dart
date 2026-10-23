import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vérification, refus, suspension et réactivation d'une ambassade.
///
/// Les quatre gestes passent par les RPC de la migration 20261019090000 : le
/// serveur exige la source (adresse https et éditeur) pour vérifier, un motif
/// pour le reste, refuse un passage incohérent et écrit l'audit. Le client ne
/// pose plus `is_verified` ni `is_suspended` lui-même (le déclencheur de garde
/// le refuserait, super-administrateur compris).

SupabaseClient get _supabase => Supabase.instance.client;

class AmbassadesAdminActions {
  const AmbassadesAdminActions();

  Future<void> verifier(String id, {required String adresse, required String editeur}) =>
      _supabase.rpc('embassy_admin_verify',
          params: {'p_id': id, 'p_source_url': adresse, 'p_source': editeur});

  Future<void> refuser(String id, String motif) =>
      _supabase.rpc('embassy_admin_reject', params: {'p_id': id, 'p_reason': motif});

  Future<void> suspendre(String id, String motif) =>
      _supabase.rpc('embassy_admin_suspend', params: {'p_id': id, 'p_reason': motif});

  Future<void> reactiver(String id, String motif) =>
      _supabase.rpc('embassy_admin_unsuspend', params: {'p_id': id, 'p_reason': motif});
}

final ambassadesAdminActionsProvider = Provider((ref) => const AmbassadesAdminActions());

/// Le refus du serveur, en clair. Son texte n'est repris que pour une saisie
/// refusée (22023), où il dit quoi corriger.
String messageAmbassadeAdmin(Object e) {
  if (e is! PostgrestException) return e.toString();
  return switch (e.code) {
    '42501' => "Vous n'avez pas la permission d'effectuer cette action.",
    '55000' => "L'ambassade a changé entre-temps (${e.message}). Liste rechargée.",
    'P0002' => 'Ambassade introuvable.',
    '22023' || '22001' => e.message,
    _ => 'Action impossible : ${e.message}',
  };
}
