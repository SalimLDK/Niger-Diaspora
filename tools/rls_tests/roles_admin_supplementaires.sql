-- Banc : quatre rôles d'administration supplémentaires (migration 20261029090000).
--
--   supabase db query --linked -f tools/rls_tests/roles_admin_supplementaires.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT `db push` : remplacer la ligne seule `-- @@CIBLE@@` par la migration
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>) —
-- c'est la répétition. APRÈS, lancé tel quel, le banc prouve l'état vivant.
--
-- CE QU'IL VÉRIFIE. Que chaque nouveau rôle a EXACTEMENT les droits annoncés et
-- aucun autre : l'auditeur et l'analyste ne peuvent rien modifier, l'agent de
-- support ne touche ni aux membres ni au journal, le validateur approuve sans
-- publier. Et que l'ancien périmètre n'a pas bougé.
--
-- CE QU'IL NE PROUVE PAS : que les policies héritées `… OR is_admin()` sont
-- fermées. Elles ne relèvent pas de cette migration ; la requête de mesure est
-- en tête de la migration, à lancer avant toute attribution de rôle.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-rol-super',    'Super',    'rol-super@banc.test',    true, 'superAdmin'),
  ('banc-rol-content',  'Content',  'rol-content@banc.test',  true, 'contentMod'),
  ('banc-rol-support',  'Support',  'rol-support@banc.test',  true, 'supportAgent'),
  ('banc-rol-valid',    'Valid',    'rol-valid@banc.test',    true, 'validator'),
  ('banc-rol-audit',    'Audit',    'rol-audit@banc.test',    true, 'auditor'),
  ('banc-rol-analyst',  'Analyst',  'rol-analyst@banc.test',  true, 'analyst');

-- ═══ 1. Les contraintes acceptent les huit rôles et refusent le reste ═══
DO $$
BEGIN
  BEGIN
    UPDATE public.users SET admin_role = 'roleInconnu' WHERE id = 'banc-rol-audit';
    INSERT INTO resultat VALUES (1, 'users.admin_role : valeur inconnue REFUSÉE', '23514', 'passé', 'ÉCHEC');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO resultat VALUES (1, 'users.admin_role : valeur inconnue REFUSÉE', '23514', '23514', 'OK');
  END;
  BEGIN
    INSERT INTO public.admin_role_permissions (role, permission) VALUES ('superAdmin', 'security.audit.view');
    INSERT INTO resultat VALUES (2, 'admin_role_permissions : superAdmin n''y figure pas', '23514', 'passé', 'ÉCHEC');
  EXCEPTION WHEN check_violation THEN
    INSERT INTO resultat VALUES (2, 'admin_role_permissions : superAdmin n''y figure pas', '23514', '23514', 'OK');
  END;
END $$;

-- ═══ 2. Nombre de droits posés par rôle (une clé absente du catalogue se verrait ici) ═══
INSERT INTO resultat
SELECT 3, 'supportAgent : 6 droits', '6', count(*)::text,
       CASE WHEN count(*) = 6 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_role_permissions WHERE role = 'supportAgent';
INSERT INTO resultat
SELECT 4, 'validator : 8 droits', '8', count(*)::text,
       CASE WHEN count(*) = 8 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_role_permissions WHERE role = 'validator';
INSERT INTO resultat
SELECT 5, 'auditor : 3 droits', '3', count(*)::text,
       CASE WHEN count(*) = 3 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_role_permissions WHERE role = 'auditor';
INSERT INTO resultat
SELECT 6, 'analyst : 3 droits', '3', count(*)::text,
       CASE WHEN count(*) = 3 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_role_permissions WHERE role = 'analyst';

-- ═══ 3. admin_has_permission, rôle par rôle ═══
-- Un cas par (compte, permission, attendu). Les refus comptent autant que les accès.
DO $$
DECLARE
  cas record;
  n int := 10;
  v boolean;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      ('banc-rol-audit',   'security.audit.view',        true),
      ('banc-rol-audit',   'security.audit.export',      true),
      ('banc-rol-audit',   'moderation.reports.review',  false),
      ('banc-rol-audit',   'support.tickets.reply',      false),
      ('banc-rol-audit',   'community.accounts.ban',     false),
      ('banc-rol-audit',   'settings.general.edit',      false),
      ('banc-rol-analyst', 'dashboard.analytics.view',   true),
      ('banc-rol-analyst', 'events.analytics.view',      true),
      ('banc-rol-analyst', 'security.audit.view',        false),
      ('banc-rol-analyst', 'community.members.view',     false),
      ('banc-rol-analyst', 'finance.transactions.view',  false),
      ('banc-rol-support', 'support.tickets.reply',      true),
      ('banc-rol-support', 'support.tickets.escalate',   true),
      ('banc-rol-support', 'support.templates.manage',   false),
      ('banc-rol-support', 'community.members.view',     false),
      ('banc-rol-support', 'security.audit.view',        false),
      ('banc-rol-support', 'privacy.requests.manage',    false),
      ('banc-rol-valid',   'consular.procedures.approve', true),
      ('banc-rol-valid',   'consular.embassies.verify',  true),
      ('banc-rol-valid',   'consular.procedures.publish', false),
      ('banc-rol-valid',   'communications.send',        false),
      ('banc-rol-valid',   'moderation.reports.review',  false),
      ('banc-rol-content', 'moderation.reports.review',  true),
      -- contentMod a reçu les droits de support avec la migration 20261018130000 : ce n'est pas un défaut.
      ('banc-rol-content', 'support.tickets.reply',      true),
      ('banc-rol-content', 'security.audit.export',      false),
      ('banc-rol-super',   'security.audit.export',      true),
      ('banc-rol-super',   'consular.procedures.publish', true)
    ) AS t(uid, perm, attendu)
  LOOP
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
      'app_metadata', jsonb_build_object('firebase_uid', cas.uid))::text, true);
    SET LOCAL ROLE authenticated;
    v := public.admin_has_permission(cas.perm);
    RESET ROLE;
    INSERT INTO resultat VALUES (n, cas.uid || ' · ' || cas.perm, cas.attendu::text, v::text,
      CASE WHEN v = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
END $$;

-- ═══ 4. L'ancien périmètre n'a pas bougé ═══
INSERT INTO resultat
SELECT 100, 'rôles historiques : au moins leur mapping d''origine (10 / 9 / 9) ; les migrations d''octobre en ont ajouté', '>=10/9/9',
       (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod') || '/' ||
       (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'businessMod') || '/' ||
       (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod'),
       CASE WHEN (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod') >= 10
             AND (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'businessMod') >= 9
             AND (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod') >= 9
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 5. Aucune ligne de droit ne vise une clé inconnue ═══
INSERT INTO resultat
SELECT 101, 'toutes les lignes de droit pointent le catalogue', '0',
       count(*)::text, CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_role_permissions rp
  LEFT JOIN public.admin_permissions p ON p.key = rp.permission
 WHERE p.key IS NULL;

-- ═══ Rapport ═══
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
