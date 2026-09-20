-- `users` n'est plus lisible sans compte.
--
-- CE QUI ÉTAIT OUVERT (mesuré en production le 2026-09-20, en simulant `anon`
-- dans une transaction en lecture seule) : 123 lignes visibles, dont 85 e-mails,
-- 55 numéros de téléphone et 61 positions GPS. La clé publique que porte chaque
-- APK suffisait — aucun compte, aucune session.
--
-- Deux causes, qui se cumulaient :
--   1. `users_select` valait pour le rôle `public`, donc pour `anon`, avec la
--      condition `NOT is_private` — et `is_private` vaut FALSE par défaut ;
--   2. `anon` gardait TOUS les droits de table sur `users` (le défaut Supabase
--      `ALTER DEFAULT PRIVILEGES … GRANT ALL`), SELECT compris. Aucune
--      migration ne les lui avait jamais retirés.
--
-- Personne n'en a besoin. L'app n'a aucun mode invité (le routeur renvoie à
-- `/auth/login` tant que Firebase n'est pas authentifié), aucune page du site
-- ne lit `users`, et les Edge Functions passent par la clé de service. Les
-- lectures de profil côté app attendent déjà la session
-- (`ensureReadableSession`) plutôt que d'interroger en anon, et celles qui ne
-- l'attendent pas ont un repli (`_getUserDataFromSupabase` retombe sur les
-- données Firebase Auth, `isHandleAvailable` laisse trancher la contrainte
-- UNIQUE).
--
-- Vérifié en base avant d'écrire : aucune vue et aucune fonction SECURITY
-- INVOKER appelable par `anon` ne lit `users` ; une seule policy étrangère le
-- fait (`content_reports` « Admins can manage all reports »), sur une table
-- qu'un anonyme n'a aucune raison d'interroger.
--
-- CE QUE CETTE MIGRATION NE FERME PAS : un compte connecté lit toujours les
-- mêmes colonnes chez tous les profils non privés — e-mail, téléphone,
-- position, mais aussi `fcm_tokens`, `voip_token`, `session_id`, `cart_data`,
-- `ban_reason`. Et créer un compte est gratuit. Un `GRANT SELECT (colonnes)`
-- le fermerait, mais l'app fait dix `select()` sans liste et un `.stream()`
-- sur `users` : sous droits par colonnes, PostgREST refuse la requête ENTIÈRE
-- (42501), et tous les builds déjà installés perdraient le profil, la carte
-- et la recherche. Ce second pas exige donc une version cliente d'abord.
--
-- Banc : tools/rls_tests/users_ferme_a_anon.sql

SET LOCAL lock_timeout = '5s';

-- ── 1. `anon` : plus aucun droit de table ───────────────────────────────────
REVOKE ALL ON public.users FROM anon;

-- ── 2. Les policies ne valent plus que pour un compte connecté ──────────────
-- Ceinture et bretelles : sans droit de table, `anon` n'atteint plus les
-- policies. Mais un `GRANT` rétabli par mégarde (ou par un défaut Supabase
-- rejoué) rouvrirait tout si elles restaient au rôle `public`.
ALTER POLICY users_select       ON public.users TO authenticated;
ALTER POLICY users_insert_own   ON public.users TO authenticated;
ALTER POLICY users_update_own   ON public.users TO authenticated;
ALTER POLICY users_update_admin ON public.users TO authenticated;

-- ── 3. `authenticated` : les verbes qu'aucune policy ne retient ─────────────
-- TRUNCATE ignore le RLS. PostgREST ne l'expose pas aujourd'hui ; il le
-- deviendrait au premier `SECURITY INVOKER` qui tronque. REFERENCES et TRIGGER
-- n'ont aucun usage applicatif.
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.users FROM authenticated;
