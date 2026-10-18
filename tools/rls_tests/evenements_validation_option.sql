-- Banc : validation des événements avant publication, en option
-- (migration 20261020090000).
--
--   supabase db query --linked -f tools/rls_tests/evenements_validation_option.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Le danger premier est qu'une option « désactivée » change
-- quelque chose : un nouvel événement doit rester immédiatement visible tant
-- que le réglage est faux. Viennent ensuite : qu'un organisateur s'approuve
-- lui-même (par colonne ou par RPC) ; qu'un événement en attente ou refusé
-- soit lisible d'un autre membre, d'un anonyme, de ses inscrits ou d'un
-- administrateur sans droit de modérer ; qu'un événement privé entre dans la
-- file ; qu'un brouillon publié ensuite y échappe ; et que l'audit porte le
-- motif d'un refus.

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
  ('banc-val-super',   'Super',   'val-super@banc.test', true,  'superAdmin'),
  ('banc-val-mod',     'Mod',     'val-mod@banc.test',   true,  'contentMod'),
  ('banc-val-finance', 'Finance', 'val-fin@banc.test',   true,  'financeMod'),
  ('banc-val-org',     'Orga',    'val-org@banc.test',   false, NULL),
  ('banc-val-autre',   'Autre',   'val-autre@banc.test', false, NULL);

-- ═══ 1. Droits et réglage ══════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'les 2 permissions existent ; contentMod porte approve, personne configure', '2/1/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN ('events.approve','events.approval.configure')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission = 'events.approve') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE permission = 'events.approval.configure'));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des cinq RPC', 'false',
  (has_function_privilege('anon', 'public.event_set_approval_required(boolean)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.event_admin_approve(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.event_admin_reject(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.event_resubmit(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.event_admin_pending()', 'EXECUTE'))::text);
SELECT pg_temp.verifie(3, 'le réglage naît FAUX', 'false',
  (SELECT require_approval::text FROM public.event_moderation_settings));
SELECT pg_temp.verifie(4, 'authenticated n''écrit pas le réglage', 'false',
  (has_table_privilege('authenticated', 'public.event_moderation_settings', 'UPDATE')
   OR has_table_privilege('authenticated', 'public.event_moderation_settings', 'INSERT'))::text);

SELECT pg_temp.moi('banc-val-mod');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(5, 'contentMod ne peut pas activer l''option', '42501',
  $q$ SELECT public.event_set_approval_required(true) $q$);
RESET ROLE;

-- ═══ 2. Option DÉSACTIVÉE : rien ne change ════════════════════════════════
SELECT pg_temp.moi('banc-val-org');
SET LOCAL ROLE authenticated;
INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, city, organizer_name) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'banc-val-org', 'a1 public, option coupée', '2031-03-10 18:00+00', 'public', 'upcoming', 'Niamey', 'Orga');
SELECT pg_temp.verifie(10, 'option coupée : l''événement public naît approuvé', 'approved',
  (SELECT approval_status FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000a1'));
SELECT pg_temp.essai(11, 'un organisateur ne s''approuve pas par colonne', '42501',
  $q$ UPDATE public.events SET approval_status = 'pending' WHERE id = '00000000-0000-0000-0000-0000000000a1' $q$);
SELECT pg_temp.essai(12, 'ni ne crée un événement déjà « refusé »', '42501',
  $q$ INSERT INTO public.events (organizer_id, title, starts_at, visibility, status, approval_status)
       VALUES ('banc-val-org', 'x', '2031-01-01 10:00+00', 'public', 'upcoming', 'rejected') $q$);
SELECT pg_temp.essai(13, 'ni ne pose une note d''approbation', '42501',
  $q$ UPDATE public.events SET approval_note = 'ok' WHERE id = '00000000-0000-0000-0000-0000000000a1' $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-val-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(14, 'option coupée : un autre membre le voit tout de suite', '1',
  (SELECT count(*)::text FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000a1'));
RESET ROLE;

-- ═══ 3. Activation ═════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-val-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'le superAdmin active l''option', 'OK',
  $q$ SELECT public.event_set_approval_required(true) $q$);
RESET ROLE;
SELECT pg_temp.verifie(21, 'le réglage est vrai', 'true',
  (SELECT require_approval::text FROM public.event_moderation_settings));

-- ═══ 4. Option ACTIVE ══════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-val-org');
SET LOCAL ROLE authenticated;
INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, city, organizer_name) VALUES
  ('00000000-0000-0000-0000-0000000000b1', 'banc-val-org', 'b1 public à valider', '2031-04-10 18:00+00', 'public', 'upcoming', 'Niamey', 'Orga'),
  ('00000000-0000-0000-0000-0000000000b2', 'banc-val-org', 'b2 privé',            '2031-04-11 18:00+00', 'people', 'upcoming', 'Niamey', 'Orga'),
  ('00000000-0000-0000-0000-0000000000b3', 'banc-val-org', 'b3 brouillon public', '2031-04-12 18:00+00', 'public', 'draft',    'Niamey', 'Orga'),
  ('00000000-0000-0000-0000-0000000000b4', 'banc-val-org', 'b4 public à refuser', '2031-04-13 18:00+00', 'public', 'upcoming', 'Niamey', 'Orga');
SELECT pg_temp.verifie(22, 'public publié : en attente ; privé et brouillon : approuvés', 'pending/approved/approved',
  (SELECT string_agg(approval_status, '/' ORDER BY title) FROM public.events WHERE title IN ('b1 public à valider','b2 privé','b3 brouillon public')));
SELECT pg_temp.verifie(23, 'l''organisateur voit ses événements en attente', '4',
  (SELECT count(*)::text FROM public.events WHERE title LIKE 'b_ %'));
UPDATE public.events SET status = 'upcoming' WHERE id = '00000000-0000-0000-0000-0000000000b3';
SELECT pg_temp.verifie(24, 'un brouillon publié ensuite entre dans la file', 'pending',
  (SELECT approval_status FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000b3'));
UPDATE public.events SET visibility = 'public' WHERE id = '00000000-0000-0000-0000-0000000000b2';
SELECT pg_temp.verifie(25, 'un privé rendu public aussi', 'pending',
  (SELECT approval_status FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000b2'));
UPDATE public.events SET title = 'a1 public, renommé' WHERE id = '00000000-0000-0000-0000-0000000000a1';
SELECT pg_temp.verifie(26, 'modifier un événement approuvé ne le remet pas en attente', 'approved',
  (SELECT approval_status FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000a1'));
SELECT pg_temp.essai(27, 'l''organisateur ne s''auto-approuve toujours pas', '42501',
  $q$ UPDATE public.events SET approval_status = 'approved' WHERE id = '00000000-0000-0000-0000-0000000000b1' $q$);
SELECT pg_temp.essai(28, 'l''organisateur n''appelle pas la RPC d''approbation', '42501',
  $q$ SELECT public.event_admin_approve('00000000-0000-0000-0000-0000000000b1') $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-val-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(30, 'un autre membre ne voit AUCUN événement en attente (b1, b2, b3, b4)', '0',
  (SELECT count(*)::text FROM public.events WHERE title LIKE 'b_ %'));
SELECT pg_temp.verifie(31, 'mais voit toujours l''approuvé (a1)', '1',
  (SELECT count(*)::text FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000a1'));
RESET ROLE;

SELECT pg_temp.verifie(32, 'un anonyme n''a aucun droit de lecture sur les événements (la validation ne l''ouvre pas)', 'false',
  has_table_privilege('anon', 'public.events', 'SELECT')::text);

SELECT pg_temp.moi('banc-val-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(33, 'financeMod (sans droit de modérer) ne voit pas l''en-attente', '0',
  (SELECT count(*)::text FROM public.events WHERE title LIKE 'b_ %'));
SELECT pg_temp.essai(34, 'financeMod n''approuve pas', '42501',
  $q$ SELECT public.event_admin_approve('00000000-0000-0000-0000-0000000000b1') $q$);
SELECT pg_temp.essai(35, 'financeMod ne lit pas la file', '42501',
  $q$ SELECT * FROM public.event_admin_pending() $q$);
RESET ROLE;

-- ═══ 5. La modération ══════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-val-mod');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(40, 'contentMod voit les 4 en attente par can_see_event', '4',
  (SELECT count(*)::text FROM public.events WHERE title LIKE 'b_ %'));
SELECT pg_temp.verifie(41, 'la file liste les 4 en attente (b1, b2 rendu public, b3 publié, b4)', '4',
  (SELECT count(*)::text FROM public.event_admin_pending() WHERE title LIKE 'b_ %'));
SELECT pg_temp.essai(42, 'refuser sans motif suffisant', '22023',
  $q$ SELECT public.event_admin_reject('00000000-0000-0000-0000-0000000000b4', 'non') $q$);
SELECT pg_temp.essai(43, 'événement inconnu', 'P0002',
  $q$ SELECT public.event_admin_approve('00000000-0000-0000-0000-0000000000ff') $q$);
SELECT pg_temp.essai(44, 'contentMod approuve b1', 'OK',
  $q$ SELECT public.event_admin_approve('00000000-0000-0000-0000-0000000000b1', 'RAS') $q$);
SELECT pg_temp.essai(45, 'déjà approuvé : conflit', '55000',
  $q$ SELECT public.event_admin_approve('00000000-0000-0000-0000-0000000000b1') $q$);
SELECT pg_temp.essai(46, 'on ne refuse pas un approuvé', '55000',
  $q$ SELECT public.event_admin_reject('00000000-0000-0000-0000-0000000000b1', 'motif long') $q$);
SELECT pg_temp.essai(47, 'contentMod refuse b4 avec un motif', 'OK',
  $q$ SELECT public.event_admin_reject('00000000-0000-0000-0000-0000000000b4', 'Description insuffisante et date incertaine') $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-val-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(48, 'après approbation de b1, un autre membre le voit ; pas b4 refusé', '1/0',
  (SELECT (SELECT count(*) FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000b1') || '/' ||
          (SELECT count(*) FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000b4')));
RESET ROLE;

-- Séparation : un administrateur ne valide pas son propre événement.
SELECT set_config('request.jwt.claims', '', true);  -- graine : sans session applicative
INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, city, organizer_name, approval_status) VALUES
  ('00000000-0000-0000-0000-0000000000c1', 'banc-val-mod', 'c1 événement de l''admin', '2031-05-01 18:00+00', 'public', 'upcoming', 'Niamey', 'Mod', 'pending');
SELECT pg_temp.moi('banc-val-mod');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(49, 'un administrateur n''approuve pas son propre événement', '42501',
  $q$ SELECT public.event_admin_approve('00000000-0000-0000-0000-0000000000c1') $q$);
RESET ROLE;

-- ═══ 6. Refus et nouvelle soumission ══════════════════════════════════════
SELECT pg_temp.moi('banc-val-org');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(50, 'l''organisateur lit le refus et son motif', 'rejected/true',
  (SELECT approval_status || '/' || (approval_note IS NOT NULL)
     FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000b4'));
SELECT pg_temp.essai(51, 'on ne soumet pas de nouveau un événement approuvé', '55000',
  $q$ SELECT public.event_resubmit('00000000-0000-0000-0000-0000000000b1') $q$);
SELECT pg_temp.essai(52, 'l''organisateur resoumet b4', 'OK',
  $q$ SELECT public.event_resubmit('00000000-0000-0000-0000-0000000000b4') $q$);
SELECT pg_temp.verifie(53, 'b4 est de nouveau en attente, sans note', 'pending/true',
  (SELECT approval_status || '/' || (approval_note IS NULL)
     FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000b4'));
RESET ROLE;

SELECT pg_temp.moi('banc-val-autre');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(54, 'un autre membre ne resoumet pas l''événement d''autrui', 'P0002',
  $q$ SELECT public.event_resubmit('00000000-0000-0000-0000-0000000000b4') $q$);
RESET ROLE;

-- ═══ 7. Retour à l'option coupée ══════════════════════════════════════════
SELECT pg_temp.moi('banc-val-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'le superAdmin coupe l''option', 'OK',
  $q$ SELECT public.event_set_approval_required(false) $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-val-org');
SET LOCAL ROLE authenticated;
INSERT INTO public.events (id, organizer_id, title, starts_at, visibility, status, city, organizer_name) VALUES
  ('00000000-0000-0000-0000-0000000000d1', 'banc-val-org', 'd1 après coupure', '2031-06-10 18:00+00', 'public', 'upcoming', 'Niamey', 'Orga');
SELECT pg_temp.verifie(61, 'option recoupée : un nouvel événement redevient immédiat', 'approved',
  (SELECT approval_status FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000d1'));
RESET ROLE;
SELECT pg_temp.verifie(62, 'mais ce qui était en attente le reste', 'pending',
  (SELECT approval_status FROM public.events WHERE id = '00000000-0000-0000-0000-0000000000b4'));

-- ═══ 8. Audit et calendrier ═══════════════════════════════════════════════
SELECT pg_temp.verifie(70, 'tracés : 2 changements de réglage, 1 approbation, 1 refus', '2/1/1',
  (SELECT count(*) FILTER (WHERE action = 'EVENT_APPROVAL_SETTING_CHANGED') || '/' ||
          count(*) FILTER (WHERE action = 'EVENT_APPROVED') || '/' ||
          count(*) FILTER (WHERE action = 'EVENT_REJECTED')
     FROM public.admin_audit_logs WHERE created_at >= now() - interval '1 minute'));
SELECT pg_temp.verifie(71, 'l''audit ne porte pas le motif du refus', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE details::text ILIKE '%Description insuffisante%'));
SELECT pg_temp.moi('banc-val-mod');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(72, 'le calendrier dit l''état d''approbation de chaque événement', 'true',
  (SELECT bool_and(e ? 'approval_status')::text
     FROM jsonb_array_elements(public.event_admin_calendar('2031-01-01+00', '2031-04-01+00') -> 'events') e));
RESET ROLE;

SELECT pg_temp.moi('banc-val-mod');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(73, 'la file « à traiter » compte les événements en attente', 'true',
  ((SELECT (e ->> 'total')::int FROM jsonb_array_elements(public.admin_attention_queue()) e
     WHERE e ->> 'key' = 'events_pending') >= 1)::text);
RESET ROLE;
SELECT pg_temp.moi('banc-val-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(74, 'financeMod ne la reçoit pas', '0',
  (SELECT count(*)::text FROM jsonb_array_elements(public.admin_attention_queue()) e WHERE e ->> 'key' = 'events_pending'));
RESET ROLE;

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
