-- Ferme, POUR LES QUATRE RÔLES LIMITÉS SEULEMENT, ce que `is_admin()` leur ouvrirait par héritage.
-- NON APPLIQUÉE — à répéter par tools/rls_tests/roles_limites_heritage.sql, puis à relire avec Salim.
-- À appliquer APRÈS 20261029090000 (qui crée les rôles), et AVANT d'en attribuer un.
--
-- CE QUE LA MESURE A MONTRÉ (relevé en production le 2026-10-29, catalogue seul) :
--   écritures ouvertes à tout administrateur, sans permission nommée
--     demarches_rubriques / demarches_catalogue_meta  ALL     (contournent relecture et publication)
--     groups_update_admin                             UPDATE  (groupes officiels)
--     business_reviews_retrait                        DELETE  (avis d'entreprises)
--     reports_update_admin                            UPDATE  (réduit à une colonne par 20261023090000)
--   lectures ouvertes à tout administrateur
--     users_select            (profils privés)    reports_select_own     (identité des déclarants)
--     activity_logs_select_own_or_admin           error_logs_admin_read  admin_notifications_select_admin
--   fonctions SECURITY DEFINER qui ne testent que is_admin()
--     profils_admin, profils_admin_page (lignes complètes de `users`),
--     conversations_guard_admin_fields, guard_group_official
--
-- LE CHOIX : un rôle limité n'entre pas dans ces chemins, les quatre rôles historiques y entrent comme avant.
-- Chaque `is_admin()` de ces objets devient `(is_admin() AND NOT is_limited_admin())`. Aucun droit des rôles
-- historiques ne change ; aucune décision de produit n'est tranchée ici (voir la fiche, § Décisions).
--
-- CE QUE CETTE MIGRATION NE FAIT PAS :
--   • `is_admin()` reste inchangée : une soixantaine de RPC l'appellent avant `admin_require_permission`.
--   • `write_admin_audit` reste exécutable : le panneau Flutter l'appelle directement
--     (admin_provider.dart:3115). Tout administrateur, limité ou non, peut donc y écrire une ligne.
--   • les tables de configuration lisibles par tout admin (admin_permissions, *_transitions) : lecture
--     sans donnée personnelle, et la console en a besoin.
--   • `users_update_own` : sa condition `is_admin = is_admin()` empêche l'auto-promotion, elle n'ouvre rien.
--
-- MÉTHODE : le texte de chaque policy et de chaque fonction est RELU dans la base puis réécrit, pas retapé
-- ici. Une définition qui aurait dérivé du dépôt est donc réécrite telle qu'elle est en production. Chaque
-- remplacement est vérifié (le texte doit avoir changé) ; sinon la migration échoue au lieu de passer en silence.

SET lock_timeout = '5s';

-- ── 1. Le prédicat ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_limited_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    (SELECT u.is_admin AND u.admin_role IN ('supportAgent', 'validator', 'auditor', 'analyst')
       FROM public.users u
      WHERE u.id = (SELECT public.firebase_uid())),
    false)
$$;

-- anon aussi : une policy qui appelle une fonction non exécutable fait échouer la lecture (cf. is_admin()).
REVOKE ALL ON FUNCTION public.is_limited_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_limited_admin() TO anon, authenticated, service_role;

-- ── 2. Les policies ────────────────────────────────────────────────────────
DO $$
DECLARE
  cible record;
  p     record;
  q     text;
  w     text;
  cmd   text;
  n_ok  int := 0;
  motif constant text := '(public\.)?\mis_admin\(\)';
  rempl constant text := '(public.is_admin() AND NOT public.is_limited_admin())';
BEGIN
  FOR cible IN
    SELECT * FROM (VALUES
      ('public', 'demarches_rubriques',      'demarches_rubriques_write'),
      ('public', 'demarches_catalogue_meta', 'demarches_catalogue_meta_write'),
      ('public', 'groups',                   'groups_update_admin'),
      ('public', 'business_reviews',         'business_reviews_retrait'),
      ('public', 'reports',                  'reports_update_admin'),
      ('public', 'reports',                  'reports_select_own'),
      ('public', 'users',                    'users_select'),
      ('public', 'activity_logs',            'activity_logs_select_own_or_admin'),
      ('public', 'error_logs',               'error_logs_admin_read'),
      ('public', 'admin_notifications',      'admin_notifications_select_admin')
    ) AS t(schema_, table_, policy_)
  LOOP
    SELECT * INTO p FROM pg_policies
     WHERE schemaname = cible.schema_ AND tablename = cible.table_ AND policyname = cible.policy_;
    IF NOT FOUND THEN
      RAISE NOTICE 'policy absente (déjà fermée ou renommée) : %.%', cible.table_, cible.policy_;
      CONTINUE;
    END IF;
    IF coalesce(p.qual, '') || coalesce(p.with_check, '') LIKE '%is_limited_admin%' THEN
      RAISE NOTICE 'déjà réécrite : %.%', cible.table_, cible.policy_;
      CONTINUE;
    END IF;

    q := regexp_replace(p.qual,       motif, rempl, 'g');
    w := regexp_replace(p.with_check, motif, rempl, 'g');
    IF q IS NOT DISTINCT FROM p.qual AND w IS NOT DISTINCT FROM p.with_check THEN
      RAISE EXCEPTION 'policy %.% : aucun is_admin() à réécrire (définition inattendue : %)',
        cible.table_, cible.policy_, coalesce(p.qual, p.with_check);
    END IF;

    cmd := format('ALTER POLICY %I ON %I.%I', cible.policy_, cible.schema_, cible.table_);
    IF q IS NOT NULL THEN cmd := cmd || format(' USING (%s)', q); END IF;
    IF w IS NOT NULL THEN cmd := cmd || format(' WITH CHECK (%s)', w); END IF;
    EXECUTE cmd;
    n_ok := n_ok + 1;
  END LOOP;
  RAISE NOTICE 'policies réécrites : %', n_ok;
END $$;

-- ── 3. Les fonctions ───────────────────────────────────────────────────────
-- CREATE OR REPLACE conserve propriétaire et droits d'exécution : on ne réécrit que le corps.
DO $$
DECLARE
  f     record;
  def   text;
  neuf  text;
  n_ok  int := 0;
  motif constant text := '(public\.)?\mis_admin\(\)';
  rempl constant text := '(public.is_admin() AND NOT public.is_limited_admin())';
BEGIN
  FOR f IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
     WHERE p.proname IN ('profils_admin', 'profils_admin_page',
                         'conversations_guard_admin_fields', 'guard_group_official')
  LOOP
    def := pg_get_functiondef(f.oid);
    IF def LIKE '%is_limited_admin%' THEN CONTINUE; END IF;
    neuf := regexp_replace(def, motif, rempl, 'g');
    IF neuf = def THEN
      RAISE EXCEPTION 'fonction % : aucun is_admin() à réécrire', f.proname;
    END IF;
    EXECUTE neuf;
    n_ok := n_ok + 1;
  END LOOP;
  RAISE NOTICE 'fonctions réécrites : %', n_ok;
END $$;

NOTIFY pgrst, 'reload schema';
