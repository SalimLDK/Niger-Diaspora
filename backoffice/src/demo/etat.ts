/**
 * Mode démo : la console tourne ENTIÈREMENT dans le navigateur, sur des données inventées.
 *
 * Garanties :
 *  - aucune requête vers Supabase, Firebase ni les Cloud Functions n'est émise tant que le mode est actif ;
 *  - rien n'est conservé : le drapeau et les données vivent en mémoire, un rechargement ramène à la connexion ;
 *  - le mode démo ne donne AUCUN accès réel : il remplace les appels, il ne les autorise pas. Le serveur continue de
 *    refuser tout ce qui vient d'une session non authentifiée.
 */
let actif = false

export const demoActif = (): boolean => actif

export function activerDemo(): void {
  actif = true
}

export function desactiverDemo(): void {
  actif = false
}

export const IDENTITE_DEMO = { id: 'demo-admin', nom: 'Compte de démonstration', email: 'demo@exemple.test' }
