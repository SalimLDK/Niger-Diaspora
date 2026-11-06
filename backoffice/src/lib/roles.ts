import { getFunctions, httpsCallable } from 'firebase/functions'
import { fbApp } from './firebase'

export interface RoleInfo { id: string; label: string; limite: boolean }

/** Les huit rôles que `setAdminRole` sait attribuer. Les quatre derniers exigent la fonction déployée avec les rôles limités. */
export const ROLES: RoleInfo[] = [
  { id: 'superAdmin', label: 'Super-administrateur', limite: false },
  { id: 'contentMod', label: 'Modérateur de contenu', limite: false },
  { id: 'businessMod', label: 'Gestionnaire commercial', limite: false },
  { id: 'financeMod', label: 'Gestionnaire financier', limite: false },
  { id: 'supportAgent', label: 'Agent de support', limite: true },
  { id: 'validator', label: 'Validateur', limite: true },
  { id: 'auditor', label: 'Auditeur', limite: true },
  { id: 'analyst', label: 'Analyste', limite: true },
]

export const libelleRole = (id: string | null | undefined): string =>
  ROLES.find((r) => r.id === id)?.label ?? (id ? id : 'Aucun rôle')

/** Message lisible pour une erreur de la callable ; le serveur écrit déjà ses refus en français. */
export function messageCallable(e: unknown): string {
  const err = e as { code?: string; message?: string }
  switch (err?.code) {
    case 'functions/permission-denied':
      return err.message || 'Refusé : seul un super-administrateur peut attribuer un rôle.'
    case 'functions/unauthenticated':
      return 'Session expirée : reconnectez-vous.'
    case 'functions/not-found':
      return err.message || 'Compte introuvable : la personne doit se connecter une première fois à l\'application.'
    case 'functions/invalid-argument':
      return err.message || 'Valeur refusée par le serveur (rôle inconnu ?).'
    case 'functions/failed-precondition':
      return err.message || 'Opération refusée dans l\'état actuel.'
    default:
      return err?.message || 'Erreur inattendue.'
  }
}

/**
 * Attribue (ou retire, avec `none`) un rôle par la Cloud Function `setAdminRole` : elle revérifie que l'appelant est
 * super-administrateur dans Postgres, refuse l'auto-modification et le retrait du dernier super-administrateur,
 * écrit la base, pose le claim, et journalise. La console ne touche jamais la table des comptes directement.
 */
export async function definirRole(uid: string, adminRole: string): Promise<void> {
  const appeler = httpsCallable<{ uid: string; adminRole: string }, unknown>(getFunctions(fbApp), 'setAdminRole')
  await appeler({ uid, adminRole })
}
