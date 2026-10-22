-- Banc : workflow de modération des signalements (migration 20261017100000).
--
--   supabase db query --linked -f tools/rls_tests/moderation_signalements_workflow.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un dossier change de statut sans
-- permission, hors de la table des transitions, ou par quelqu'un d'autre que
-- son responsable ; et qu'une décision ne laisse pas de trace. Le banc vise
-- donc les refus (ordinaire, financeMod, autre modérateur, passage absent,
-- réouverture d'un dossier clos, double décision), puis le chemin nominal et
-- l'audit écrit dans la même transaction.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- Exécute q ; attendu = 'OK' (aucune erreur) ou le SQLSTATE refusé.
CREATE FUNCTION pg_temp.essai(n int, cas text, attendu text, q text) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE obtenu text;
BEGIN
  EXECUTE q;
  obtenu := 'OK';
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN obtenu = attendu THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (n, cas, attendu, SQLSTATE,
    CASE WHEN SQLSTATE = attendu THEN 'OK' ELSE 'ÉCHEC' END);
END $f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-mod-super',   'Super',   'mod-super@banc.test',   true,  'superAdmin'),
  ('banc-mod-a',       'Mod A',   'mod-a@banc.test',       true,  'contentMod'),
  ('banc-mod-b',       'Mod B',   'mod-b@banc.test',       true,  'contentMod'),
  ('banc-mod-finance', 'Finance', 'mod-fin@banc.test',     true,  'financeMod'),
  ('banc-mod-ordi',    'Ordi',    'mod-ordi@banc.test',    false, NULL);

INSERT INTO public.reports (id, reporter_id, target_type, target_id, reason) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'banc-mod-ordi', 'post', 'p1', 'spam'),
  ('00000000-0000-0000-0000-0000000000a2', 'banc-mod-ordi', 'post', 'p2', 'spam'),
  ('00000000-0000-0000-0000-0000000000a3', 'banc-mod-ordi', 'post', 'p3', 'spam');

-- ═══ 1. Catalogue ══════════════════════════════════════════════════════════
INSERT INTO resultat
SELECT 1, 'les 5 transitions sont en base', '5',
       count(*)::text, CASE WHEN count(*) = 5 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.moderation_report_transitions;

INSERT INTO resultat
SELECT 2, 'contentMod porte assign et escalate, financeMod aucune des deux', '2/0',
       (SELECT count(*) FROM public.admin_role_permissions
         WHERE role = 'contentMod' AND permission IN ('moderation.reports.assign','moderation.reports.escalate')) || '/' ||
       (SELECT count(*) FROM public.admin_role_permissions
         WHERE role = 'financeMod' AND permission LIKE 'moderation.%'),
       CASE WHEN (SELECT count(*) FROM public.admin_role_permissions
                   WHERE role = 'contentMod' AND permission IN ('moderation.reports.assign','moderation.reports.escalate')) = 2
             AND (SELECT count(*) FROM public.admin_role_permissions
                   WHERE role = 'financeMod' AND permission LIKE 'moderation.%') = 0
            THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat
SELECT 3, 'anon n''exécute pas signalement_transition', 'false',
       has_function_privilege('anon', 'public.signalement_transition(uuid,text,text,text,text)', 'EXECUTE')::text,
       CASE WHEN NOT has_function_privilege('anon', 'public.signalement_transition(uuid,text,text,text,text)', 'EXECUTE')
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 2. Refus avant tout ═══════════════════════════════════════════════════
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-ordi'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : prise en charge REFUSÉE', '42501',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'reviewing')$q$);
RESET ROLE;

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-finance'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod (admin sans droit de modération) : prise en charge REFUSÉE', '42501',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'reviewing')$q$);
RESET ROLE;

-- ═══ 3. Le modérateur A ════════════════════════════════════════════════════
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-a'))::text, true);
SET LOCAL ROLE authenticated;

SELECT pg_temp.essai(20, 'A : dossier introuvable → P0002', 'P0002',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000ff', 'reviewing')$q$);
SELECT pg_temp.essai(21, 'A : pending → resolved ABSENT de la table (55000)', '55000',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'resolved', 'content_removed', 'x', 'retrait')$q$);
SELECT pg_temp.essai(22, 'A : prend en charge a1', 'OK',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'reviewing')$q$);
SELECT pg_temp.essai(23, 'A : prend en charge a1 une seconde fois → 55000 (déjà reviewing)', '55000',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'reviewing')$q$);
SELECT pg_temp.essai(24, 'A : classer sans motif → 22023', '22023',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'dismissed', NULL, 'faits')$q$);
SELECT pg_temp.essai(25, 'A : classer avec un motif hors liste → 22023', '22023',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'dismissed', 'je_nai_pas_envie', 'faits')$q$);
SELECT pg_temp.essai(26, 'A : classer sans justification → 22023', '22023',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'dismissed', 'duplicate', '   ')$q$);
SELECT pg_temp.essai(27, 'A : résoudre sans action exécutée → 22023', '22023',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'resolved', 'content_removed', 'faits')$q$);
RESET ROLE;

INSERT INTO resultat
SELECT 28, 'a1 attribué à A, statut reviewing', 'banc-mod-a/reviewing',
       assigned_to || '/' || status,
       CASE WHEN assigned_to = 'banc-mod-a' AND status = 'reviewing' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.reports WHERE id = '00000000-0000-0000-0000-0000000000a1';

-- B ne décide pas le dossier de A.
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-b'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'B : décider le dossier de A REFUSÉ', '42501',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'dismissed', 'duplicate', 'faits')$q$);
RESET ROLE;

-- A décide : classement sans suite.
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-a'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(31, 'A : classe sans suite (motif + justification)', 'OK',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'dismissed', 'duplicate', 'Doublon du dossier précédent')$q$);
SELECT pg_temp.essai(32, 'A : seconde décision sur un dossier clos → 55000', '55000',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'resolved', 'content_removed', 'x', 'retrait')$q$);
SELECT pg_temp.essai(33, 'A : réouvrir un dossier clos → 55000', '55000',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a1', 'reviewing')$q$);
RESET ROLE;

INSERT INTO resultat
SELECT 34, 'a1 : dismissed, motif duplicate, relevé par A', 'dismissed/duplicate/banc-mod-a',
       status || '/' || reason_code || '/' || reviewed_by,
       CASE WHEN status = 'dismissed' AND reason_code = 'duplicate' AND reviewed_by = 'banc-mod-a'
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.reports WHERE id = '00000000-0000-0000-0000-0000000000a1';

INSERT INTO resultat
SELECT 35, 'audit : REPORT_ASSIGNED puis MODERATION_DECIDED pour a1, acteur A', '1/1',
       (SELECT count(*) FROM public.admin_audit_logs
         WHERE target_type = 'report' AND target_id = '00000000-0000-0000-0000-0000000000a1'
           AND action = 'REPORT_ASSIGNED' AND admin_id = 'banc-mod-a') || '/' ||
       (SELECT count(*) FROM public.admin_audit_logs
         WHERE target_type = 'report' AND target_id = '00000000-0000-0000-0000-0000000000a1'
           AND action = 'MODERATION_DECIDED' AND admin_id = 'banc-mod-a'
           AND reason_code = 'duplicate' AND details->>'to' = 'dismissed'),
       CASE WHEN (SELECT count(*) FROM public.admin_audit_logs
                   WHERE target_id = '00000000-0000-0000-0000-0000000000a1'
                     AND action = 'REPORT_ASSIGNED' AND admin_id = 'banc-mod-a') = 1
             AND (SELECT count(*) FROM public.admin_audit_logs
                   WHERE target_id = '00000000-0000-0000-0000-0000000000a1'
                     AND action = 'MODERATION_DECIDED' AND admin_id = 'banc-mod-a'
                     AND reason_code = 'duplicate' AND details->>'to' = 'dismissed') = 1
            THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 4. Escalade, reprise, superAdmin ══════════════════════════════════════
SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-a'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'A : prend a2', 'OK',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a2', 'reviewing')$q$);
SELECT pg_temp.essai(41, 'A : escalade a2 sans motif normalisé → 22023', '22023',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a2', 'escalated', NULL, 'doute')$q$);
SELECT pg_temp.essai(42, 'A : escalade a2 (conflict_of_interest)', 'OK',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a2', 'escalated', 'conflict_of_interest', 'Je connais le membre')$q$);
RESET ROLE;

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-b'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(43, 'B : reprend a2 escaladé', 'OK',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a2', 'reviewing')$q$);
RESET ROLE;

INSERT INTO resultat
SELECT 44, 'a2 : repris par B', 'banc-mod-b/reviewing',
       assigned_to || '/' || status,
       CASE WHEN assigned_to = 'banc-mod-b' AND status = 'reviewing' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.reports WHERE id = '00000000-0000-0000-0000-0000000000a2';

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-a'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(45, 'A : décider a2, désormais à B, REFUSÉ', '42501',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a2', 'dismissed', 'duplicate', 'x')$q$);
RESET ROLE;

SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
  'app_metadata', jsonb_build_object('firebase_uid','banc-mod-super'))::text, true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(46, 'superAdmin : décide a2 attribué à B', 'OK',
  $q$SELECT public.signalement_transition('00000000-0000-0000-0000-0000000000a2', 'resolved', 'user_warned', 'Avertissement envoyé', 'avertissement')$q$);
RESET ROLE;

INSERT INTO resultat
SELECT 47, 'a2 : resolved avec action_taken enregistrée', 'resolved/avertissement',
       status || '/' || action_taken,
       CASE WHEN status = 'resolved' AND action_taken = 'avertissement' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.reports WHERE id = '00000000-0000-0000-0000-0000000000a2';

-- ═══ 5. Un refus ne laisse ni changement ni trace de succès ════════════════
INSERT INTO resultat
SELECT 50, 'a3 intact (jamais touché), aucune ligne d''audit', 'pending/0',
       status || '/' || (SELECT count(*) FROM public.admin_audit_logs
                          WHERE target_id = '00000000-0000-0000-0000-0000000000a3'),
       CASE WHEN status = 'pending' AND (SELECT count(*) FROM public.admin_audit_logs
                          WHERE target_id = '00000000-0000-0000-0000-0000000000a3') = 0
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.reports WHERE id = '00000000-0000-0000-0000-0000000000a3';

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
