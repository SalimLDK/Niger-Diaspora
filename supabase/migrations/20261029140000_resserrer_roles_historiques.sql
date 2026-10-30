-- Resserre les QUATRE RÔLES HISTORIQUES : un droit nommé remplace le simple drapeau `is_admin()`.
-- NON APPLIQUÉE — décision de Salim (message du 2026-10-29) ; à répéter par
-- tools/rls_tests/roles_durcissement_complet.sql avant toute application.
-- À appliquer APRÈS 20261029100000 (qui introduit `is_limited_admin()`).
--
-- CE QUI CHANGE POUR LES RÔLES EN PLACE (le catalogue de droits fait foi) :
--   droit exigé                    objets                                              qui le porte aujourd'hui
--   moderation.reports.view        reports (SELECT)                                    contentMod
--   moderation.reports.review      reports (UPDATE de la colonne notifiée)             contentMod
--   community.members.view         users (SELECT des profils privés), profils_admin*   contentMod
--   community.groups.manage        groups (UPDATE officiels), gardes de groupes        contentMod
--   directory.listings.delete      business_reviews (DELETE par un admin)              businessMod
--   consular.procedures.edit       demarches_rubriques, demarches_catalogue_meta       (superAdmin seul, sauf mapping plus récent)
--   security.audit.view            activity_logs, error_logs (SELECT)                  les quatre
--   communications.view            admin_notifications (SELECT)                        selon le mapping
-- Conséquence nette : businessMod et financeMod ne lisent plus les signalements, les profils privés ni
-- `profils_admin` ; seul contentMod les lit. superAdmin garde tout le catalogue.
--
-- MÉTHODE : chaque définition est RELUE dans la base puis réécrite, jamais retapée. Dans le texte lu :
--   is_limited_admin()  →  false            (le garde-fou de 20261029100000 devient sans objet)
--   is_admin()          →  admin_has_permission('<droit>')
-- Une policy qui s'applique à `anon` ou `public` est LAISSÉE EN L'ÉTAT (`admin_has_permission` n'est pas
-- exécutable par anon et ferait échouer la lecture publique) et signalée par un NOTICE. Une définition
-- inattendue fait échouer la migration.

SET lock_timeout = '5s';

DO $$
DECLARE
  cible record;
  p     record;
  q     text;
  w     text;
  cmd   text;
  n_ok  int := 0;
  perm  text;
BEGIN
  FOR cible IN
    SELECT * FROM (VALUES
      ('reports',                  'reports_select_own',                'moderation.reports.view'),
      ('reports',                  'reports_update_admin',              'moderation.reports.review'),
      ('users',                    'users_select',                      'community.members.view'),
      ('groups',                   'groups_update_admin',               'community.groups.manage'),
      ('business_reviews',         'business_reviews_retrait',          'directory.listings.delete'),
      ('demarches_rubriques',      'demarches_rubriques_write',         'consular.procedures.edit'),
      ('demarches_catalogue_meta', 'demarches_catalogue_meta_write',    'consular.procedures.edit'),
      ('activity_logs',            'activity_logs_select_own_or_admin', 'security.audit.view'),
      ('error_logs',               'error_logs_admin_read',             'security.audit.view'),
      ('admin_notifications',      'admin_notifications_select_admin',  'communications.view')
    ) AS t(table_, policy_, perm_)
  LOOP
    perm := cible.perm_;
    SELECT * INTO p FROM pg_policies
     WHERE schemaname = 'public' AND tablename = cible.table_ AND policyname = cible.policy_;
    IF NOT FOUND THEN
      RAISE NOTICE 'policy absente : %.%', cible.table_, cible.policy_;
      CONTINUE;
    END IF;
    IF coalesce(p.qual, '') || coalesce(p.with_check, '') LIKE '%admin_has_permission%' THEN
      RAISE NOTICE 'déjà par permission : %.%', cible.table_, cible.policy_;
      CONTINUE;
    END IF;
    IF p.roles && ARRAY['public', 'anon']::name[] THEN
      RAISE NOTICE 'LAISSÉE EN L''ÉTAT (s''applique à anon/public) : %.%', cible.table_, cible.policy_;
      CONTINUE;
    END IF;

    q := regexp_replace(regexp_replace(p.qual, '(public\.)?\mis_limited_admin\(\)', 'false', 'g'),
                        '(public\.)?\mis_admin\(\)', format('public.admin_has_permission(%L)', perm), 'g');
    w := regexp_replace(regexp_replace(p.with_check, '(public\.)?\mis_limited_admin\(\)', 'false', 'g'),
                        '(public\.)?\mis_admin\(\)', format('public.admin_has_permission(%L)', perm), 'g');
    IF q IS NOT DISTINCT FROM p.qual AND w IS NOT DISTINCT FROM p.with_check THEN
      RAISE EXCEPTION 'policy %.% : aucun is_admin() à remplacer (définition inattendue : %)',
        cible.table_, cible.policy_, coalesce(p.qual, p.with_check);
    END IF;

    cmd := format('ALTER POLICY %I ON public.%I', cible.policy_, cible.table_);
    IF q IS NOT NULL THEN cmd := cmd || format(' USING (%s)', q); END IF;
    IF w IS NOT NULL THEN cmd := cmd || format(' WITH CHECK (%s)', w); END IF;
    EXECUTE cmd;
    n_ok := n_ok + 1;
  END LOOP;
  RAISE NOTICE 'policies resserrées : %', n_ok;
END $$;

DO $$
DECLARE
  f     record;
  def   text;
  neuf  text;
  perm  text;
  n_ok  int := 0;
BEGIN
  FOR f IN
    SELECT p.oid, p.proname,
           CASE p.proname
             WHEN 'profils_admin'                     THEN 'community.members.view'
             WHEN 'profils_admin_page'                THEN 'community.members.view'
             WHEN 'guard_group_official'              THEN 'community.groups.manage'
             WHEN 'conversations_guard_admin_fields'  THEN 'community.groups.manage'
           END AS perm
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
     WHERE p.proname IN ('profils_admin', 'profils_admin_page', 'guard_group_official', 'conversations_guard_admin_fields')
  LOOP
    def := pg_get_functiondef(f.oid);
    IF def LIKE '%admin_has_permission(''' || f.perm || '''%' THEN CONTINUE; END IF;
    neuf := regexp_replace(regexp_replace(def, '(public\.)?\mis_limited_admin\(\)', 'false', 'g'),
                           '(public\.)?\mis_admin\(\)', format('public.admin_has_permission(%L)', f.perm), 'g');
    IF neuf = def THEN
      RAISE EXCEPTION 'fonction % : aucun is_admin() à remplacer', f.proname;
    END IF;
    EXECUTE neuf;
    n_ok := n_ok + 1;
  END LOOP;
  RAISE NOTICE 'fonctions resserrées : %', n_ok;
END $$;

NOTIFY pgrst, 'reload schema';
