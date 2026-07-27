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

### 2.2 Export des données — ✅ implémenté (à déployer)
Droit à la portabilité (RGPD art. 20) couvert par l'Edge Function
`export-my-data` + `DataExportService` côté app.

- **Serveur** : `supabase/functions/export-my-data/index.ts`. Vérifie le
  Firebase ID token via les clés publiques Google (même mécanique que
  `auth-firebase-exchange`) ; la service_role key ne quitte jamais le serveur.
  N'exporte que les lignes rattachées au `firebase_uid` du token.
- **Client** : `lib/core/services/data_export_service.dart` → écrit le JSON
  dans un fichier temporaire et ouvre la feuille de partage système. Aucune
  donnée personnelle ne transite en query string.
- **UI** : `settings_screen.dart`, entrée « Exporter mes données » juste
  au-dessus de la zone de danger (clés l10n `exportMyData*`).

**Deux limites assumées, écrites dans l'export lui-même (`_notes`) :**
1. Le contenu des messages est chiffré de bout en bout — le serveur n'a pas les
   clés et ne peut pas le déchiffrer. Il sort donc tel qu'il est stocké.
2. Seuls les messages **dont l'utilisateur est l'auteur** sont exportés :
   exporter toute la conversation ferait fuiter les données de tiers, ce que la
   portabilité n'autorise pas.

Les tables sont déclarées avec plusieurs colonnes candidates ; une table ou une
colonne absente du schéma distant est reportée dans `_skipped` au lieu de faire
échouer l'export (le schéma distant a dérivé du dépôt).

**Reste à faire** : `supabase functions deploy export-my-data`, puis vérifier
`_skipped` sur un compte réel pour corriger les colonnes mal devinées. Les
nœuds RTDB résiduels ne sont pas encore inclus.

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
- [x] Edge Function `export-my-data` livrée et exposée dans les réglages (code) — reste `supabase functions deploy export-my-data`.
- [ ] Base légale RGPD validée par le juridique.
