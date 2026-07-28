---
name: project_supabase_schema_drift
description: Cause racine des erreurs PGRST205 (tables manquantes) sur le Supabase distant et remédiation appliquée le 2026-06-25
metadata:
  type: project
---

Plusieurs tables étaient référencées par l'app Flutter (`.from('...')`) mais absentes de la base Supabase distante → erreurs `PostgrestException PGRST205 "Could not find the table 'public.X' in the schema cache"`.

**Cause racine :** des tables (`post_bookmarks`, `blocked_users`) avaient été ajoutées au fichier `20260522223150_initial_schema.sql` *après* que cette migration ait déjà été marquée appliquée sur le distant → `supabase db push` ne les recrée jamais. Ne JAMAIS éditer une migration déjà appliquée pour corriger ça ; créer une nouvelle migration idempotente (`CREATE TABLE IF NOT EXISTS` + policy gardée par `pg_policies` + `NOTIFY pgrst, 'reload schema';`) puis `supabase db push`.

**Corrigé le 2026-06-25 (toutes appliquées au distant) :**
- `post_bookmarks`, `blocked_users` — recréées (migrations 20260625200000 / 200100).
- Feature Heritage (`heritage_recordings`, `heritage_collections`, `heritage_user_data` + RPC `increment_column`) — n'existait dans AUCUNE migration ; portée depuis Firestore, code Dart en `lib/features/audio_rooms/.../heritage_*`. Tables créées avec colonnes **camelCase entre guillemets** pour matcher le code Dart sans le modifier (migration 20260625200200).

**Méthode d'audit (réutilisable, sans psql/Docker) :** comparer `grep -roE "\.from\(['\"][a-z_]+['\"]" lib` (tables référencées) vs la liste exposée par PostgREST récupérée via `curl {SUPABASE_URL}/rest/v1/` avec le `SUPABASE_SERVICE_ROLE_KEY` (clés `definitions` du spec OpenAPI). Au 2026-06-25, diff = 0 table manquante.

**Dettes/caveats à traiter plus tard :**
- Colonnes camelCase de Heritage = incohérent avec le reste (snake_case) — dette de port Firestore.
- Compteurs d'engagement de `heritage_recordings` (`playCount`/`likeCount` via `_increment` en lecture-modif-écriture côté Dart) n'augmentent PAS pour les non-propriétaires sous RLS (update affecte 0 ligne, pas d'erreur). Pour les rendre cross-user, router `_increment` via le RPC `increment_column` (déjà allowlisté pour ces colonnes).

Voir [[project_audit_remediation.md]].
