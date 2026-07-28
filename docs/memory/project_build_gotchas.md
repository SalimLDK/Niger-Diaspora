---
name: project_build_gotchas
description: Deux pièges de build diaspo_niger — compileSdk doit rester 36 (faux SDK android-37) et le template l10n est app_fr.arb avec parité de métadonnées obligatoire
metadata: 
  node_type: memory
  type: project
  originSessionId: 7af77ac2-7325-47b9-a905-80f4ba42c51a
  modified: 2026-07-21T06:09:18.697Z
---

Deux causes de build cassé sur diaspo_niger, toutes deux au diagnostic trompeur (constaté le 2026-07-21).

**1. compileSdk Android doit rester 36.**
`android/app/build.gradle.kts` utilise `compileSdk = flutter.compileSdkVersion` (= 36) et
`android/build.gradle.kts` épingle `compileSdkVersion(36)` sur les sous-projets plugins.
Ne pas remettre `compileSdk = 37` : l'API 37 n'existe pas. Trois faux dossiers
(`android-37`, `android-37.0`, `android-37.bak`, copies d'android-36 avec `source.properties`
édité à la main) traînaient dans `%LOCALAPPDATA%\Android\Sdk\platforms` et ont été supprimés.
Symptôme : `Failed to find Platform SDK with path: platforms;android-37`, d'abord sur `:app`
puis sur les modules plugins.

**2. Le template l10n est `lib/l10n/app_fr.arb`, pas l'anglais.**
Défini par `template-arb-file: app_fr.arb` dans `l10n.yaml`. Toute clé à placeholder doit avoir
son bloc `"@clé": { "placeholders": ... }` avec des **types identiques** dans `app_fr.arb` ET
`app_en.arb`. Sinon `flutter gen-l10n` sort en échec (exit 1) avec un message qui ressemble à un
simple avertissement, laisse `app_localizations.dart` sans aucun getter, et le build produit des
milliers de « getter isn't defined for the type 'AppLocalizations' ». 27 blocs manquaient côté FR.

**Why:** les deux symptômes pointent loin de leur cause — le premier accuse un plugin tiers, le
second fait croire à du code applicatif cassé alors que seul le codegen a échoué.

**How to apply:** devant un mur d'erreurs `AppLocalizations`, lancer `flutter gen-l10n` seul et
vérifier son code de sortie avant de toucher au code. Voir aussi [[project_supabase_schema_drift]].
