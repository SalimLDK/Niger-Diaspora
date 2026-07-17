# Rollback & Données personnelles (RGPD)

Statut : pré-prod 2026-07-15.

## 1. Stratégie de rollback

### 1.1 Application mobile (iOS / Android)
- **Versionner chaque release** : `pubspec.yaml` (`version: x.y.z+build`). Ne
  jamais réutiliser un `build number`.
- **Android** : conserver l'AAB signé + le mapping R8 de CHAQUE build publié
  (`releases/`). Rollback = re-promouvoir l'AAB précédent via Play Console
  (les utilisateurs déjà mis à jour ne redescendent pas — prévoir un correctif
  forward si bug critique).
- **iOS** : App Store ne permet pas le rollback binaire. Rollback = soumission
  expédiée d'un build corrigé (prévoir un délai de revue) ; garder la version
  N-1 prête à re-soumettre.
- **Kill-switch applicatif** : utiliser `firebase_remote_config` (déjà dans les
  dépendances) pour désactiver à distance une feature qui dérape sans republier.

### 1.2 Base de données (Supabase — base PARTAGÉE)
- **Avant toute migration en prod** : snapshot/backup PITR Supabase
  (Dashboard > Database > Backups). Noter le point de restauration.
- **Migrations idempotentes** : `supabase/migrations/` — la migration initiale a
  été rendue rejouable (2026-07-15 : `CREATE TABLE/INDEX IF NOT EXISTS`,
  `DROP POLICY IF EXISTS` + `CREATE`, `CREATE OR REPLACE TRIGGER`).
- **Down-migrations** : Supabase ne les génère pas automatiquement. Pour toute
  migration à risque (drop/rename/backfill), écrire un script de compensation
  `-- ROLLBACK:` en commentaire en tête de fichier, ou une migration inverse
  dédiée. **Rappel base partagée** : ne jamais `DROP` une table/colonne sans
  vérifier qu'aucun autre projet (smartbudget) ne la référence.
- **Ordre de restauration** : restaurer la base AVANT de rollback l'app si le
  schéma a changé de façon incompatible.

### 1.3 Edge Functions
- Redéploiement versionné (`supabase functions deploy <name>`). Garder le commit
  précédent taggé pour redeploy immédiat.

## 2. Données personnelles (RGPD)

### 2.1 Suppression de compte — ✅ implémentée
`auth_remote_datasource.dart:276` (`deleteAccount`) :
- Ordre sûr : nettoyage Supabase d'abord, suppression Firebase Auth ensuite
  (évite les données orphelines si échec).
- Couvre : `users` (cascade FK), `conversations` (suppression si ≤2 participants,
  sinon retrait de l'utilisateur), retrait des `groups`.
- Exposée dans l'UI : `settings_screen.dart:505` avec confirmation
  (`deleteAccountWarning`).
- **À compléter** : purge des nœuds Firebase RTDB liés à l'utilisateur
  (réactions, accusés de lecture, présence — cf `docs/ADR-messaging-source-of-truth.md`)
  et des fichiers Firebase Storage. Vérifier qu'aucune donnée résiduelle ne
  subsiste hors de la table `users`.

### 2.2 Export des données — ❌ NON implémenté (à faire)
Le droit à la portabilité (RGPD art. 20) n'est pas couvert : aucun
`exportUserData`/`downloadMyData` dans le code.

**Plan d'implémentation recommandé** (Edge Function `export-my-data`) :
1. Fonction serveur authentifiée (vérifie le Firebase ID token, comme
   `auth-firebase-exchange`), qui lit avec la service_role key **côté serveur
   uniquement**.
2. Agrège pour le `firebase_uid` courant : `users`, `transactions`,
   `recipients`, `posts`, `post_comments`, `conversations`+`messages` (dont
   l'utilisateur est participant), `orders`, `businesses`, `products`,
   `events`, `notifications`, `legal_acceptances` + les nœuds RTDB résiduels.
3. Retourne un JSON (ou ZIP) ; livraison par lien signé à durée limitée ou
   email. Ne jamais passer de données perso en query string.
4. Exposer dans `settings_screen` à côté de « Supprimer le compte ».

### 2.3 Base légale & information
- Écran politique de confidentialité présent (`privacy_policy_screen.dart`),
  acceptations tracées (`legal_acceptances`).
- **À confirmer avec le juridique** : base légale de chaque traitement
  (consentement pub/tracking, exécution du contrat pour la marketplace,
  intérêt légitime pour la localisation), et registre des traitements si cible
  UE. Le tracking pub (AdMob/IDFA) exige consentement explicite (ATT iOS +
  Consent Mode Android).

## 3. Checklist go-live (rollback & data)
- [ ] Backup PITR Supabase pris juste avant la migration de prod.
- [ ] AAB + mapping R8 de la release archivés.
- [ ] Remote Config kill-switch testé.
- [ ] `deleteAccount` complété (RTDB + Storage) et testé bout en bout.
- [ ] Edge Function `export-my-data` livrée et exposée dans les réglages.
- [ ] Base légale RGPD validée par le juridique.
