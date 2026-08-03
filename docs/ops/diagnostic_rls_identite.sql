-- =============================================================================
-- Diagnostic — les policies RLS savent-elles qui est l'utilisateur ?
--
-- À coller tel quel dans le SQL Editor Supabase. LECTURE SEULE : aucune de ces
-- requêtes n'écrit ni ne modifie quoi que ce soit.
--
-- Contexte : l'app s'authentifie via Firebase, puis échange le jeton contre une
-- session Supabase. L'échange crée DEUX identifiants distincts —
-- `supabaseUserId` (l'utilisateur Supabase Auth, exposé par le claim `sub`) et
-- le Firebase UID, écrit dans `public.users.id`.
--
-- Le dépôt contient deux fonctions d'identité :
--   current_user_id()  = auth.jwt() ->> 'sub'   -> l'ID Supabase Auth
--   firebase_uid()     = app_metadata / auth_mappings -> le Firebase UID
--
-- 48 policies du dépôt comparent encore `current_user_id()` à des colonnes qui
-- contiennent des Firebase UID. Si c'est aussi le cas dans la base déployée,
-- ces policies n'accordent jamais rien. Ce script le vérifie sur les faits.
-- =============================================================================


-- ─── A. LA QUESTION DÉCISIVE ────────────────────────────────────────────────
-- Les deux identités coïncident-elles ?
--
-- Si `identifiants_qui_coincident` vaut 0 alors que `lignes_users` est non nul,
-- les policies basées sur current_user_id() sont bel et bien inopérantes.
-- Si le compte est proche de `lignes_users`, alors `sub` porte déjà le Firebase
-- UID et il n'y a pas de problème d'identité.

SELECT
  (SELECT count(*) FROM public.users) AS lignes_users,
  (SELECT count(*) FROM auth.users)   AS comptes_auth,
  (SELECT count(*)
     FROM auth.users a
     JOIN public.users u ON u.id = a.id::text) AS identifiants_qui_coincident;


-- ─── B. firebase_uid() PEUT-ELLE RÉSOUDRE ? ─────────────────────────────────
-- À vérifier AVANT toute migration vers firebase_uid() : si les comptes n'ont
-- pas le claim dans app_metadata et que la table de secours est vide, basculer
-- les policies vers cette fonction casserait l'accès au lieu de le réparer.

SELECT
  (SELECT count(*) FROM auth.users)                                AS comptes_auth,
  (SELECT count(*) FROM auth.users
     WHERE raw_app_meta_data ? 'firebase_uid')                     AS avec_claim_app_metadata,
  (SELECT count(*) FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = 'auth_mappings') AS table_de_secours_existe;

-- Si la table de secours existe, combien de correspondances contient-elle :
-- (commenter cette requête si la ligne ci-dessus renvoie 0)
SELECT count(*) AS correspondances_auth_mappings FROM public.auth_mappings;


-- ─── C. ÉTAT RÉEL DES POLICIES DÉPLOYÉES ────────────────────────────────────
-- La liste qui compte : ce que la base applique vraiment, indépendamment du
-- contenu du dépôt.

SELECT
  tablename            AS "table",
  policyname           AS policy,
  cmd                  AS commande,
  CASE
    WHEN COALESCE(qual, '') || COALESCE(with_check, '') ILIKE '%firebase_uid%'
      THEN 'migrée'
    ELSE 'CASSÉE — current_user_id()'
  END                  AS etat
FROM pg_policies
WHERE schemaname = 'public'
  AND (COALESCE(qual, '') || COALESCE(with_check, '')) ILIKE '%current_user_id%'
ORDER BY etat DESC, tablename, policyname;


-- ─── D. RÉSUMÉ CHIFFRÉ ──────────────────────────────────────────────────────
-- À comparer avec l'analyse du dépôt : 48 policies cassées, 14 migrées.
-- Un écart signifie que la base a été rapiécée à la main.

SELECT
  count(*) FILTER (
    WHERE (COALESCE(qual, '') || COALESCE(with_check, '')) ILIKE '%current_user_id%'
      AND (COALESCE(qual, '') || COALESCE(with_check, '')) NOT ILIKE '%firebase_uid%'
  ) AS policies_cassees,
  count(*) FILTER (
    WHERE (COALESCE(qual, '') || COALESCE(with_check, '')) ILIKE '%firebase_uid%'
  ) AS policies_migrees,
  count(*) AS policies_totales
FROM pg_policies
WHERE schemaname = 'public';


-- ─── E. FOCUS PODCASTS ──────────────────────────────────────────────────────
-- Le périmètre qui a déclenché l'enquête. Les trois policies de gestion
-- (podcasts_manage_own, podcast_episodes_manage, podcast_subscriptions_own)
-- doivent apparaître comme « migrée » pour qu'un créateur puisse gérer son
-- podcast et qu'un auditeur puisse s'abonner.

SELECT tablename AS "table", policyname AS policy, cmd AS commande, qual AS condition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('podcasts', 'podcast_episodes',
                    'podcast_subscriptions', 'podcast_user_data')
ORDER BY tablename, policyname;
