-- Banc : « Contacter un membre » (migration 20261106090000). NON LANCÉ à ce jour.
--
--   supabase db query --linked -f tools/rls_tests/contacter_un_membre.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT application : remplacer la ligne seule `-- @@CIBLE@@` par la migration (répétition,
-- python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>). APRÈS, lancé tel quel, il prouve l'état vivant.
-- Prérequis : les migrations 20261029090000 (rôles limités) et 20261029100000 sont appliquées.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role) VALUES
  ('banc-ct-super',   'Super',   'ct-super@banc.test',   true,  'superAdmin'),
  ('banc-ct-content', 'Content', 'ct-content@banc.test', true,  'contentMod'),
  ('banc-ct-support', 'Support', 'ct-support@banc.test', true,  'supportAgent'),
  ('banc-ct-audit',   'Audit',   'ct-audit@banc.test',   true,  'auditor'),
  ('banc-ct-biz',     'Biz',     'ct-biz@banc.test',     true,  'businessMod'),
  ('banc-ct-m1',      'Membre1', 'ct-m1@banc.test',      false, NULL),
  ('banc-ct-m2',      'Membre2', 'ct-m2@banc.test',      false, NULL),
  ('banc-ct-m3',      'Membre3', 'ct-m3@banc.test',      false, NULL);

-- ═══ 1. Droits : contentMod et superAdmin contactent ; les autres rôles non ═══
DO $$
DECLARE
  cas record; n int := 10; res text;
BEGIN
  FOR cas IN
    SELECT * FROM (VALUES
      ('banc-ct-content', 'banc-ct-m1', 'ok'),
      ('banc-ct-super',   'banc-ct-m2', 'ok'),
      ('banc-ct-support', 'banc-ct-m3', '42501'),
      ('banc-ct-audit',   'banc-ct-m3', '42501'),
      ('banc-ct-biz',     'banc-ct-m3', '42501')
    ) AS t(uid, membre, attendu)
  LOOP
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
      'app_metadata', jsonb_build_object('firebase_uid', cas.uid))::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN
      PERFORM public.member_admin_contact(cas.membre, 'info_request', 'Sujet du banc', 'Message du banc, assez long.');
      res := 'ok';
    EXCEPTION WHEN OTHERS THEN
      res := SQLSTATE;
    END;
    RESET ROLE;
    INSERT INTO resultat VALUES (n, cas.uid || ' · contact', cas.attendu, res,
      CASE WHEN res = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
END $$;

-- ═══ 2. Validations (en tant que contentMod) ═══
DO $$
DECLARE
  cas record; n int := 20; res text;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-ct-content'))::text, true);
  SET LOCAL ROLE authenticated;
  FOR cas IN
    SELECT * FROM (VALUES
      ('motif inconnu',          'banc-ct-m3',      'inconnu',      'Sujet du banc', 'Message du banc, assez long.', '22023'),
      ('sujet trop court',       'banc-ct-m3',      'other',        'abc',           'Message du banc, assez long.', '22023'),
      ('message trop court',     'banc-ct-m3',      'other',        'Sujet du banc', 'court',                        '22023'),
      ('soi-même',               'banc-ct-content', 'other',        'Sujet du banc', 'Message du banc, assez long.', '42501'),
      ('membre introuvable',     'banc-ct-absent',  'other',        'Sujet du banc', 'Message du banc, assez long.', 'P0002'),
      ('compte administrateur',  'banc-ct-audit',   'other',        'Sujet du banc', 'Message du banc, assez long.', '42501')
    ) AS t(cas_, membre, motif, sujet, corps, attendu)
  LOOP
    BEGIN
      PERFORM public.member_admin_contact(cas.membre, cas.motif, cas.sujet, cas.corps);
      res := 'ok';
    EXCEPTION WHEN OTHERS THEN
      res := SQLSTATE;
    END;
    INSERT INTO resultat VALUES (n, 'validation : ' || cas.cas_, cas.attendu, res,
      CASE WHEN res = cas.attendu THEN 'OK' ELSE 'ÉCHEC' END);
    n := n + 1;
  END LOOP;
  RESET ROLE;
END $$;

-- ═══ 3. Plafond de 3 contacts par membre et par 24 h ═══
DO $$
DECLARE
  i int; res text;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-ct-super'))::text, true);
  SET LOCAL ROLE authenticated;
  -- banc-ct-m2 a déjà reçu 1 message (cas 11) : deux de plus passent, le quatrième est refusé.
  FOR i IN 1..3 LOOP
    BEGIN
      PERFORM public.member_admin_contact('banc-ct-m2', 'other', 'Sujet du banc ' || i, 'Message du banc numéro ' || i || ', long.');
      res := 'ok';
    EXCEPTION WHEN OTHERS THEN
      res := SQLSTATE;
    END;
    INSERT INTO resultat VALUES (30 + i, 'plafond : contact n° ' || (i + 1) || ' du même membre',
      CASE WHEN i < 3 THEN 'ok' ELSE '55000' END, res,
      CASE WHEN res = CASE WHEN i < 3 THEN 'ok' ELSE '55000' END THEN 'OK' ELSE 'ÉCHEC' END);
  END LOOP;
  RESET ROLE;
END $$;

-- ═══ 4. Ce que le contact produit : ticket lisible par le membre, notification neutre, audit sans texte ═══
INSERT INTO resultat
SELECT 40, 'ticket ouvert au nom du membre, en cours, non lu, avec le premier message du support', '1/in_progress/true/true',
       count(*) || '/' || coalesce(min(status), '-') || '/' || coalesce(bool_and(has_unread_support_messages), false)
         || '/' || coalesce(bool_and((messages -> 0 ->> 'isFromSupport')::boolean), false),
       CASE WHEN count(*) = 1 AND min(status) = 'in_progress' AND bool_and(has_unread_support_messages)
             AND bool_and((messages -> 0 ->> 'isFromSupport')::boolean) THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.support_tickets WHERE user_id = 'banc-ct-m1' AND opened_by_admin = 'banc-ct-content';

INSERT INTO resultat
SELECT 41, 'notification : titre serveur, corps neutre (ne reprend pas le message)', 'neutre',
       CASE WHEN body NOT LIKE '%Message du banc%' AND title = 'Message de l''équipe Diaspo Niger' THEN 'neutre' ELSE 'fuite' END,
       CASE WHEN body NOT LIKE '%Message du banc%' AND title = 'Message de l''équipe Diaspo Niger' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications WHERE user_id = 'banc-ct-m1' ORDER BY created_at DESC LIMIT 1;

INSERT INTO resultat
SELECT 42, 'audit : MEMBER_CONTACTED avec le motif, sans le texte du message', '1/true',
       count(*) || '/' || coalesce(bool_and(details::text NOT LIKE '%Message du banc%' AND reason_code = 'info_request'), false),
       CASE WHEN count(*) = 1 AND bool_and(details::text NOT LIKE '%Message du banc%' AND reason_code = 'info_request')
            THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_audit_logs WHERE action = 'MEMBER_CONTACTED' AND target_id = 'banc-ct-m1';

DO $$
DECLARE v int; w int;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-ct-m1'))::text, true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO v FROM public.support_tickets WHERE user_id = 'banc-ct-m1';
  SELECT count(*) INTO w FROM public.support_tickets WHERE user_id = 'banc-ct-m2';
  RESET ROLE;
  INSERT INTO resultat VALUES (43, 'le membre lit SON ticket et pas celui d''un autre', '1/0', v || '/' || w,
    CASE WHEN v = 1 AND w = 0 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 5. La permission existe et n'est portée que par contentMod (superAdmin : tout le catalogue) ═══
INSERT INTO resultat
SELECT 50, 'community.members.contact : portée par contentMod seul', 'contentMod',
       coalesce(string_agg(role, ',' ORDER BY role), '(aucun)'),
       CASE WHEN string_agg(role, ',' ORDER BY role) = 'contentMod' THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_role_permissions WHERE permission = 'community.members.contact';

-- ═══ Rapport ═══
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
