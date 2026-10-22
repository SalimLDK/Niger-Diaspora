import 'package:supabase_flutter/supabase_flutter.dart';

/// Motifs normalisés d'une décision sur un signalement.
///
/// Miroir de `signalement_transition` (migration 20261017100000) : la base
/// refuse tout autre code (22023). Les libellés vivent en l10n
/// (`adminMotifDismiss…` / `adminMotifResolve…`) ; ce fichier ne porte que les
/// codes, pour que l'écran et le test partent de la même liste.
const List<String> motifsClassementSansSuite = [
  'rule_not_violated',
  'insufficient_evidence',
  'content_unavailable',
  'duplicate',
  'out_of_scope',
];

const List<String> motifsDecisionAvecAction = [
  'content_removed',
  'user_warned',
  'user_suspended',
  'user_banned',
  'correction_requested',
];

/// Ce que le panneau dit d'un refus de `signalement_transition`.
///
/// Les messages du serveur sont déjà en français et sans donnée sensible ; on
/// les garde pour 42501 (permission, dossier d'un autre) et 22023 (motif,
/// justification). 55000 est le cas qu'un modérateur voit vraiment : un autre
/// a décidé entre-temps — le texte dit de recharger, pas de réessayer.
String messageTransitionSignalement(PostgrestException e) {
  switch (e.code) {
    case '55000':
      return 'Ce signalement a changé de statut entre-temps (un autre '
          'modérateur a peut-être décidé). Rechargez la liste.';
    case 'P0002':
      return 'Signalement introuvable : il a été supprimé.';
    case '42501':
    case '22023':
    case '22001':
      return e.message;
    default:
      return 'Décision non enregistrée : ${e.message}';
  }
}
