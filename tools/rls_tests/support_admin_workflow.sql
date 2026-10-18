-- Banc : workflow du support (migration 20261018130000).
--
--   supabase db query --linked -f tools/rls_tests/support_admin_workflow.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Les dangers sont : qu'un utilisateur écrive une réponse
-- « du support » ou se donne un responsable dans son propre ticket ; qu'un
-- agent décide le ticket d'un autre, ou réponde sans l'avoir pris ; qu'une note
-- interne soit lisible par l'utilisateur ; qu'un administrateur écrive les
-- tables sans passer par les RPC ; et qu'une action réussie laisse son audit
-- quand un refus n'en laisse aucun. Il vérifie aussi que l'application peut
-- toujours créer un ticket avec ses colonnes réelles.

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
  ('banc-sup-super',   'Super',    'sup-super@banc.test',   true,  'superAdmin'),
  ('banc-sup-a',       'Agent A',  'sup-a@banc.test',       true,  'contentMod'),
  ('banc-sup-b',       'Agent B',  'sup-b@banc.test',       true,  'contentMod'),
  ('banc-sup-finance', 'Finance',  'sup-fin@banc.test',     true,  'financeMod'),
  ('banc-sup-u1',      'Membre 1', 'sup-u1@banc.test',      false, NULL),
  ('banc-sup-u2',      'Membre 2', 'sup-u2@banc.test',      false, NULL);

INSERT INTO public.support_tickets (id, user_id, subject, status, assigned_to, messages) VALUES
  ('00000000-0000-0000-0000-0000000000d1', 'banc-sup-u1', 't1 ouvert',     'open',        NULL,
   '[{"id":"m0","senderId":"banc-sup-u1","senderName":"U1","isFromSupport":false,"content":"Bonjour","createdAt":"2026-10-18T00:00:00Z"}]'),
  ('00000000-0000-0000-0000-0000000000d2', 'banc-sup-u1', 't2 en cours A', 'in_progress', 'banc-sup-a',
   '[{"id":"m0","senderId":"banc-sup-u1","senderName":"U1","isFromSupport":false,"content":"Bonjour","createdAt":"2026-10-18T00:00:00Z"}]'),
  ('00000000-0000-0000-0000-0000000000d3', 'banc-sup-u1', 't3 ouvert',     'open',        NULL,
   '[{"id":"m0","senderId":"banc-sup-u1","senderName":"U1","isFromSupport":false,"content":"Bonjour","createdAt":"2026-10-18T00:00:00Z"}]'),
  ('00000000-0000-0000-0000-0000000000d4', 'banc-sup-u1', 't4 résolu A',   'resolved',    'banc-sup-a',
   '[{"id":"m0","senderId":"banc-sup-u1","senderName":"U1","isFromSupport":false,"content":"Bonjour","createdAt":"2026-10-18T00:00:00Z"}]');

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'les 4 permissions sont au catalogue, contentMod les porte, financeMod aucune', '4/4/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key LIKE 'support.tickets.%') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission LIKE 'support.tickets.%') || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod' AND permission LIKE 'support.%'));
SELECT pg_temp.verifie(2, 'anon n''exécute aucune des cinq RPC', 'false',
  (has_function_privilege('anon', 'public.support_ticket_transition(uuid,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_ticket_reply(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_ticket_note(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_ticket_set_priority(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_ticket_mark_read(uuid)', 'EXECUTE'))::text);
SELECT pg_temp.verifie(3, 'authenticated n''a plus DELETE sur support_tickets', 'false',
  has_table_privilege('authenticated', 'public.support_tickets', 'DELETE')::text);

-- ═══ 2. Qui lit quoi ═══════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-sup-u2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(10, 'membre 2 ne voit pas les tickets de membre 1', '0',
  (SELECT count(*)::text FROM public.support_tickets WHERE subject LIKE 't_ %'));
RESET ROLE;
SELECT pg_temp.moi('banc-sup-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(11, 'membre 1 voit ses 4 tickets', '4',
  (SELECT count(*)::text FROM public.support_tickets WHERE subject LIKE 't_ %'));
RESET ROLE;
SELECT pg_temp.moi('banc-sup-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(12, 'financeMod (admin sans droit support) ne voit rien', '0',
  (SELECT count(*)::text FROM public.support_tickets WHERE subject LIKE 't_ %'));
RESET ROLE;
SELECT pg_temp.moi('banc-sup-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(13, 'agent A voit les 4 tickets', '4',
  (SELECT count(*)::text FROM public.support_tickets WHERE subject LIKE 't_ %'));
RESET ROLE;

-- ═══ 3. Prise en charge et refus ═══════════════════════════════════════════
SELECT pg_temp.moi('banc-sup-u2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(20, 'ordinaire : prendre en charge REFUSÉ', '42501',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'in_progress')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sup-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(21, 'financeMod : prendre en charge REFUSÉ', '42501',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'in_progress')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sup-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(22, 'A : ticket introuvable → P0002', 'P0002',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000ff', 'in_progress')$q$);
SELECT pg_temp.essai(23, 'A : open → resolved ABSENT (55000)', '55000',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'resolved', 'x')$q$);
SELECT pg_temp.essai(24, 'A : répondre avant la prise en charge → 55000', '55000',
  $q$SELECT public.support_ticket_reply('00000000-0000-0000-0000-0000000000d1', 'Bonjour')$q$);
SELECT pg_temp.essai(25, 'A : prend t1', 'OK',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'in_progress')$q$);
SELECT pg_temp.essai(26, 'A : réponse vide → 22023', '22023',
  $q$SELECT public.support_ticket_reply('00000000-0000-0000-0000-0000000000d1', '   ')$q$);
SELECT pg_temp.essai(27, 'A : répond à t1', 'OK',
  $q$SELECT public.support_ticket_reply('00000000-0000-0000-0000-0000000000d1', 'Nous regardons votre dossier.')$q$);
SELECT pg_temp.essai(28, 'A : résoudre sans résolution → 22023', '22023',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'resolved', '  ')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sup-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(29, 'B : répondre sur le ticket de A REFUSÉ', '42501',
  $q$SELECT public.support_ticket_reply('00000000-0000-0000-0000-0000000000d1', 'Je me permets')$q$);
SELECT pg_temp.essai(30, 'B : résoudre le ticket de A REFUSÉ', '42501',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'resolved', 'fait')$q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sup-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(31, 'A : résout t1', 'OK',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'resolved', 'Compte rétabli.')$q$);
SELECT pg_temp.essai(32, 'A : résoudre une seconde fois → 55000', '55000',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'resolved', 'Compte rétabli.')$q$);
SELECT pg_temp.essai(33, 'A : répondre sur un ticket résolu → 55000', '55000',
  $q$SELECT public.support_ticket_reply('00000000-0000-0000-0000-0000000000d1', 'Encore')$q$);
SELECT pg_temp.essai(34, 'A : clôt t1 sans motif → 22023', '22023',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'closed', '')$q$);
SELECT pg_temp.essai(35, 'A : clôt t1', 'OK',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'closed', 'Confirmé par le membre.')$q$);
SELECT pg_temp.essai(36, 'A : rouvrir un ticket clos → 55000', '55000',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d1', 'in_progress', 'Retour')$q$);
RESET ROLE;

-- ═══ 4. Reprise, superAdmin, priorité, réouverture ═════════════════════════
SELECT pg_temp.moi('banc-sup-b');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(40, 'B : reprendre t2 sans motif → 22023', '22023',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d2', 'in_progress')$q$);
SELECT pg_temp.essai(41, 'B : reprend t2 avec motif', 'OK',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d2', 'in_progress', 'A est absent')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sup-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(42, 'A : répondre sur t2, désormais à B, REFUSÉ', '42501',
  $q$SELECT public.support_ticket_reply('00000000-0000-0000-0000-0000000000d2', 'Bonjour')$q$);
SELECT pg_temp.essai(43, 'A : priorité urgente sur t2', 'OK',
  $q$SELECT public.support_ticket_set_priority('00000000-0000-0000-0000-0000000000d2', 'urgent')$q$);
SELECT pg_temp.essai(44, 'A : priorité hors liste → 22023', '22023',
  $q$SELECT public.support_ticket_set_priority('00000000-0000-0000-0000-0000000000d2', 'immediate')$q$);
SELECT pg_temp.essai(45, 'A : priorité sur un ticket clos → 55000', '55000',
  $q$SELECT public.support_ticket_set_priority('00000000-0000-0000-0000-0000000000d1', 'high')$q$);
SELECT pg_temp.essai(46, 'A : rouvre t4 (résolu) avec motif', 'OK',
  $q$SELECT public.support_ticket_transition('00000000-0000-0000-0000-0000000000d4', 'in_progress', 'Le problème est revenu')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sup-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(47, 'superAdmin : répond sur t2 attribué à B', 'OK',
  $q$SELECT public.support_ticket_reply('00000000-0000-0000-0000-0000000000d2', 'Réponse du responsable.')$q$);
RESET ROLE;

SELECT pg_temp.verifie(48, 't2 : à B, priorité urgent', 'banc-sup-b/urgent',
  (SELECT assigned_to || '/' || priority FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000d2'));
SELECT pg_temp.verifie(49, 't1 : closed, résolution consignée', 'closed/Confirmé par le membre.',
  (SELECT status || '/' || resolution_note FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000d1'));

-- ═══ 5. Notes internes ═════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-sup-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'financeMod : note interne REFUSÉE', '42501',
  $q$SELECT public.support_ticket_note('00000000-0000-0000-0000-0000000000d2', 'curieux')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sup-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(51, 'A : note interne sur t2 (ticket d''un autre agent)', 'OK',
  $q$SELECT public.support_ticket_note('00000000-0000-0000-0000-0000000000d2', 'Le membre a déjà écrit en juin.')$q$);
SELECT pg_temp.essai(52, 'A : note vide → 22023', '22023',
  $q$SELECT public.support_ticket_note('00000000-0000-0000-0000-0000000000d2', ' ')$q$);
SELECT pg_temp.essai(53, 'A : INSERT direct dans les notes REFUSÉ', '42501',
  $q$INSERT INTO public.support_ticket_notes (ticket_id, author_id, body) VALUES ('00000000-0000-0000-0000-0000000000d2','banc-sup-a','x')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sup-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(54, 'le membre ne lit AUCUNE note interne', '0',
  (SELECT count(*)::text FROM public.support_ticket_notes));
RESET ROLE;
SELECT pg_temp.verifie(55, 'la note n''est pas dans messages de t2 (membre + réponse du superAdmin)', '2',
  (SELECT jsonb_array_length(messages)::text FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000d2'));

-- ═══ 6. Ce que le membre voit d'une réponse ════════════════════════════════
SELECT pg_temp.verifie(60, 'réponse : isFromSupport, nom neutre, non lue', 'true/Support Diaspo Niger/true',
  (SELECT (messages -> -1 ->> 'isFromSupport') || '/' || (messages -> -1 ->> 'senderName') || '/' || has_unread_support_messages::text
     FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000d1'));

-- ═══ 7. Le membre ne se donne aucun pouvoir ════════════════════════════════
SELECT pg_temp.moi('banc-sup-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(70, 'membre : se donner un responsable REFUSÉ', '42501',
  $q$UPDATE public.support_tickets SET assigned_to = 'banc-sup-u1' WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(71, 'membre : fixer sa priorité REFUSÉ', '42501',
  $q$UPDATE public.support_tickets SET priority = 'urgent' WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(72, 'membre : se mettre « en cours » REFUSÉ', '42501',
  $q$UPDATE public.support_tickets SET status = 'in_progress' WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(73, 'membre : écrire une réponse « du support » REFUSÉ', '42501',
  $q$UPDATE public.support_tickets SET messages = messages || '[{"id":"mx","senderId":"banc-sup-u1","senderName":"Support","isFromSupport":true,"content":"Votre remboursement est accordé","createdAt":"2026-10-18T00:00:00Z"}]'::jsonb WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(74, 'membre : écrire au nom d''un autre REFUSÉ', '42501',
  $q$UPDATE public.support_tickets SET messages = messages || '[{"id":"my","senderId":"banc-sup-u2","senderName":"U2","isFromSupport":false,"content":"x","createdAt":"2026-10-18T00:00:00Z"}]'::jsonb WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(75, 'membre : réécrire un message envoyé REFUSÉ', '42501',
  $q$UPDATE public.support_tickets SET messages = '[{"id":"m0","senderId":"banc-sup-u1","senderName":"U1","isFromSupport":false,"content":"Autre chose","createdAt":"2026-10-18T00:00:00Z"}]'::jsonb WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(76, 'membre : effacer l''historique REFUSÉ', '42501',
  $q$UPDATE public.support_tickets SET messages = '[]'::jsonb WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(77, 'membre : supprimer son ticket REFUSÉ', '42501',
  $q$DELETE FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(78, 'membre : créer un ticket déjà « attribué » REFUSÉ', '42501',
  $q$INSERT INTO public.support_tickets (user_id, subject, assigned_to) VALUES ('banc-sup-u1','x','banc-sup-a')$q$);
SELECT pg_temp.essai(79, 'membre : créer un ticket au nom d''un autre REFUSÉ', '42501',
  $q$INSERT INTO public.support_tickets (user_id, subject) VALUES ('banc-sup-u2','x')$q$);

-- Ce que l'application fait réellement doit continuer de passer.
SELECT pg_temp.essai(80, 'membre : crée un ticket avec les colonnes de l''application', 'OK',
  $q$INSERT INTO public.support_tickets (user_id, user_name, user_email, subject, description, category, status, related_transaction_id, messages, has_unread_user_messages, has_unread_support_messages)
     VALUES ('banc-sup-u1','Membre 1','sup-u1@banc.test','Transfert bloqué','Mon transfert est bloqué','transaction','open','tx-1',
             '[{"id":"msg_0","senderId":"banc-sup-u1","senderName":"Membre 1","isFromSupport":false,"content":"Mon transfert est bloqué","createdAt":"2026-10-18T00:00:00Z"}]'::jsonb, false, false)$q$);
SELECT pg_temp.essai(81, 'membre : ajoute un message en son nom', 'OK',
  $q$UPDATE public.support_tickets SET messages = messages || '[{"id":"msg_1","senderId":"banc-sup-u1","senderName":"U1","isFromSupport":false,"content":"Merci","createdAt":"2026-10-18T00:00:00Z"}]'::jsonb, has_unread_user_messages = true WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
SELECT pg_temp.essai(82, 'membre : lit les réponses (drapeau non lu)', 'OK',
  $q$UPDATE public.support_tickets SET has_unread_support_messages = false WHERE id = '00000000-0000-0000-0000-0000000000d1'$q$);
SELECT pg_temp.essai(83, 'membre : clôt lui-même son ticket', 'OK',
  $q$UPDATE public.support_tickets SET status = 'closed' WHERE id = '00000000-0000-0000-0000-0000000000d3'$q$);
RESET ROLE;

-- ═══ 8. Un administrateur n'écrit pas les tickets d'autrui à la main ═══════
SELECT pg_temp.moi('banc-sup-a');
SET LOCAL ROLE authenticated;
UPDATE public.support_tickets SET status = 'closed', assigned_to = 'banc-sup-a'
 WHERE id = '00000000-0000-0000-0000-0000000000d2';
RESET ROLE;
SELECT pg_temp.verifie(90, 'UPDATE direct par un admin : t2 inchangé (aucune policy d''écriture)', 'in_progress/banc-sup-b',
  (SELECT status || '/' || assigned_to FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000d2'));

-- ═══ 9. Lu / non lu ════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-sup-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(91, 'A : marque t3 comme lu', 'OK',
  $q$SELECT public.support_ticket_mark_read('00000000-0000-0000-0000-0000000000d3')$q$);
RESET ROLE;
SELECT pg_temp.moi('banc-sup-u2');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(92, 'ordinaire : marquer lu REFUSÉ', '42501',
  $q$SELECT public.support_ticket_mark_read('00000000-0000-0000-0000-0000000000d3')$q$);
RESET ROLE;
SELECT pg_temp.verifie(93, 't3 : messages du membre lus', 'false',
  (SELECT has_unread_user_messages::text FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000d3'));

-- ═══ 10. L'audit ═══════════════════════════════════════════════════════════
SELECT pg_temp.verifie(100, 't1 : 1 prise, 1 réponse, 1 résolution, 1 clôture', '1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'TICKET_ASSIGNED') || '/' ||
          count(*) FILTER (WHERE action = 'TICKET_REPLIED') || '/' ||
          count(*) FILTER (WHERE action = 'TICKET_RESOLVED') || '/' ||
          count(*) FILTER (WHERE action = 'TICKET_CLOSED')
     FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000d1'));
SELECT pg_temp.verifie(101, 't2 : reprise, priorité, réponse du superAdmin, note', '1/1/1/1',
  (SELECT count(*) FILTER (WHERE action = 'TICKET_REASSIGNED') || '/' ||
          count(*) FILTER (WHERE action = 'TICKET_PRIORITY_CHANGED') || '/' ||
          count(*) FILTER (WHERE action = 'TICKET_REPLIED') || '/' ||
          count(*) FILTER (WHERE action = 'TICKET_NOTE_ADDED')
     FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000d2'));
SELECT pg_temp.verifie(102, 't4 : une réouverture', '1',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id = '00000000-0000-0000-0000-0000000000d4' AND action = 'TICKET_REOPENED'));
SELECT pg_temp.verifie(103, 't3 : aucune ligne d''audit (refus et lecture n''en laissent pas)', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs WHERE target_id = '00000000-0000-0000-0000-0000000000d3'));
SELECT pg_temp.verifie(104, 'l''audit ne contient pas le texte des réponses', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id LIKE '00000000-0000-0000-0000-0000000000d%'
      AND details::text LIKE '%Nous regardons%'));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
