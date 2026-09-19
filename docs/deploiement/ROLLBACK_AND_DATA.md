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
  ⚠️ **État réel relevé le 2026-09-19** (`supabase backups list --project-ref
  zyrfkcjjrhddpfxcgezo`) : sauvegardes physiques (WAL-G) **actives**, **PITR
  DÉSACTIVÉ**, aucune date listée par la CLI. Il n'y a donc pas de « point de
  restauration » à la seconde : on restaure la sauvegarde quotidienne la plus
  proche. **La durée de conservation n'est pas lisible par la CLI** — à relever
  dans Dashboard > Database > Backups et à noter ici : `___ jours`. Tant que ce
  chiffre manque, le texte de confidentialité ne peut pas dire combien de temps
  une donnée supprimée survit dans les sauvegardes.
- **Après TOUTE restauration** : rejouer les suppressions de compte (§ 2.1).
  Sans cela, les comptes supprimés depuis la sauvegarde réapparaissent.
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

### 2.1 Suppression de compte — ✅ réparée le 2026-09-18 (migration appliquée, fonction à déployer)
L'ancien flux (`deleteAccount`) ne supprimait presque rien côté Supabase : DELETE
sur `users` sans policy DELETE (0 ligne, sans erreur), conversations réservées à
`created_by`, `groups.member_ids` vide partout. Seul le compte Firebase
disparaissait. Le client ne supprime plus rien lui-même.

Modèle : **demande → désactivation immédiate → 30 jours → purge.**
- **Demande** : RPC `request_account_deletion`
  (`auth_remote_datasource.dart`, `requestAccountDeletion`). Profil et
  publications masqués, push arrêté, commerces dépubliés, sessions Supabase
  révoquées. Se reconnecter avant l'échéance annule (`cancel_account_deletion`,
  écran `/account-deletion`). UI : `profile_screen.dart`.
- **Finalisation** : Cloud Function planifiée `finalizeAccountDeletions`
  (`functions/index.js`) — supprime le compte Firebase (→ `cleanupUserData` :
  Firestore, RTDB, Storage), écrit la pierre tombale `deleted_accounts/<uid>`,
  puis purge Supabase en UNE transaction (`private.purge_account`). Déploiement :
  `firebase deploy --only functions:finalizeAccountDeletions`, jamais `--force`.
- **Refus** : compte plateforme ; obligations financières OUVERTES (commande en
  cours, séquestre retenu, litige, virement en attente). Les dossiers clos ne
  bloquent pas — voir ci-dessous.
- **Historique financier** (migration `20260919113700`, non appliquée) : les
  dossiers clos sont CONSERVÉS avec leurs faits comptables (montants, dates,
  statuts, uid, identifiants Stripe) ; le texte libre et les coordonnées de la
  personne sont effacés ; une tâche nocturne coupe le lien (uid, identifiants
  Stripe) une fois la durée dépassée pour un compte supprimé. **Inerte tant que
  `app_config.financial_retention_years` n'est pas posée** : sans elle un dossier
  clos bloque encore la suppression. La durée est une décision juridique, pas
  technique — faire relire la liste des champs effacés (surtout les transferts)
  avant de la poser.
- **Clés et base MLS du téléphone** (migration `20260919123300`, non appliquée) :
  effacées À RETARDEMENT — la demande pose un marqueur local ; au premier
  lancement qui suit l'échéance + 1 jour, le téléphone demande au serveur, sans
  compte, si la suppression est menée à terme (`account_deletion_completed`, un
  booléen), et seulement alors efface la base MLS, les clés Signal, les clés
  dérivées, les vérifications et curseurs de CE compte. Une annulation faite sur un
  autre appareil n'efface donc rien. Sans elle, rien ne les détruisait : ni la
  déconnexion, ni la suppression.
- **Ce qui n'est PAS effacé** : les sauvegardes Supabase jusqu'à leur expiration
  (durée NON relevée, § 1.2) ; les dossiers financiers clos jusqu'à l'échéance de
  conservation. Détail et décisions ouvertes dans `TESTS_APPAREIL_A_FAIRE.md`
  (« Supprimer mon compte »).
- Le site public `public/delete-account.html` **n'est pas rebranché** : il
  supprime encore Firestore puis le compte Firebase, jamais Supabase, et son
  texte promet « toutes vos données effacées ».

#### Après une restauration Supabase : rejouer les suppressions
Une restauration ramène la base à un instant passé : les comptes supprimés
depuis la sauvegarde y réapparaissent (profil, messages, amitiés,
appartenances), alors que leur compte Firebase n'existe plus. Personne ne peut
s'y connecter, mais leur contenu redevient visible des autres.
`account_deletion_requests` est restaurée avec le reste : elle ne peut pas s'en
souvenir. La mémoire est donc dans Firestore, hors de portée d'une restauration
Supabase : `deleted_accounts/<uid>` (un uid et une date, ni nom ni e-mail),
écrite par `finalizeAccountDeletions` AVANT chaque purge — et la purge est
refusée si elle n'est pas écrite.

Procédure, à faire **à la main après TOUTE restauration** :
1. Restaurer.
2. `node tools/rejouer_suppressions_apres_restauration.mjs` — simulation : liste
   les comptes dont la base montre des restes, sans rien modifier.
3. Relire la liste, puis `--apply`.
4. Relancer la simulation : « 0 à rejouer ».

Prérequis : `cd functions && npm install`, un compte de service avec accès en
lecture à Firestore et à Firebase Auth (`GOOGLE_APPLICATION_CREDENTIALS`),
`SUPABASE_URL` et `SUPABASE_SERVICE_KEY` (à défaut lus dans `functions/.env`).
Garde-fous du script : jamais de purge d'un uid dont le compte Firebase existe
encore, ni sur un doute de lecture ; plafond de 200 comptes d'un coup.

Ce que la procédure ne couvre pas : une suppression encore `pending` au moment
de la sauvegarde puis perdue par la restauration — la personne retrouve un
compte actif et doit redemander. Ce n'est pas une fuite.

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
- [ ] Suppression de compte : fonction `finalizeAccountDeletions` déployée, et testée
  bout en bout sur un compte jetable (entrée P0 de `TESTS_APPAREIL_A_FAIRE.md`).
- [ ] Durée de conservation des sauvegardes Supabase relevée (§ 1.2) et reportée dans
  le texte de confidentialité.
- [ ] Procédure « après une restauration » (§ 2.1) essayée une fois à blanc.
- [x] Edge Function `export-my-data` livrée et exposée dans les réglages (code) — reste `supabase functions deploy export-my-data`.
- [ ] Base légale RGPD validée par le juridique.
