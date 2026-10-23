-- Banc : modération des événements (migration 20261018170000).
--
--   supabase db query --linked -f tools/rls_tests/evenements_moderation.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Les dangers sont : qu'un administrateur sans le droit
-- annule ou supprime l'événement de quelqu'un, sans motif, ou par une écriture
-- directe qui contournerait l'historique ; qu'une annulation ou un
-- déplacement ne laisse aucune trace de ce qui a changé et de qui l'a décidé ;
-- que l'historique se réécrive ; et que des champs sans importance
-- (compteur, image) le saturent. Il vérifie aussi que l'organisateur garde la
-- main sur son propre événement.

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
  ('banc-evt-super',   'Super',    'evt-super@banc.test',   true,  'superAdmin'),
  ('banc-evt-a',       'Agent A',  'evt-a@banc.test',       true,  'contentMod'),
  ('banc-evt-finance', 'Finance',  'evt-fin@banc.test',     true,  'financeMod'),
  ('banc-evt-org',     'Organisateur', 'evt-org@banc.test', false, NULL),
  ('banc-evt-ordi',    'Ordi',     'evt-ordi@banc.test',    false, NULL);

INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, attendee_count) VALUES
  ('00000000-0000-0000-0000-0000000000e1', 'banc-evt-org', 'e1 à annuler',  now() + interval '10 days', 'public', 'upcoming', 4),
  ('00000000-0000-0000-0000-0000000000e2', 'banc-evt-org', 'e2 à supprimer', now() + interval '10 days', 'public', 'upcoming', 0),
  ('00000000-0000-0000-0000-0000000000e3', 'banc-evt-org', 'e3 terminé',    now() - interval '10 days', 'public', 'ended',    9),
  ('00000000-0000-0000-0000-0000000000e4', 'banc-evt-org', 'e4 de l''organisateur', now() + interval '20 days', 'public', 'upcoming', 0);

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'events.cancel et events.delete au catalogue ; contentMod : cancel seul ; financeMod : rien', '2/1/0/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN ('events.cancel', 'events.delete')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission = 'events.cancel') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission = 'events.delete') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod' AND permission LIKE 'events.%'));
SELECT pg_temp.verifie(2, 'anon n''exécute ni l''annulation ni la suppression', 'false',
  (has_function_privilege('anon', 'public.event_admin_cancel(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.event_admin_delete(uuid,text)', 'EXECUTE'))::text);
SELECT pg_temp.verifie(3, 'personne n''écrit event_history directement', 'false',
  (has_table_privilege('authenticated', 'public.event_history', 'INSERT')
   OR has_table_privilege('authenticated', 'public.event_history', 'UPDATE')
   OR has_table_privilege('authenticated', 'public.event_history', 'DELETE')
   OR has_table_privilege('anon', 'public.event_history', 'SELECT'))::text);

-- ═══ 2. Annuler : refus ════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-evt-ordi');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'ordinaire : annuler REFUSÉ', '42501',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000e1', 'Salle indisponible')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-evt-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'financeMod : annuler REFUSÉ', '42501',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000e1', 'Salle indisponible')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-evt-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(12, 'A : annuler sans motif → 22023', '22023',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000e1', '   ')$q$);
SELECT pg_temp.essai(13, 'A : motif trop court → 22023', '22023',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000e1', 'non')$q$);
SELECT pg_temp.essai(14, 'A : événement introuvable → P0002', 'P0002',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000ff', 'Salle indisponible')$q$);
SELECT pg_temp.essai(15, 'A : annuler un événement terminé → 55000', '55000',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000e3', 'Salle indisponible')$q$);
SELECT pg_temp.essai(16, 'A : annule e1 avec motif', 'OK',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000e1', 'Salle indisponible')$q$);
SELECT pg_temp.essai(17, 'A : annuler e1 une seconde fois → 55000', '55000',
  $q$SELECT public.event_admin_cancel('00000000-0000-0000-0000-0000000000e1', 'Salle indisponible')$q$);
RESET ROLE;

-- ═══ 3. Supprimer ══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-evt-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'contentMod : supprimer REFUSÉ (events.delete réservé au superAdmin)', '42501',
  $q$SELECT public.event_admin_delete('00000000-0000-0000-0000-0000000000e2', 'Contenu illicite')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-evt-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(21, 'superAdmin : supprimer sans motif → 22023', '22023',
  $q$SELECT public.event_admin_delete('00000000-0000-0000-0000-0000000000e2', '')$q$);
SELECT pg_temp.essai(22, 'superAdmin : supprime e2 avec motif', 'OK',
  $q$SELECT public.event_admin_delete('00000000-0000-0000-0000-0000000000e2', 'Contenu illicite')$q$);
SELECT pg_temp.essai(23, 'superAdmin : supprimer e2 une seconde fois → P0002', 'P0002',
  $q$SELECT public.event_admin_delete('00000000-0000-0000-0000-0000000000e2', 'Contenu illicite')$q$);
RESET ROLE;
SELECT pg_temp.verifie(24, 'e2 n''existe plus', '0',
  (SELECT count(*)::text FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000e2'));

-- ═══ 4. Plus d'écriture directe pour un administrateur ═════════════════════
SELECT pg_temp.moi('banc-evt-a');
SET LOCAL ROLE authenticated;
UPDATE public.events SET status = 'cancelled' WHERE id = '00000000-0000-0000-0000-0000000000e4';
DELETE FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000e4';
RESET ROLE;
SELECT pg_temp.verifie(30, 'UPDATE et DELETE directs d''un admin : e4 intact', 'upcoming',
  (SELECT status FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000e4'));

-- ═══ 5. L'organisateur garde la main, et tout est consigné ═════════════════
SELECT pg_temp.moi('banc-evt-org');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'organisateur : déplace et change l''adresse', 'OK',
  $q$UPDATE public.events SET starts_at = starts_at + interval '1 day', address = 'Nouvelle adresse' WHERE id = '00000000-0000-0000-0000-0000000000e4'$q$);
SELECT pg_temp.essai(41, 'organisateur : change seulement l''image', 'OK',
  $q$UPDATE public.events SET cover_url = 'https://exemple.ne/x.jpg' WHERE id = '00000000-0000-0000-0000-0000000000e4'$q$);
RESET ROLE;
UPDATE public.events SET attendee_count = attendee_count + 1 WHERE id = '00000000-0000-0000-0000-0000000000e4';
SELECT pg_temp.moi('banc-evt-org');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(42, 'organisateur : annule son propre événement', 'OK',
  $q$UPDATE public.events SET status = 'cancelled' WHERE id = '00000000-0000-0000-0000-0000000000e4'$q$);
RESET ROLE;

SELECT pg_temp.verifie(50, 'e4 : 2 lignes d''historique (déplacement, annulation) — ni l''image ni le compteur', '2/organizer/organizer',
  (SELECT count(*) || '/' || min(actor_role) || '/' || max(actor_role)
     FROM public.event_history WHERE event_id = '00000000-0000-0000-0000-0000000000e4'));
SELECT pg_temp.verifie(51, 'e4 : le déplacement porte starts_at ET address, avec ancienne et nouvelle valeur', 'true/true/true',
  (SELECT (changes ? 'starts_at')::text || '/' || (changes ? 'address')::text || '/' ||
          ((changes -> 'address' ->> 'to') = 'Nouvelle adresse')::text
     FROM public.event_history WHERE event_id = '00000000-0000-0000-0000-0000000000e4' AND changes ? 'starts_at'));
SELECT pg_temp.verifie(52, 'e1 : annulation par l''admin, motif et valeurs consignés', 'changed/admin/banc-evt-a/Salle indisponible/upcoming>cancelled',
  (SELECT kind || '/' || actor_role || '/' || actor_id || '/' || reason || '/' ||
          (changes -> 'status' ->> 'from') || '>' || (changes -> 'status' ->> 'to')
     FROM public.event_history WHERE event_id = '00000000-0000-0000-0000-0000000000e1'));
SELECT pg_temp.verifie(53, 'e2 : suppression consignée avec instantané et motif', 'deleted/admin/Contenu illicite/e2 à supprimer',
  (SELECT kind || '/' || actor_role || '/' || reason || '/' || (changes ->> 'title')
     FROM public.event_history WHERE event_id = '00000000-0000-0000-0000-0000000000e2'));

-- ═══ 6. Qui lit l'historique, et il ne se réécrit pas ══════════════════════
SELECT pg_temp.moi('banc-evt-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(60, 'agent A (events.moderate) lit l''historique', '4',
  (SELECT count(*)::text FROM public.event_history));
RESET ROLE;
SELECT pg_temp.moi('banc-evt-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(61, 'financeMod ne lit rien', '0', (SELECT count(*)::text FROM public.event_history));
RESET ROLE;
SELECT pg_temp.moi('banc-evt-org');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(62, 'l''organisateur ne lit pas le journal', '0', (SELECT count(*)::text FROM public.event_history));
RESET ROLE;
SELECT pg_temp.essai(63, 'UPDATE de l''historique REFUSÉ (même pour le propriétaire)', '42501',
  $q$UPDATE public.event_history SET reason = 'réécrit'$q$);
SELECT pg_temp.essai(64, 'DELETE de l''historique REFUSÉ', '42501',
  $q$DELETE FROM public.event_history$q$);

-- ═══ 7. Audit ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(70, 'une annulation et une suppression auditées, rien pour les refus', '1/1/0/0',
  (SELECT count(*) FILTER (WHERE action = 'EVENT_CANCELLED' AND target_id = '00000000-0000-0000-0000-0000000000e1') || '/' ||
          count(*) FILTER (WHERE action = 'EVENT_DELETED' AND target_id = '00000000-0000-0000-0000-0000000000e2') || '/' ||
          count(*) FILTER (WHERE target_id = '00000000-0000-0000-0000-0000000000e3') || '/' ||
          count(*) FILTER (WHERE target_id = '00000000-0000-0000-0000-0000000000e4')
     FROM public.admin_audit_logs));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
