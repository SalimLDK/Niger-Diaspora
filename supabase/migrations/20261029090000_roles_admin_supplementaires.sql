-- Quatre rôles d'administration de plus : supportAgent, validator, auditor,
-- analyst. NON APPLIQUÉE — à répéter par le banc
-- tools/rls_tests/roles_admin_supplementaires.sql, puis à relire avec Salim.
--
-- ⚠️ AVANT DE L'APPLIQUER, MESURER UN RISQUE QUE LE DÉPÔT NE PEUT PAS DIRE.
--
-- Un rôle d'administration pose `users.is_admin = true`. Or `is_admin()` ne
-- regarde QUE ce drapeau : toute policy ou fonction écrite `… OR is_admin()`
-- sans `admin_has_permission(…)` ouvre ses droits à un auditor ou à un analyst
-- comme à un superAdmin. Le dépôt en compte 186 occurrences, et une partie est
-- déjà fermée (migrations d'octobre) ; ce qui reste vivant, seule la base le
-- sait. À lancer en lecture seule, AVANT d'attribuer le moindre rôle :
--
--   SELECT schemaname||'.'||tablename AS objet, cmd, policyname
--     FROM pg_policies
--    WHERE (coalesce(qual,'')||coalesce(with_check,'')) ~ 'is_admin\(\)'
--      AND (coalesce(qual,'')||coalesce(with_check,'')) !~ 'admin_has_permission'
--    ORDER BY 1, 2, 3;
--
-- Chaque ligne est un droit que les nouveaux rôles recevront. Ceux de lecture
-- seule (auditor, analyst) ne tiennent leur promesse que si aucune ligne de
-- ECRITURE (INSERT / UPDATE / DELETE / ALL) ne reste. La même vérification vaut
-- pour les fonctions SECURITY DEFINER qui testent `is_admin()` seul.
--
-- Ce que cette migration ne fait PAS, et pourquoi :
--   • elle ne touche pas `is_admin()` : une soixantaine de RPC l'appellent
--     avant `admin_require_permission`, la durcir couperait aussi les nouveaux
--     rôles de leurs propres fonctions ;
--   • elle n'accorde AUCUN droit d'écriture direct : chaque permission ci-dessous
--     est celle d'une fonction serveur qui revérifie état, motif et audit ;
--   • elle n'attribue le rôle à personne.

SET lock_timeout = '5s';

-- ── 1. Les contraintes qui énuméraient quatre rôles ─────────────────────────
-- Les noms générés par Postgres ne sont pas garantis : on retrouve les CHECK
-- par leur contenu, on ne présume pas leur nom.
DO $$
DECLARE c record;
BEGIN
  FOR c IN
    SELECT con.conrelid::regclass AS tbl, con.conname
      FROM pg_constraint con
     WHERE con.contype = 'c'
       AND con.conrelid IN ('public.users'::regclass, 'public.admin_role_permissions'::regclass)
       AND pg_get_constraintdef(con.oid) LIKE '%contentMod%'
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', c.tbl, c.conname);
  END LOOP;
END $$;

ALTER TABLE public.users
  ADD CONSTRAINT users_admin_role_check
  CHECK (admin_role IS NULL OR admin_role IN (
    'superAdmin', 'contentMod', 'businessMod', 'financeMod',
    'supportAgent', 'validator', 'auditor', 'analyst'));

-- Le superAdmin n'a pas de lignes ici : admin_has_permission lui donne tout le
-- catalogue. Les autres rôles sont énumérés.
ALTER TABLE public.admin_role_permissions
  ADD CONSTRAINT admin_role_permissions_role_check
  CHECK (role IN ('contentMod', 'businessMod', 'financeMod',
                  'supportAgent', 'validator', 'auditor', 'analyst'));

-- ── 2. Les droits de chaque rôle ────────────────────────────────────────────
-- Par clé du catalogue : une clé absente du catalogue ne lève rien ici (le
-- banc compte les lignes posées pour que l'oubli se voie).
INSERT INTO public.admin_role_permissions (role, permission)
SELECT r.role, p.key
  FROM (VALUES
    -- Agent de support : tickets, rien d'autre ; pas de lecture des membres.
    ('supportAgent', 'dashboard.view'),
    ('supportAgent', 'support.tickets.view'),
    ('supportAgent', 'support.tickets.reply'),
    ('supportAgent', 'support.tickets.assign'),
    ('supportAgent', 'support.tickets.escalate'),
    ('supportAgent', 'support.tickets.close'),
    -- Validateur : relit et approuve, ne publie pas (séparation auteur / validation).
    ('validator', 'dashboard.view'),
    ('validator', 'consular.view'),
    ('validator', 'consular.procedures.approve'),
    ('validator', 'consular.procedures.edit'),
    ('validator', 'consular.embassies.verify'),
    ('validator', 'directory.listings.view'),
    ('validator', 'directory.listings.approve'),
    ('validator', 'events.approve'),
    -- Auditeur : journal et rapport, en lecture seule.
    ('auditor', 'dashboard.view'),
    ('auditor', 'security.audit.view'),
    ('auditor', 'security.audit.export'),
    -- Analyste : statistiques agrégées seulement.
    ('analyst', 'dashboard.view'),
    ('analyst', 'dashboard.analytics.view'),
    ('analyst', 'events.analytics.view')
  ) AS r(role, perm)
  JOIN public.admin_permissions p ON p.key = r.perm
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';
