/** Message lisible pour une erreur PostgREST ; un refus de droit n'est jamais un « succès vide ». */
export function messageErreur(e: unknown): string {
  const err = e as { code?: string; message?: string }
  if (err?.code === '42501') return "Accès refusé : vous n'avez pas la permission requise."
  if (err?.code === '55000') return err.message ?? "Transition impossible dans l'état actuel."
  if (err?.code === '22023') return err.message ?? 'Valeur refusée par le serveur.'
  if (err?.code === 'PGRST301' || err?.code === 'PGRST303') return 'Session expirée : reconnectez-vous.'
  return err?.message ?? 'Erreur inattendue.'
}
