-- Banc : délais de service, escalade, modèles de réponse (migration 20261019210000).
--
--   supabase db query --linked -f tools/rls_tests/support_sla_escalade_modeles.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
-- AVANT `db push` : injecter la migration à la place de `-- @@CIBLE@@`
-- (python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>).
--
-- CE QU'IL VÉRIFIE. Les dangers sont : qu'un utilisateur s'escalade (ou se
-- désescalade) son propre ticket ; qu'un agent arrête des délais, ou lève une
-- escalade qu'il n'a pas à lever ; qu'un ticket sans cible soit déclaré « en
-- retard » ; qu'un modèle de réponse soit lisible ou écrivable par qui ne peut
-- pas répondre ; et que l'audit porte le texte d'un motif ou d'un modèle.

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
  ('banc-sla-super',   'Super',    'sla-super@banc.test',   true,  'superAdmin'),
  ('banc-sla-a',       'Agent A',  'sla-a@banc.test',       true,  'contentMod'),
  ('banc-sla-finance', 'Finance',  'sla-fin@banc.test',     true,  'financeMod'),
  ('banc-sla-u1',      'Membre 1', 'sla-u1@banc.test',      false, NULL);

-- d1 : compte/normal, créé il y a 100 h, jamais répondu.
-- d2 : compte/normal, créé à l'instant, déjà répondu.
-- d3 : « other » : aucune cible ne le concerne.
-- d4 : résolu.
INSERT INTO public.support_tickets (id, user_id, subject, status, category, priority, created_at, messages) VALUES
  ('00000000-0000-0000-0000-0000000000e1', 'banc-sla-u1', 'e1', 'open', 'account', 'normal',
   now() - interval '100 hours',
   '[{"id":"m0","senderId":"banc-sla-u1","isFromSupport":false,"content":"Bonjour","createdAt":"2026-10-01T00:00:00Z"}]'),
  ('00000000-0000-0000-0000-0000000000e2', 'banc-sla-u1', 'e2', 'in_progress', 'account', 'normal',
   now(),
   jsonb_build_array(
     jsonb_build_object('id','m0','senderId','banc-sla-u1','isFromSupport',false,'content','Bonjour',
                        'createdAt', to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')),
     jsonb_build_object('id','m1','senderId','banc-sla-a','isFromSupport',true,'content','Re',
                        'createdAt', to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))),
  ('00000000-0000-0000-0000-0000000000e3', 'banc-sla-u1', 'e3', 'open', 'other', 'normal', now() - interval '500 hours',
   '[{"id":"m0","senderId":"banc-sla-u1","isFromSupport":false,"content":"Bonjour","createdAt":"2026-10-01T00:00:00Z"}]'),
  ('00000000-0000-0000-0000-0000000000e4', 'banc-sla-u1', 'e4', 'resolved', 'account', 'normal', now() - interval '300 hours',
   '[{"id":"m0","senderId":"banc-sla-u1","isFromSupport":false,"content":"Bonjour","createdAt":"2026-10-01T00:00:00Z"}]');

-- ═══ 1. Catalogue et droits ════════════════════════════════════════════════
SELECT pg_temp.verifie(1, 'les 4 permissions sont au catalogue ; contentMod en porte 2 ; financeMod aucune', '4/2/0',
  (SELECT count(*) FROM public.admin_permissions WHERE key IN
     ('support.tickets.escalate','support.tickets.escalation.resolve','support.sla.manage','support.templates.manage')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'contentMod' AND permission IN
     ('support.tickets.escalate','support.templates.manage')) || '/' ||
  (SELECT count(*) FROM public.admin_role_permissions WHERE role = 'financeMod' AND permission IN
     ('support.tickets.escalate','support.tickets.escalation.resolve','support.sla.manage','support.templates.manage')));
SELECT pg_temp.verifie(2, 'escalation.resolve et sla.manage ne vont à aucun rôle (superAdmin seul)', '0',
  (SELECT count(*)::text FROM public.admin_role_permissions
    WHERE permission IN ('support.tickets.escalation.resolve','support.sla.manage')));
SELECT pg_temp.verifie(3, 'anon n''exécute aucune des six RPC', 'false',
  (has_function_privilege('anon', 'public.support_sla_set(text,text,integer,integer)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_sla_status()', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_ticket_escalate(uuid,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_ticket_escalation_resolve(uuid)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_template_save(uuid,text,text,text)', 'EXECUTE')
   OR has_function_privilege('anon', 'public.support_template_delete(uuid)', 'EXECUTE'))::text);
SELECT pg_temp.verifie(4, 'la table des délais naît vide : aucune durée inventée', '0',
  (SELECT count(*)::text FROM public.support_sla_targets));
SELECT pg_temp.verifie(5, 'authenticated n''écrit ni les délais ni les modèles directement', 'false',
  (has_table_privilege('authenticated', 'public.support_sla_targets', 'INSERT')
   OR has_table_privilege('authenticated', 'public.support_sla_targets', 'UPDATE')
   OR has_table_privilege('authenticated', 'public.support_reply_templates', 'INSERT')
   OR has_table_privilege('authenticated', 'public.support_reply_templates', 'UPDATE')
   OR has_table_privilege('authenticated', 'public.support_reply_templates', 'DELETE'))::text);

-- ═══ 2. Délais ═════════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-sla-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(10, 'contentMod ne peut pas arrêter un délai', '42501',
  $q$ SELECT public.support_sla_set('account','normal',24,72) $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sla-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(11, 'catégorie inconnue refusée', '22023',
  $q$ SELECT public.support_sla_set('nimporte','normal',24,72) $q$);
SELECT pg_temp.essai(12, 'priorité inconnue refusée', '22023',
  $q$ SELECT public.support_sla_set('account','critique',24,72) $q$);
SELECT pg_temp.essai(13, 'première réponse après la résolution refusée', '22023',
  $q$ SELECT public.support_sla_set('account','normal',100,72) $q$);
SELECT pg_temp.essai(14, 'durée hors bornes refusée', '22023',
  $q$ SELECT public.support_sla_set('account','normal',0,72) $q$);
SELECT pg_temp.essai(15, 'le superAdmin arrête account/normal : 24 h / 72 h', 'OK',
  $q$ SELECT public.support_sla_set('account','normal',24,72) $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sla-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(16, 'contentMod lit la cible', '1',
  (SELECT count(*)::text FROM public.support_sla_targets));
SELECT pg_temp.verifie(17, 'seuls les tickets avec une cible ont une échéance : e1 et e2, ni e3 (autre catégorie) ni e4 (résolu)', '2',
  (SELECT count(*)::text FROM public.support_sla_status()));
SELECT pg_temp.verifie(18, 'e1 (100 h, sans réponse) : en retard sur les deux délais', 'true/true',
  (SELECT first_response_late || '/' || resolution_late FROM public.support_sla_status()
    WHERE ticket_id = '00000000-0000-0000-0000-0000000000e1'));
SELECT pg_temp.verifie(19, 'e2 (à l''instant, déjà répondu) : dans les délais', 'false/false',
  (SELECT first_response_late || '/' || resolution_late FROM public.support_sla_status()
    WHERE ticket_id = '00000000-0000-0000-0000-0000000000e2'));
SELECT pg_temp.verifie(20, 'e2 : l''heure de première réponse est relevée', 'true',
  (SELECT (first_response_at IS NOT NULL)::text FROM public.support_sla_status()
    WHERE ticket_id = '00000000-0000-0000-0000-0000000000e2'));
RESET ROLE;

SELECT pg_temp.moi('banc-sla-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(21, 'financeMod ne lit pas les échéances', '42501',
  $q$ SELECT * FROM public.support_sla_status() $q$);
SELECT pg_temp.verifie(22, 'financeMod ne lit pas les cibles', '0',
  (SELECT count(*)::text FROM public.support_sla_targets));
RESET ROLE;

SELECT pg_temp.moi('banc-sla-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(23, 'un membre n''appelle pas les échéances', '42501',
  $q$ SELECT * FROM public.support_sla_status() $q$);
SELECT pg_temp.verifie(24, 'un membre ne lit pas les cibles', '0',
  (SELECT count(*)::text FROM public.support_sla_targets));
RESET ROLE;

SELECT pg_temp.moi('banc-sla-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(25, 'les deux durées à NULL retirent la cible', 'OK',
  $q$ SELECT public.support_sla_set('account','normal',NULL,NULL) $q$);
SELECT pg_temp.verifie(26, 'sans cible, plus aucune échéance, donc aucun retard', '0',
  (SELECT count(*)::text FROM public.support_sla_status()));
RESET ROLE;

-- ═══ 3. Escalade ═══════════════════════════════════════════════════════════
SELECT pg_temp.moi('banc-sla-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(30, 'financeMod ne peut pas escalader', '42501',
  $q$ SELECT public.support_ticket_escalate('00000000-0000-0000-0000-0000000000e1','hors de mon périmètre') $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sla-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(31, 'un membre ne peut pas escalader son ticket', '42501',
  $q$ SELECT public.support_ticket_escalate('00000000-0000-0000-0000-0000000000e1','hors de mon périmètre') $q$);
SELECT pg_temp.essai(32, 'un membre ne s''escalade pas par UPDATE direct', '42501',
  $q$ UPDATE public.support_tickets SET escalated_at = now(), escalated_by = 'banc-sla-u1'
       WHERE id = '00000000-0000-0000-0000-0000000000e1' $q$);
SELECT pg_temp.essai(33, 'un membre ne crée pas un ticket déjà escaladé', '42501',
  $q$ INSERT INTO public.support_tickets (user_id, subject, escalated_at, escalation_reason)
       VALUES ('banc-sla-u1','x', now(), 'y') $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sla-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(34, 'motif trop court refusé', '22023',
  $q$ SELECT public.support_ticket_escalate('00000000-0000-0000-0000-0000000000e1','ok') $q$);
SELECT pg_temp.essai(35, 'ticket inconnu', 'P0002',
  $q$ SELECT public.support_ticket_escalate('00000000-0000-0000-0000-0000000000ff','hors de mon périmètre') $q$);
SELECT pg_temp.essai(36, 'ticket résolu : on n''escalade pas', '55000',
  $q$ SELECT public.support_ticket_escalate('00000000-0000-0000-0000-0000000000e4','hors de mon périmètre') $q$);
SELECT pg_temp.essai(37, 'contentMod escalade e1', 'OK',
  $q$ SELECT public.support_ticket_escalate('00000000-0000-0000-0000-0000000000e1','Litige financier hors de mon périmètre') $q$);
SELECT pg_temp.essai(38, 'déjà escaladé', '55000',
  $q$ SELECT public.support_ticket_escalate('00000000-0000-0000-0000-0000000000e1','Litige financier hors de mon périmètre') $q$);
SELECT pg_temp.essai(39, 'contentMod ne lève pas l''escalade', '42501',
  $q$ SELECT public.support_ticket_escalation_resolve('00000000-0000-0000-0000-0000000000e1') $q$);
SELECT pg_temp.verifie(40, 'le ticket porte l''escalade : par A, avec motif', 'banc-sla-a/true',
  (SELECT escalated_by || '/' || (escalation_reason IS NOT NULL) FROM public.support_tickets
    WHERE id = '00000000-0000-0000-0000-0000000000e1'));
RESET ROLE;

SELECT pg_temp.moi('banc-sla-super');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(41, 'pas escaladé : rien à lever', '55000',
  $q$ SELECT public.support_ticket_escalation_resolve('00000000-0000-0000-0000-0000000000e2') $q$);
SELECT pg_temp.essai(42, 'le superAdmin lève l''escalade de e1', 'OK',
  $q$ SELECT public.support_ticket_escalation_resolve('00000000-0000-0000-0000-0000000000e1') $q$);
SELECT pg_temp.verifie(43, 'après levée, les trois colonnes sont vides', 'true',
  (SELECT (escalated_at IS NULL AND escalated_by IS NULL AND escalation_reason IS NULL)::text
     FROM public.support_tickets WHERE id = '00000000-0000-0000-0000-0000000000e1'));
RESET ROLE;

-- ═══ 4. Modèles de réponse ═════════════════════════════════════════════════
SELECT pg_temp.moi('banc-sla-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(50, 'financeMod n''écrit pas de modèle', '42501',
  $q$ SELECT public.support_template_save(NULL,'Titre','Texte secret du modèle','account') $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sla-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(51, 'catégorie invalide refusée', '22023',
  $q$ SELECT public.support_template_save(NULL,'Titre','Texte secret du modèle','nimporte') $q$);
SELECT pg_temp.essai(52, 'titre vide refusé', '22023',
  $q$ SELECT public.support_template_save(NULL,'  ','Texte secret du modèle','account') $q$);
SELECT pg_temp.essai(53, 'modèle inconnu à modifier', 'P0002',
  $q$ SELECT public.support_template_save('00000000-0000-0000-0000-0000000000ff','Titre','Texte','account') $q$);
SELECT pg_temp.essai(54, 'contentMod crée un modèle', 'OK',
  $q$ SELECT public.support_template_save(NULL,'Accusé de réception','Texte secret du modèle','account') $q$);
SELECT pg_temp.verifie(55, 'contentMod le relit', '1',
  (SELECT count(*)::text FROM public.support_reply_templates));
SELECT pg_temp.essai(56, 'contentMod ne supprime pas un modèle inconnu', 'P0002',
  $q$ SELECT public.support_template_delete('00000000-0000-0000-0000-0000000000ff') $q$);
SELECT pg_temp.essai(57, 'écriture directe dans la table refusée', '42501',
  $q$ INSERT INTO public.support_reply_templates (title, body, created_by) VALUES ('x','y','banc-sla-a') $q$);
RESET ROLE;

SELECT pg_temp.moi('banc-sla-finance');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(58, 'financeMod ne lit aucun modèle', '0',
  (SELECT count(*)::text FROM public.support_reply_templates));
RESET ROLE;

SELECT pg_temp.moi('banc-sla-u1');
SET LOCAL ROLE authenticated;
SELECT pg_temp.verifie(59, 'un membre ne lit aucun modèle', '0',
  (SELECT count(*)::text FROM public.support_reply_templates));
RESET ROLE;

SELECT pg_temp.moi('banc-sla-a');
SET LOCAL ROLE authenticated;
SELECT pg_temp.essai(60, 'contentMod supprime son modèle', 'OK',
  $q$ SELECT public.support_template_delete((SELECT id FROM public.support_reply_templates LIMIT 1)) $q$);
SELECT pg_temp.verifie(61, 'plus aucun modèle', '0',
  (SELECT count(*)::text FROM public.support_reply_templates));
RESET ROLE;

-- ═══ 5. Audit ══════════════════════════════════════════════════════════════
SELECT pg_temp.verifie(70, 'escalade + levée + délai posé/retiré + modèle créé/supprimé, tous tracés', '1/1/2/1/1',
  (SELECT count(*) FILTER (WHERE action = 'TICKET_ESCALATED') || '/' ||
          count(*) FILTER (WHERE action = 'TICKET_ESCALATION_RESOLVED') || '/' ||
          count(*) FILTER (WHERE action = 'SUPPORT_SLA_SET') || '/' ||
          count(*) FILTER (WHERE action = 'SUPPORT_TEMPLATE_SAVED') || '/' ||
          count(*) FILTER (WHERE action = 'SUPPORT_TEMPLATE_DELETED')
     FROM public.admin_audit_logs
    WHERE created_at >= now() - interval '1 minute'
      AND action IN ('TICKET_ESCALATED','TICKET_ESCALATION_RESOLVED','SUPPORT_SLA_SET',
                     'SUPPORT_TEMPLATE_SAVED','SUPPORT_TEMPLATE_DELETED')));
SELECT pg_temp.verifie(71, 'l''audit ne porte ni le motif d''escalade ni le texte d''un modèle', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE details::text LIKE '%Litige financier%' OR details::text LIKE '%Texte secret%'));
SELECT pg_temp.verifie(72, 'aucun refus n''a laissé de ligne d''audit sur e3/e4', '0',
  (SELECT count(*)::text FROM public.admin_audit_logs
    WHERE target_id IN ('00000000-0000-0000-0000-0000000000e3','00000000-0000-0000-0000-0000000000e4')));

-- ═══ Rapport ═══════════════════════════════════════════════════════════════
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
