-- Banc : modération des groupes (migration 20261019173000).
--
--   python tools/rls_tests/repeter_cible.py tools/rls_tests/groupes_moderation_admin.sql \
--     supabase/migrations/20261019173000_groupes_moderation_admin.sql <sortie.sql>
--   supabase db query --linked -f <sortie.sql>
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- CE QU'IL VÉRIFIE. Le danger est qu'un agent sans droit change la
-- confidentialité ou supprime un groupe ; qu'un groupe OFFICIEL soit touché
-- par un autre qu'un superAdmin ; qu'une suppression emporte des événements
-- sans le dire ; qu'un geste ne laisse ni motif, ni historique, ni audit ; que
-- l'historique se réécrive ; et que la lecture des groupes privés s'ouvre à
-- n'importe quel administrateur ou compte.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

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

CREATE FUNCTION pg_temp.moi(uid text) RETURNS void
LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', uid))::text, true)
$f$;

CREATE FUNCTION pg_temp.verifie(n int, cas text, attendu text, obtenu text) RETURNS void
LANGUAGE sql AS $f$
  INSERT INTO resultat VALUES (n, cas, attendu, obtenu,
    CASE WHEN attendu = obtenu THEN 'OK' ELSE 'ÉCHEC' END)
$f$;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-grp-super',   'Super',   'grp-super@banc.test',   true,  'superAdmin'),
  ('banc-grp-content', 'Content', 'grp-content@banc.test', true,  'contentMod'),
  ('banc-grp-finance', 'Finance', 'grp-fin@banc.test',     true,  'financeMod'),
  ('banc-grp-ordi',    'Ordi',    'grp-ordi@banc.test',    false, NULL);

-- Les groupes se créent sous l'identité d'un administrateur : le déclencheur
-- impose le créateur, et marquer un groupe officiel exige is_admin().
SELECT pg_temp.moi('banc-grp-super');
-- Un seul groupe officiel par pays : g3 prend un pays qui n'existe pas.
INSERT INTO public.groups (id, name, is_private, is_official, member_count, country_code) VALUES
  ('00000000-0000-0000-0000-00000000aa01', 'g1 public ordinaire', false, false, 7, 'Banc-Pays'),
  ('00000000-0000-0000-0000-00000000aa02', 'g2 privé ordinaire',  true,  false, 3, 'Banc-Pays'),
  ('00000000-0000-0000-0000-00000000aa03', 'g3 officiel',         false, true,  40, 'Banc-Pays-Officiel'),
  ('00000000-0000-0000-0000-00000000aa04', 'g4 à supprimer',      false, false, 2, 'Banc-Pays'),
  ('00000000-0000-0000-0000-00000000aa05', 'g5 intact',           false, false, 1, 'Banc-Pays');
INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, group_id) VALUES
  ('00000000-0000-0000-0000-00000000ee01', 'banc-grp-ordi', 'e1 du groupe 4', now() + interval '10 days', 'public', 'upcoming', '00000000-0000-0000-0000-00000000aa04');

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'community.groups.manage : contentMod seul', 'contentMod',
  (SELECT string_agg(role, ',') FROM public.admin_role_permissions WHERE permission = 'community.groups.manage'));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des deux fonctions', 'false',
  (has_function_privilege('anon', 'public.group_admin_set_privacy(text,boolean,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.group_admin_delete(text,text)', 'EXECUTE'))::text);

-- ═══ 2. Confidentialité ════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-grp-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : changer REFUSÉ', '42501',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa01', true, 'Test du banc')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-grp-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : changer REFUSÉ', '42501',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa01', true, 'Test du banc')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-grp-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'contentMod : motif trop court → 22023', '22023',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa01', true, 'xx')$q$);
SELECT pg_temp.essai(13, 'contentMod : identifiant invalide → 22023', '22023',
  $q$SELECT public.group_admin_set_privacy('pas-un-uuid', true, 'Test du banc')$q$);
SELECT pg_temp.essai(14, 'contentMod : groupe inconnu → P0002', 'P0002',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000ffff', true, 'Test du banc')$q$);
SELECT pg_temp.essai(15, 'contentMod : valeur nulle → 22023', '22023',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa01', NULL, 'Test du banc')$q$);
SELECT pg_temp.essai(16, 'contentMod : g1 devient privé', 'OK',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa01', true, 'Contenu signalé à plusieurs reprises')$q$);
SELECT pg_temp.essai(17, 'contentMod : g1 déjà privé → 55000', '55000',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa01', true, 'Contenu signalé à plusieurs reprises')$q$);
SELECT pg_temp.essai(18, 'contentMod : groupe officiel REFUSÉ', '42501',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa03', true, 'Test du banc officiel')$q$);
RESET ROLE;
SELECT pg_temp.verifie(19, 'g1 est bien privé, g3 officiel est resté public', 'true/false',
  (SELECT (SELECT is_private::text FROM public.groups WHERE id = '00000000-0000-0000-0000-00000000aa01') || '/' ||
          (SELECT is_private::text FROM public.groups WHERE id = '00000000-0000-0000-0000-00000000aa03')));

SELECT pg_temp.moi('banc-grp-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'superAdmin : groupe officiel modifié', 'OK',
  $q$SELECT public.group_admin_set_privacy('00000000-0000-0000-0000-00000000aa03', true, 'Décision de la direction')$q$);
RESET ROLE;

-- ═══ 3. Lecture des groupes privés ═════════════════════════════════════════
SELECT pg_temp.moi('banc-grp-content');
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE lu_content AS SELECT count(*) n FROM public.groups WHERE is_private;
RESET ROLE;
SELECT pg_temp.moi('banc-grp-finance');
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE lu_finance AS SELECT count(*) n FROM public.groups WHERE is_private;
RESET ROLE;
SELECT pg_temp.moi('banc-grp-ordi');
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE lu_ordi AS SELECT count(*) n FROM public.groups WHERE is_private;
RESET ROLE;
SELECT pg_temp.verifie(30, 'contentMod voit les groupes privés (g1, g2, g3 : au moins 3)', 'true',
  ((SELECT n FROM lu_content) >= 3)::text);
SELECT pg_temp.verifie(31, 'financeMod et un compte ordinaire n''en voient aucun des trois', 'true',
  ((SELECT n FROM lu_finance) < (SELECT n FROM lu_content) AND (SELECT n FROM lu_ordi) < (SELECT n FROM lu_content))::text);

-- ═══ 4. Suppression ════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-grp-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'ordinaire : supprimer REFUSÉ', '42501',
  $q$SELECT public.group_admin_delete('00000000-0000-0000-0000-00000000aa04', 'Test du banc')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-grp-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(41, 'financeMod : supprimer REFUSÉ', '42501',
  $q$SELECT public.group_admin_delete('00000000-0000-0000-0000-00000000aa04', 'Test du banc')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-grp-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(42, 'contentMod : motif vide → 22023', '22023',
  $q$SELECT public.group_admin_delete('00000000-0000-0000-0000-00000000aa04', '   ')$q$);
SELECT pg_temp.essai(43, 'contentMod : groupe inconnu → P0002', 'P0002',
  $q$SELECT public.group_admin_delete('00000000-0000-0000-0000-00000000ffff', 'Test du banc')$q$);
SELECT pg_temp.essai(44, 'contentMod : groupe officiel REFUSÉ', '42501',
  $q$SELECT public.group_admin_delete('00000000-0000-0000-0000-00000000aa03', 'Test du banc officiel')$q$);
-- L'ancien chemin direct reste fermé : DELETE sans policy = 0 ligne, pas d'erreur.
DELETE FROM public.groups WHERE id = '00000000-0000-0000-0000-00000000aa05';
RESET ROLE;
SELECT pg_temp.verifie(45, 'le DELETE direct d''un administrateur ne supprime rien', '1',
  (SELECT count(*)::text FROM public.groups WHERE id = '00000000-0000-0000-0000-00000000aa05'));
SELECT pg_temp.verifie(46, 'rien n''a été supprimé par les refus', '1',
  (SELECT count(*)::text FROM public.groups WHERE id = '00000000-0000-0000-0000-00000000aa04'));

SELECT pg_temp.moi('banc-grp-content');
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE suppr AS SELECT public.group_admin_delete('00000000-0000-0000-0000-00000000aa04', 'Groupe de revente illégale') AS evenements;
RESET ROLE;
SELECT pg_temp.verifie(47, 'la suppression rend le nombre d''événements emportés', '1', (SELECT evenements::text FROM suppr));
SELECT pg_temp.verifie(48, 'le groupe et son événement ont disparu', '0/0',
  (SELECT count(*) FROM public.groups WHERE id = '00000000-0000-0000-0000-00000000aa04') || '/' ||
  (SELECT count(*) FROM public.events WHERE id = '00000000-0000-0000-0000-00000000ee01'));
SELECT pg_temp.verifie(49, 'l''historique garde le nom, le motif et ce qui est parti', 'g4 à supprimer/Groupe de revente illégale/1',
  (SELECT group_name || '/' || reason || '/' || (metadata->>'events_deleted')
     FROM public.group_moderation_events WHERE kind = 'deleted'));

SELECT pg_temp.moi('banc-grp-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'superAdmin : supprime un groupe officiel', 'OK',
  $q$SELECT public.group_admin_delete('00000000-0000-0000-0000-00000000aa03', 'Fermeture du groupe officiel')$q$);
RESET ROLE;

-- ═══ 5. Historique, audit, ajout seul ══════════════════════════════════════
SELECT pg_temp.verifie(60, 'historique : 2 confidentialités, 2 suppressions', '2/2',
  (SELECT count(*) FILTER (WHERE kind = 'privacy_changed') || '/' || count(*) FILTER (WHERE kind = 'deleted')
     FROM public.group_moderation_events));
SELECT pg_temp.verifie(61, 'audit : GROUP_PRIVACY_CHANGED 2, GROUP_DELETED 2', '2/2',
  (SELECT count(*) FILTER (WHERE action = 'GROUP_PRIVACY_CHANGED') || '/' || count(*) FILTER (WHERE action = 'GROUP_DELETED')
     FROM public.admin_audit_logs WHERE target_id LIKE '00000000-0000-0000-0000-00000000aa%'));
SELECT pg_temp.verifie(62, 'l''audit ne contient pas les motifs', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id LIKE '00000000-0000-0000-0000-00000000aa%'
      AND (details::text LIKE '%revente%' OR details::text LIKE '%signalé%' OR details::text LIKE '%direction%')));
SELECT pg_temp.essai(63, 'UPDATE de l''historique refusé', '42501',
  $q$UPDATE public.group_moderation_events SET reason = 'falsifié'$q$);
SELECT pg_temp.essai(64, 'DELETE de l''historique refusé', '42501',
  $q$DELETE FROM public.group_moderation_events$q$);
SELECT pg_temp.essai(65, 'TRUNCATE de l''historique refusé', '42501',
  $q$TRUNCATE public.group_moderation_events$q$);

SELECT pg_temp.moi('banc-grp-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(66, 'un compte ordinaire ne lit pas l''historique', '0',
  (SELECT count(*)::text FROM public.group_moderation_events));
RESET ROLE;
SELECT pg_temp.moi('banc-grp-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(67, 'contentMod lit l''historique', '4',
  (SELECT count(*)::text FROM public.group_moderation_events));
RESET ROLE;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
