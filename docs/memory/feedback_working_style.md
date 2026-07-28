---
name: feedback_working_style
description: "Comment Salim veut qu'on travaille — commit+push par étape, honnêteté sur le bloqué/non-testable, hygiène git (ne pas écraser son WIP)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 583381e0-f82b-4106-8cae-5ae186d21804
  modified: 2026-07-28T17:37:20.122Z
---

Façon de travailler validée avec Salim (session de refonte 2026-07-28, 23 commits) :

- **Un commit par étape, puis push**, au fil de l'eau — pas de gros commit fourre-tout. Messages en français style Conventional Commits (`feat()`/`style()`/`chore()`/`fix()` + scope), corps décrivant le quoi/pourquoi et ce qui reste non fait.
- **Être franc sur ce qui est bloqué ou non testable** plutôt que de forcer un changement marginal ou fragile. Quand une feature dépend de données/modèles absents (ville de post, activité groupe, stories, horaires ambassade parsables) ou d'un écran non testable sans device, le dire et livrer la version honnête (ex. filtre PAYS au lieu de VILLE, pas de « ouvert maintenant » sans format d'horaires garanti). Salim préfère ça au cochage de cases.
- **Avant d'ajouter un champ au modèle**, vérifier où vit vraiment la donnée (ex. `lastMessageAt` était sur la conversation liée, pas sur `GroupEntity` → dérivé d'un provider existant, pas de champ mort).

**Why:** Salim itère vite en déléguant large (« continue », « fais X ensuite ») ; il compte sur des commits atomiques traçables et sur un jugement honnête des limites, pas sur de l'optimisme.

**How to apply:**
- Ne JAMAIS écraser son WIP non commité. `message_input.dart` (composer flottant qui retire la pilule « MAINTENIR ») est son chantier — le laisser tel quel. Pour éditer un fichier qui a du WIP, **stash chirurgical d'un seul fichier** (`git stash push <fichier>`), éditer, committer, puis `git stash pop`.
- Quand des fichiers modifiés non-tiens apparaissent dans l'arbre, les **classer avant de committer** : `git diff -w` sépare le simple `dart format` de la vraie logique ; committer les features cohérentes ensemble et le reformatage en `chore()` à part.
- Verrou l10n : après ajout de clés, `flutter gen-l10n` (parité `app_fr.arb`/`app_en.arb`), cf [[project_build_gotchas]]. Écritures Supabase : garde-fou `ensureAuthenticated()`, cf [[project_supabase_write_auth_guard]].
