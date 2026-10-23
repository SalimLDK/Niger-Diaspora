-- Banc : calendrier, inscrits et statistiques des événements (migration
-- 20261019190000).
--
--   supabase db query --linked -f tools/rls_tests/evenements_calendrier_inscrits_stats.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger est qu'une liste de personnes (les inscrits) soit
-- lisible par un rôle qui n'y a pas droit, ou le soit sans trace ; qu'un
-- agenda privé soit lu par un modérateur ; et que des statistiques annoncent
-- des chiffres que la base ne peut pas mesurer. Les événements d'essai sont en
-- 2031, les statistiques se comparent AVANT / APRÈS (les vrais événements ne
-- perturbent pas le banc).

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;
CREATE TEMP TABLE avant(k text, v jsonb);
GRANT ALL ON avant TO anon, authenticated;

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
  ('banc-evs-super',   'Super',    'evs-super@banc.test',   true,  'superAdmin'),
  ('banc-evs-content', 'Content',  'evs-content@banc.test', true,  'contentMod'),
  ('banc-evs-finance', 'Finance',  'evs-fin@banc.test',     true,  'financeMod'),
  ('banc-evs-ordi',    'Ordi',     'evs-ordi@banc.test',    false, NULL),
  ('banc-evs-org',     'Organisateur', 'evs-org@banc.test', false, NULL),
  ('banc-evs-a1',      'Alice Inscrite', 'evs-a1@banc.test', false, NULL),
  ('banc-evs-a2',      'Bob Inscrit',    'evs-a2@banc.test', false, NULL),
  ('banc-evs-a3',      'Carla Inscrite', 'evs-a3@banc.test', false, NULL);

-- Les chiffres AVANT les événements d'essai.
SELECT pg_temp.moi('banc-evs-super');
SET LOCAL ROLE authenticated;
INSERT INTO avant SELECT 'stats', public.event_admin_stats(30);
RESET ROLE;

INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, max_attendees, city, organizer_name) VALUES
  ('00000000-0000-0000-0000-0000000000f1', 'banc-evs-org', 'f1 public à venir', '2031-03-10 18:00+00', 'public', 'upcoming', 10, 'Niamey', 'Organisateur'),
  ('00000000-0000-0000-0000-0000000000f2', 'banc-evs-org', 'f2 public à annuler', '2031-03-20 18:00+00', 'public', 'upcoming', 10, 'Zinder', 'Organisateur'),
  ('00000000-0000-0000-0000-0000000000f3', 'banc-evs-org', 'f3 privé (invités)', '2031-03-15 18:00+00', 'people', 'upcoming', NULL, 'Maradi', 'Organisateur'),
  ('00000000-0000-0000-0000-0000000000f4', 'banc-evs-org', 'f4 brouillon', '2031-03-25 18:00+00', 'public', 'draft', NULL, 'Agadez', 'Organisateur'),
  ('00000000-0000-0000-0000-0000000000f5', 'banc-evs-org', 'f5 hors période', '2031-06-10 18:00+00', 'public', 'upcoming', NULL, 'Niamey', 'Organisateur');
INSERT INTO public.event_attendees (event_id, user_id) VALUES
  ('00000000-0000-0000-0000-0000000000f1', 'banc-evs-a1'),
  ('00000000-0000-0000-0000-0000000000f1', 'banc-evs-a2'),
  ('00000000-0000-0000-0000-0000000000f1', 'banc-evs-a3'),
  ('00000000-0000-0000-0000-0000000000f3', 'banc-evs-a1');

-- ═══ 1. Droits ═════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(1, '2 permissions au catalogue ; analytics pour contentMod, attendance pour AUCUN rôle', '2/1/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN ('events.attendance.view', 'events.analytics.view')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission = 'events.analytics.view') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE permission = 'events.attendance.view'));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des trois fonctions', 'false',
  (has_function_privilege('anon', 'public.event_admin_calendar(timestamptz,timestamptz)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.event_admin_attendees(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.event_admin_stats(integer)', 'EXECUTE'))::text);

-- ═══ 2. Calendrier ═════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-evs-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : calendrier REFUSÉ', '42501',
  $q$SELECT public.event_admin_calendar('2031-03-01+00', '2031-04-01+00')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-evs-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : calendrier REFUSÉ', '42501',
  $q$SELECT public.event_admin_calendar('2031-03-01+00', '2031-04-01+00')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-evs-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'période à l''envers → 22023', '22023',
  $q$SELECT public.event_admin_calendar('2031-04-01+00', '2031-03-01+00')$q$);
SELECT pg_temp.essai(13, 'période de 200 jours → 22023', '22023',
  $q$SELECT public.event_admin_calendar('2031-01-01+00', '2031-07-20+00')$q$);
SELECT pg_temp.verifie(14, 'mars 2031 : les 2 événements publics, dans l''ordre ; le privé et le brouillon sont comptés, pas listés', '2/f1 public à venir/f2 public à annuler/2',
  (SELECT jsonb_array_length(r -> 'events') || '/' || (r -> 'events' -> 0 ->> 'title') || '/' || (r -> 'events' -> 1 ->> 'title') || '/' || (r ->> 'hidden_private')
     FROM (SELECT public.event_admin_calendar('2031-03-01+00', '2031-04-01+00') AS r) x));
SELECT pg_temp.verifie(15, 'le titre de l''événement privé n''apparaît nulle part dans la réponse', 'false',
  (SELECT (public.event_admin_calendar('2031-03-01+00', '2031-04-01+00')::text LIKE '%privé (invités)%')::text));
RESET ROLE;

-- ═══ 3. Les inscrits : une liste de personnes ═════════════════════════════
SELECT pg_temp.moi('banc-evs-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'contentMod : liste des inscrits REFUSÉE', '42501',
  $q$SELECT * FROM public.event_admin_attendees('00000000-0000-0000-0000-0000000000f1')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-evs-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(21, 'ordinaire : liste des inscrits REFUSÉE', '42501',
  $q$SELECT * FROM public.event_admin_attendees('00000000-0000-0000-0000-0000000000f1')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-evs-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(22, 'événement introuvable → P0002', 'P0002',
  $q$SELECT * FROM public.event_admin_attendees('00000000-0000-0000-0000-0000000000ff')$q$);
SELECT pg_temp.verifie(23, 'superAdmin lit les 3 inscrits, avec leurs noms, dans l''ordre', '3/Alice Inscrite',
  (SELECT count(*) || '/' || min(display_name) FROM public.event_admin_attendees('00000000-0000-0000-0000-0000000000f1')));
RESET ROLE;
SELECT pg_temp.verifie(24, 'la consultation est journalisée : une ligne, le nombre de lignes, aucun nom', '1/3/0',
  (SELECT count(*) || '/' || max((details ->> 'count')::int) ||  '/' ||
          count(*) FILTER (WHERE details::text LIKE '%Alice%' OR details::text LIKE '%banc-evs-a%')
     FROM public.admin_audit_logs WHERE action = 'EVENT_ATTENDEES_VIEWED'));

-- ═══ 4. Statistiques ═══════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-evs-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'financeMod : statistiques REFUSÉES', '42501', $q$SELECT public.event_admin_stats(30)$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-evs-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(31, 'fenêtre de 0 jour → 22023', '22023', $q$SELECT public.event_admin_stats(0)$q$);
SELECT pg_temp.essai(32, 'fenêtre de 400 jours → 22023', '22023', $q$SELECT public.event_admin_stats(400)$q$);
RESET ROLE;

-- Annulation d'un événement par la voie normale : elle entre dans l'historique, donc dans les statistiques.
SELECT pg_temp.moi('banc-evs-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(33, 'contentMod annule f2', 'OK',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000f2', 'Salle indisponible')$q$);
SELECT pg_temp.verifie(34, 'écarts AVANT / APRÈS : 5 créés, 4 inscriptions, 3 à venir de plus (f1, f3, f5), 1 annulation', '5/4/3/1',
  (SELECT ((a ->> 'events_created')::int - (b ->> 'events_created')::int) || '/' ||
          ((a ->> 'registrations')::int - (b ->> 'registrations')::int) || '/' ||
          ((a ->> 'events_upcoming')::int - (b ->> 'events_upcoming')::int) || '/' ||
          ((a ->> 'events_cancelled')::int - (b ->> 'events_cancelled')::int)
     FROM (SELECT public.event_admin_stats(30) AS a, (SELECT v FROM avant WHERE k = 'stats') AS b) x));
SELECT pg_temp.verifie(35, 'la réponse porte ses définitions et dit ce qu''elle ne mesure pas', 'true/true',
  (SELECT ((r -> 'definitions') ? 'registrations')::text || '/' ||
          ((r -> 'not_measured')::text LIKE '%participations confirmées%')::text
     FROM (SELECT public.event_admin_stats(30) AS r) x));
RESET ROLE;

-- ═══ 5. Rien de plus que les fonctions ════════════════════════════════════
SELECT pg_temp.moi('banc-evs-content');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(40, 'contentMod (events.moderate) voit les 5 événements d''essai (brouillon et privé compris) mais lit les inscrits comme un membre : ceux du PUBLIC, pas ceux du PRIVÉ', '5/3/0',
  (SELECT (SELECT count(*) FROM public.events WHERE title LIKE 'f_ %') || '/' ||
          (SELECT count(*) FROM public.event_attendees WHERE event_id = '00000000-0000-0000-0000-0000000000f1') || '/' ||
          (SELECT count(*) FROM public.event_attendees WHERE event_id = '00000000-0000-0000-0000-0000000000f3')));
RESET ROLE;
SELECT pg_temp.moi('banc-evs-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(41, 'financeMod ne voit plus que les 3 événements PUBLICS publiés (ni le brouillon ni le privé), et aucun inscrit du privé', '3/0',
  (SELECT (SELECT count(*) FROM public.events WHERE title LIKE 'f_ %') || '/' ||
          (SELECT count(*) FROM public.event_attendees WHERE event_id = '00000000-0000-0000-0000-0000000000f3')));
RESET ROLE;
SELECT pg_temp.moi('banc-evs-a1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(42, 'régression : un inscrit à l''événement privé le voit toujours (ses lignes et sa visibilité)', '1/1',
  (SELECT (SELECT count(*) FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000f3') || '/' ||
          (SELECT count(*) FROM public.event_attendees WHERE event_id = '00000000-0000-0000-0000-0000000000f3')));
RESET ROLE;
SELECT pg_temp.moi('banc-evs-org');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(43, 'régression : l''organisateur voit ses 5 événements', '5',
  (SELECT count(*)::text FROM public.events WHERE title LIKE 'f_ %'));
RESET ROLE;
SELECT pg_temp.moi('banc-evs-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(44, 'la fonction ouvre au superAdmin la liste de l''événement privé, journalisée', '1',
  (SELECT count(*)::text FROM public.event_admin_attendees('00000000-0000-0000-0000-0000000000f3')));
RESET ROLE;
SELECT pg_temp.moi('banc-evs-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(45, 'régression : un membre ordinaire voit les événements publics, pas le privé ni le brouillon', '3',
  (SELECT count(*)::text FROM public.events WHERE title LIKE 'f_ %'));
RESET ROLE;
SELECT pg_temp.verifie(46, 'la fonction interne n''est pas appelable', 'false',
  (has_function_privilege('authenticated', 'public.can_see_event_as_member(uuid)', 'EXECUTE'))::text);

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
