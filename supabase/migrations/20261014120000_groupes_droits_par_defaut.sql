-- Groupes : les droits par défaut de Supabase retirés là où ils ne servent à
-- rien, et la création d'un groupe officiel fermée aux anonymes.
--
-- 1. TRUNCATE, REFERENCES, TRIGGER
-- `ALTER DEFAULT PRIVILEGES … GRANT ALL ON TABLES TO anon, authenticated` :
-- toute table naît avec les sept verbes. 20261005120000 les a retirés à la
-- messagerie, et à `group_members` / `group_pinned_items` ; restaient
-- `groups`, `group_requests`, `group_invites` et `departs_groupe_officiel`.
-- TRUNCATE ignore le RLS — aucune policy ne le retient. PostgREST ne
-- l'expose pas aujourd'hui ; ce serait une porte au premier `security
-- invoker` qui tronque. REFERENCES et TRIGGER ne servent à aucun client.
-- SELECT / INSERT / UPDATE / DELETE restent, gardés par le RLS.
--
-- 2. get_or_create_official_group
-- SECURITY DEFINER, sans vérification de l'appelant, jamais révoquée pour
-- `anon` : un appel anonyme créait le groupe officiel de n'importe quel pays
-- du référentiel — et chaque création prend un verrou ACCESS EXCLUSIVE sur
-- `groups` (`ALTER TABLE … DISABLE TRIGGER`). L'application l'appelle en
-- session (`ensureOfficialGroup`, après `ensureAuthenticated`) : seul
-- `authenticated` la garde. Le corps ne change pas — sa conversion sans DDL
-- reste à faire à part (voir 20260914140000).
--
-- Banc : tools/rls_tests/groupes_droits_par_defaut.sql

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['groups', 'group_requests', 'group_invites', 'departs_groupe_officiel']
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.%I FROM anon, authenticated', t);
    END IF;
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.get_or_create_official_group(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_or_create_official_group(text, text) TO authenticated;
