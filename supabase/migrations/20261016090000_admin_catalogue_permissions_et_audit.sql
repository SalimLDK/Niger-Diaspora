-- Back-office, étape 1 du référentiel d'administration (docs/ADMIN_GUIDE_DEVELOPPEUR.md) :
-- un catalogue de permissions EN BASE, `admin_has_permission()` pour que le
-- serveur arbitre, et un journal d'audit qui ne se réécrit pas.
--
-- ═══ POURQUOI ═══════════════════════════════════════════════════════════════
--
-- 1. Les permissions n'existent que dans le client (`rolePermissions`,
--    lib/features/admin/domain/constants/role_permissions.dart). Le serveur
--    ne sait distinguer que `is_admin()` et `is_super_admin()` : un contentMod
--    et un financeMod ont, côté RLS, les mêmes droits. Le catalogue ci-dessous
--    reprend le mapping du client TEL QUEL (mêmes permissions pour chaque rôle,
--    nommées `domaine.ressource.action`) : cette migration ne retire ni
--    n'accorde rien à personne, elle rend le mapping lisible par les policies
--    et les RPC à venir. Le champ `legacy_key` garde le nom de l'enum Dart.
-- 2. `admin_audit_logs` (créée en 20261014050000) laisse l'admin la réécrire :
--    rien n'empêche, pour `postgres` ou `service_role`, un UPDATE/DELETE/
--    TRUNCATE, et le client n'en a pas le droit seulement par défaut de GRANT.
--    Un déclencheur le refuse à TOUS les rôles. Trois colonnes s'ajoutent
--    (result, reason_code, correlation_id) ; les écritures existantes
--    (client, functions/supabase.js) restent valides — les défauts les couvrent.
--
-- ═══ CE QUE CETTE MIGRATION NE FAIT PAS ═════════════════════════════════════
--
-- • Elle ne retire pas l'INSERT client sur `admin_audit_logs` : `AdminNotifier`
--   y écrit encore (admin_provider.dart:3522). Le retirer avant de basculer le
--   client sur `write_admin_audit()` rendrait l'audit muet (le `catch` avale
--   l'erreur). Étape suivante : basculer, puis REVOKE INSERT.
-- • Elle ne branche aucune policy existante sur `admin_has_permission()`.
-- • Un refus d'autorisation LEVÉ (42501) annule la transaction, donc l'audit
--   écrit dans la même transaction. Journaliser un refus se fait depuis
--   l'appelant (Edge Function, clé de service) ou par une seconde requête —
--   `admin_require_permission()` ne journalise donc pas.
--
-- Banc : tools/rls_tests/admin_catalogue_permissions_et_audit.sql
-- (`-- @@CIBLE@@` ← ce fichier via tools/rls_tests/repeter_cible.py).
-- Pas de BEGIN ici : repeter_cible.py le refuse, et `db push` n'en pose pas.

SET lock_timeout = '5s';

-- ── 1. Le catalogue ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_permissions (
  key         text PRIMARY KEY
              CHECK (key ~ '^[a-z]+(\.[a-z_]+){1,3}$'),
  module      text NOT NULL,
  description text NOT NULL,
  legacy_key  text UNIQUE
);

CREATE TABLE IF NOT EXISTS public.admin_role_permissions (
  role       text NOT NULL
             CHECK (role IN ('contentMod', 'businessMod', 'financeMod')),
  permission text NOT NULL REFERENCES public.admin_permissions (key) ON DELETE CASCADE,
  PRIMARY KEY (role, permission)
);
-- `superAdmin` n'a pas de ligne : il a tout le catalogue (voir la fonction).
-- Une permission ajoutée plus tard lui est donc acquise dès son insertion —
-- c'est voulu, et c'est la raison de la CHECK ci-dessus : aucun rôle ne peut
-- porter 'superAdmin' ici par erreur.

INSERT INTO public.admin_permissions (key, module, description, legacy_key) VALUES
  ('dashboard.view',                 'dashboard',      'Voir le tableau de bord',                    'viewDashboard'),
  ('dashboard.analytics.view',       'dashboard',      'Voir les statistiques',                      'viewAnalytics'),
  ('community.members.view',         'community',      'Voir les membres',                           'viewUsers'),
  ('community.members.verify',       'community',      'Vérifier / révoquer le badge d''un profil',  'verifyProfiles'),
  ('community.accounts.ban',         'community',      'Bannir / débannir un compte',                'banUsers'),
  ('community.content.view',         'community',      'Voir les contenus',                          'viewContent'),
  ('community.groups.manage',        'community',      'Modérer les groupes',                        'moderateGroups'),
  ('events.moderate',                'events',         'Modérer les événements',                     'moderateEvents'),
  ('moderation.reports.view',        'moderation',     'Voir les signalements',                      'viewReports'),
  ('moderation.reports.review',      'moderation',     'Traiter / résoudre les signalements',        'resolveReports'),
  ('directory.listings.view',        'directory',      'Voir les entreprises',                       'viewBusinesses'),
  ('directory.listings.approve',     'directory',      'Vérifier une entreprise',                    'verifyBusinesses'),
  ('directory.listings.boost',       'directory',      'Mettre une entreprise en avant',             'boostBusinesses'),
  ('directory.listings.delete',      'directory',      'Supprimer une entreprise',                   'deleteBusinesses'),
  ('marketplace.view',               'marketplace',    'Voir la marketplace',                        'viewMarketplace'),
  ('marketplace.products.moderate',  'marketplace',    'Modérer les produits',                       'moderateProducts'),
  ('marketplace.orders.view',        'marketplace',    'Voir les commandes',                         'viewOrders'),
  ('marketplace.disputes.resolve',   'marketplace',    'Résoudre les litiges',                       'resolveDisputes'),
  ('finance.transactions.view',      'finance',        'Voir les transactions',                      'viewTransactions'),
  ('finance.transactions.refund',    'finance',        'Rembourser une transaction',                 'refundTransactions'),
  ('finance.transactions.complete',  'finance',        'Compléter une transaction',                  'completeTransactions'),
  ('communications.send',            'communications', 'Envoyer des notifications',                  'sendNotifications'),
  ('settings.general.view',          'settings',       'Voir les paramètres',                        'viewSettings'),
  ('settings.general.edit',          'settings',       'Modifier les paramètres',                    'updateSettings'),
  ('settings.flags.view',            'settings',       'Voir les options fonctionnelles',            'viewFeatureFlags'),
  ('settings.flags.manage',          'settings',       'Activer / couper une option fonctionnelle',  'toggleFeatureFlags'),
  ('security.audit.view',            'security',       'Lire le journal d''audit',                   'viewAuditLogs'),
  ('security.admins.promote',        'security',       'Promouvoir un compte en administrateur',     'promoteAdmins'),
  ('security.roles.manage',          'security',       'Gérer les rôles',                            'manageRoles')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.admin_role_permissions (role, permission)
SELECT r.role, p.key
  FROM (VALUES
    -- contentMod
    ('contentMod', 'viewDashboard'), ('contentMod', 'viewUsers'),
    ('contentMod', 'banUsers'), ('contentMod', 'verifyProfiles'),
    ('contentMod', 'viewContent'), ('contentMod', 'moderateEvents'),
    ('contentMod', 'moderateGroups'), ('contentMod', 'viewReports'),
    ('contentMod', 'resolveReports'), ('contentMod', 'viewAuditLogs'),
    -- businessMod
    ('businessMod', 'viewDashboard'), ('businessMod', 'viewBusinesses'),
    ('businessMod', 'verifyBusinesses'), ('businessMod', 'boostBusinesses'),
    ('businessMod', 'deleteBusinesses'), ('businessMod', 'viewMarketplace'),
    ('businessMod', 'moderateProducts'), ('businessMod', 'viewOrders'),
    ('businessMod', 'viewAuditLogs'),
    -- financeMod
    ('financeMod', 'viewDashboard'), ('financeMod', 'viewTransactions'),
    ('financeMod', 'refundTransactions'), ('financeMod', 'completeTransactions'),
    ('financeMod', 'viewMarketplace'), ('financeMod', 'viewOrders'),
    ('financeMod', 'resolveDisputes'), ('financeMod', 'viewAnalytics'),
    ('financeMod', 'viewAuditLogs')
  ) AS r(role, legacy)
  JOIN public.admin_permissions p ON p.legacy_key = r.legacy
ON CONFLICT DO NOTHING;

ALTER TABLE public.admin_permissions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_role_permissions ENABLE ROW LEVEL SECURITY;

-- Lecture pour un admin (l'écran Rôles affiche le catalogue) ; écriture par
-- migration seulement. `REVOKE` d'abord : le GRANT par défaut de Supabase
-- donne tout à anon et authenticated (CLAUDE.md).
REVOKE ALL ON public.admin_permissions      FROM anon, authenticated;
REVOKE ALL ON public.admin_role_permissions FROM anon, authenticated;
GRANT SELECT ON public.admin_permissions      TO authenticated;
GRANT SELECT ON public.admin_role_permissions TO authenticated;

DROP POLICY IF EXISTS admin_permissions_select_admin ON public.admin_permissions;
CREATE POLICY admin_permissions_select_admin ON public.admin_permissions
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_role_permissions_select_admin ON public.admin_role_permissions;
CREATE POLICY admin_role_permissions_select_admin ON public.admin_role_permissions
  FOR SELECT TO authenticated USING (public.is_admin());

-- ── 2. admin_has_permission ─────────────────────────────────────────────────
-- Vrai si l'appelant est admin ET que son rôle porte `perm`. Faux dans tous
-- les autres cas : refus par défaut — permission inconnue, rôle absent ou
-- inconnu, `is_admin` faux (rôle laissé sur la ligne d'un ex-admin), pas de
-- session. superAdmin : tout le catalogue, mais une clé hors catalogue reste
-- refusée (une faute de frappe ne devient pas un passe-droit).
--
-- SECURITY DEFINER pour lire `users` et le catalogue sans dépendre des droits
-- de l'appelant ; search_path figé. STABLE : la décision ne change pas au
-- sein d'une requête.
CREATE OR REPLACE FUNCTION public.admin_has_permission(perm text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE((
    SELECT CASE
             WHEN u.admin_role = 'superAdmin' THEN
               EXISTS (SELECT 1 FROM public.admin_permissions p WHERE p.key = perm)
             ELSE
               EXISTS (SELECT 1 FROM public.admin_role_permissions rp
                        WHERE rp.role = u.admin_role AND rp.permission = perm)
           END
      FROM public.users u
     WHERE u.id = (SELECT public.firebase_uid())
       AND u.is_admin
       AND u.admin_role IS NOT NULL
  ), false)
$$;

-- Variante qui LÈVE : pour les RPC, où un `false` silencieux se lit « aucun
-- résultat ». 42501, comme les autres refus du back-office.
CREATE OR REPLACE FUNCTION public.admin_require_permission(perm text)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.admin_has_permission(perm) THEN
    RAISE EXCEPTION 'permission requise : %', perm USING ERRCODE = '42501';
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.admin_has_permission(text)     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_require_permission(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_has_permission(text)     TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_require_permission(text) TO authenticated, service_role;

-- ── 3. Le journal : colonnes ────────────────────────────────────────────────
-- Défauts qui couvrent les écrivains actuels : une ligne sans ces colonnes
-- est un succès, sans motif, sans corrélation.
ALTER TABLE public.admin_audit_logs
  ADD COLUMN IF NOT EXISTS result         text NOT NULL DEFAULT 'success',
  ADD COLUMN IF NOT EXISTS reason_code    text,
  ADD COLUMN IF NOT EXISTS correlation_id text;

ALTER TABLE public.admin_audit_logs
  DROP CONSTRAINT IF EXISTS admin_audit_logs_result_check;
ALTER TABLE public.admin_audit_logs
  ADD CONSTRAINT admin_audit_logs_result_check
  CHECK (result IN ('success', 'denied', 'failed', 'partial'));

CREATE INDEX IF NOT EXISTS admin_audit_logs_target_idx
  ON public.admin_audit_logs (target_type, target_id, created_at DESC);
CREATE INDEX IF NOT EXISTS admin_audit_logs_correlation_idx
  ON public.admin_audit_logs (correlation_id) WHERE correlation_id IS NOT NULL;

-- ── 4. Le journal : append-only, pour TOUS les rôles ────────────────────────
-- Un REVOKE ne retient pas `postgres` ni `service_role` ; un déclencheur, si.
-- Le jour où une purge de rétention sera décidée, elle passera par une
-- migration qui le désarme explicitement et le dit.
CREATE OR REPLACE FUNCTION public.admin_audit_logs_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'admin_audit_logs est en ajout seul (% refusé)', TG_OP
    USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS admin_audit_logs_no_rewrite ON public.admin_audit_logs;
CREATE TRIGGER admin_audit_logs_no_rewrite
  BEFORE UPDATE OR DELETE ON public.admin_audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.admin_audit_logs_append_only();

DROP TRIGGER IF EXISTS admin_audit_logs_no_truncate ON public.admin_audit_logs;
CREATE TRIGGER admin_audit_logs_no_truncate
  BEFORE TRUNCATE ON public.admin_audit_logs
  FOR EACH STATEMENT EXECUTE FUNCTION public.admin_audit_logs_append_only();

-- Le journal se lit avec la permission `security.audit.view`, plus avec le seul
-- drapeau admin : contentMod, businessMod, financeMod et superAdmin la portent
-- (mapping du client, inchangé) ; un admin sans rôle — le « fantôme » de
-- l'audit du 14/10 — ne lit plus rien.
DROP POLICY IF EXISTS admin_audit_logs_select_admin ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_select_admin ON public.admin_audit_logs
  FOR SELECT TO authenticated
  USING (public.admin_has_permission('security.audit.view'));

-- ── 5. write_admin_audit : l'écriture par le serveur ────────────────────────
-- L'acteur vient de la session, jamais d'un paramètre. Exige un admin ; la
-- permission de l'ACTION journalisée est vérifiée par l'appelant (cette
-- fonction écrit, elle n'autorise pas). Les métadonnées refusent les clés qui
-- ressemblent à un secret : l'audit ne porte ni mot de passe ni jeton.
CREATE OR REPLACE FUNCTION public.write_admin_audit(
  p_action         text,
  p_resource_type  text,
  p_resource_id    text,
  p_result         text  DEFAULT 'success',
  p_reason_code    text  DEFAULT NULL,
  p_correlation_id text  DEFAULT NULL,
  p_metadata       jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor text := (SELECT public.firebase_uid());
  v_name  text;
  v_id    uuid;
BEGIN
  IF v_actor IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'write_admin_audit : réservé aux administrateurs'
      USING ERRCODE = '42501';
  END IF;

  IF p_action IS NULL OR p_action !~ '^[A-Z][A-Z0-9_]{2,63}$' THEN
    RAISE EXCEPTION 'write_admin_audit : action invalide (MAJUSCULES_ET_TIRETS_BAS)'
      USING ERRCODE = '22023';
  END IF;
  IF p_result NOT IN ('success', 'denied', 'failed', 'partial') THEN
    RAISE EXCEPTION 'write_admin_audit : result invalide' USING ERRCODE = '22023';
  END IF;

  p_metadata := COALESCE(p_metadata, '{}'::jsonb);
  IF jsonb_typeof(p_metadata) <> 'object' OR length(p_metadata::text) > 4096 THEN
    RAISE EXCEPTION 'write_admin_audit : metadata doit être un objet de 4 Ko au plus'
      USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_metadata) k
              WHERE lower(k) ~ '(pass|token|secret|api_?key|private_?key|authorization)') THEN
    RAISE EXCEPTION 'write_admin_audit : metadata ne doit porter aucun secret'
      USING ERRCODE = '22023';
  END IF;

  SELECT display_name INTO v_name FROM public.users WHERE id = v_actor;

  INSERT INTO public.admin_audit_logs
    (admin_id, admin_name, action, target_type, target_id, details,
     result, reason_code, correlation_id)
  VALUES
    (v_actor, v_name, p_action, p_resource_type, p_resource_id, p_metadata,
     p_result, p_reason_code, p_correlation_id)
  RETURNING id INTO v_id;

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.write_admin_audit(text, text, text, text, text, text, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.write_admin_audit(text, text, text, text, text, text, jsonb)
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
