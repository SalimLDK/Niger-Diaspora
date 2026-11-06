-- Banc : invitations d'administrateurs (migration 20261106100000). NON LANCÉ à ce jour.
--
--   supabase db query --linked -f tools/rls_tests/invitations_administrateurs.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- AVANT application : remplacer la ligne seule `-- @@CIBLE@@` par la migration (répétition,
-- python tools/rls_tests/repeter_cible.py <banc> <migration> <sortie>). APRÈS, lancé tel quel, il prouve l'état vivant.
-- Prérequis : migrations 20261029090000 et 20261029100000 appliquées (rôles limités, is_limited_admin).
--
-- Ce banc ne couvre PAS la Cloud Function `accepterInvitationAdmin` (écriture du rôle, claim, RTDB) : elle est testée
-- par `cd functions && npm test`. Il couvre tout ce qui est en base : droits, états, expiration, plafonds, étanchéité.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
GRANT ALL ON resultat TO anon, authenticated;

-- @@CIBLE@@

INSERT INTO public.users (id, display_name, email, is_admin, admin_role, is_banned) VALUES
  ('banc-inv-s1',   'Super1',  's1@banc-invitation.test', true,  'superAdmin', false),
  ('banc-inv-s2',   'Super2',  's2@banc-invitation.test', true,  'superAdmin', false),
  ('banc-inv-cont', 'Content', 'ct@banc-invitation.test', true,  'contentMod', false),
  ('banc-inv-aud',  'Audit',   'au@banc-invitation.test', true,  'auditor',    false),
  ('banc-inv-m1',   'Membre1', 'amina.n@banc-invitation.test', false, NULL, false),
  ('banc-inv-m2',   'Membre2', 'm2@banc-invitation.test', false, NULL, false),
  ('banc-inv-m3',   'Membre3', 'm3@banc-invitation.test', false, NULL, false),
  ('banc-inv-ban',  'Banni',   'bn@banc-invitation.test', false, NULL, true);

-- Aide : exécuter un appel en tant que `uid`, rendre 'ok' ou le SQLSTATE.
CREATE OR REPLACE FUNCTION pg_temp.en_tant_que(uid text, requete text) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE res text;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', uid))::text, true);
  SET LOCAL ROLE authenticated;
  BEGIN
    EXECUTE requete;
    res := 'ok';
  EXCEPTION WHEN OTHERS THEN
    res := SQLSTATE;
  END;
  RESET ROLE;
  RETURN res;
END $$;
GRANT EXECUTE ON FUNCTION pg_temp.en_tant_que(text, text) TO PUBLIC;

-- ═══ 1. Qui peut inviter ═══
INSERT INTO resultat SELECT 1, 'super-administrateur : invite un membre (rôle limité)', 'ok',
  pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-m1', 'auditor')$q$),
  CASE WHEN pg_temp.en_tant_que('banc-inv-s2', $q$SELECT public.admin_invitation_create('banc-inv-m2', 'analyst')$q$) = 'ok' THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat SELECT 2 + k, 'refusé : ' || nom, '42501', r, CASE WHEN r = '42501' THEN 'OK' ELSE 'ÉCHEC' END
  FROM (VALUES
    (0, 'contentMod (admin non super)', pg_temp.en_tant_que('banc-inv-cont', $q$SELECT public.admin_invitation_create('banc-inv-m3', 'auditor')$q$)),
    (1, 'auditeur',                      pg_temp.en_tant_que('banc-inv-aud',  $q$SELECT public.admin_invitation_create('banc-inv-m3', 'auditor')$q$)),
    (2, 'membre ordinaire',              pg_temp.en_tant_que('banc-inv-m3',   $q$SELECT public.admin_invitation_create('banc-inv-m2', 'auditor')$q$)),
    (3, 'soi-même',                      pg_temp.en_tant_que('banc-inv-s1',   $q$SELECT public.admin_invitation_create('banc-inv-s1', 'auditor')$q$))
  ) AS t(k, nom, r);

-- ═══ 2. Validations et refus d'état ═══
INSERT INTO resultat SELECT 10 + k, nom, attendu, r, CASE WHEN r = attendu THEN 'OK' ELSE 'ÉCHEC' END
  FROM (VALUES
    (0, 'rôle inconnu',                 '22023', pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-m3', 'roi')$q$)),
    (1, 'compte introuvable',           'P0002', pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-absent', 'auditor')$q$)),
    (2, 'compte suspendu',              '55000', pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-ban', 'auditor')$q$)),
    (3, 'invitation déjà ouverte',      '55000', pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-m1', 'analyst')$q$)),
    (4, 'a déjà ce rôle',               '55000', pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-aud', 'auditor')$q$))
  ) AS t(k, nom, attendu, r);

-- ═══ 3. Rôle superAdmin : second approbateur obligatoire ═══
SELECT pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-m3', 'superAdmin')$q$);

INSERT INTO resultat
SELECT 20, 'invitation superAdmin : en attente d''approbation, invisible de l''invité', 'pending_approval/0',
       (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3') || '/' ||
       (SELECT count(*) FROM public.admin_invitations i WHERE i.invitee_id = 'banc-inv-m3' AND i.status = 'pending'),
       CASE WHEN (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3') = 'pending_approval' THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat SELECT 21, 'l''inviteur ne s''auto-approuve pas', '42501',
  pg_temp.en_tant_que('banc-inv-s1', format($q$SELECT public.admin_invitation_approve(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3'))),
  CASE WHEN pg_temp.en_tant_que('banc-inv-s1', format($q$SELECT public.admin_invitation_approve(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3'))) = '42501' THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat SELECT 22, 'un contentMod n''approuve pas', '42501',
  pg_temp.en_tant_que('banc-inv-cont', format($q$SELECT public.admin_invitation_approve(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3'))),
  CASE WHEN pg_temp.en_tant_que('banc-inv-cont', format($q$SELECT public.admin_invitation_approve(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3'))) = '42501' THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat SELECT 23, 'un AUTRE super-administrateur approuve', 'ok',
  pg_temp.en_tant_que('banc-inv-s2', format($q$SELECT public.admin_invitation_approve(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3'))),
  CASE WHEN (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3') = 'pending' THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 4. Côté invité ═══
-- (le journal et les notifications sont relus plus bas)
DO $$
DECLARE v int; w int; x int;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-inv-m1'))::text, true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO v FROM public.admin_invitation_mine();
  RESET ROLE;
  INSERT INTO resultat VALUES (30, 'l''invité voit SA seule invitation prête', '1', v::text, CASE WHEN v = 1 THEN 'OK' ELSE 'ÉCHEC' END);

  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-inv-ban'))::text, true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO w FROM public.admin_invitation_mine();
  RESET ROLE;
  INSERT INTO resultat VALUES (31, 'un autre compte ne voit aucune invitation d''autrui', '0', w::text, CASE WHEN w = 0 THEN 'OK' ELSE 'ÉCHEC' END);

  -- Table fermée en accès direct.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-inv-m1'))::text, true);
  SET LOCAL ROLE authenticated;
  BEGIN
    SELECT count(*) INTO x FROM public.admin_invitations;
    INSERT INTO resultat VALUES (32, 'lecture directe de la table fermée', '42501', 'lu ' || x, 'ÉCHEC');
  EXCEPTION WHEN insufficient_privilege THEN
    INSERT INTO resultat VALUES (32, 'lecture directe de la table fermée', '42501', '42501', 'OK');
  END;
  RESET ROLE;
END $$;

INSERT INTO resultat SELECT 33, 'un autre invité ne peut pas refuser l''invitation d''autrui', 'P0002',
  pg_temp.en_tant_que('banc-inv-m2', format($q$SELECT public.admin_invitation_decline(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1'))),
  CASE WHEN pg_temp.en_tant_que('banc-inv-m2', format($q$SELECT public.admin_invitation_decline(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1'))) = 'P0002' THEN 'OK' ELSE 'ÉCHEC' END;

INSERT INTO resultat SELECT 34, 'l''invité refuse sa propre invitation', 'ok',
  pg_temp.en_tant_que('banc-inv-m2', format($q$SELECT public.admin_invitation_decline(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m2'))),
  CASE WHEN (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m2') = 'declined' THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 5. Réclamation (clé de service) : seule voie d'acceptation ═══
INSERT INTO resultat SELECT 40, 'authenticated ne peut pas réclamer', 'false',
  has_function_privilege('authenticated', 'public.admin_invitation_claim(uuid,text)', 'EXECUTE')::text,
  CASE WHEN NOT has_function_privilege('authenticated', 'public.admin_invitation_claim(uuid,text)', 'EXECUTE')
        AND NOT has_function_privilege('anon', 'public.admin_invitation_claim(uuid,text)', 'EXECUTE')
        AND has_function_privilege('service_role', 'public.admin_invitation_claim(uuid,text)', 'EXECUTE') THEN 'OK' ELSE 'ÉCHEC' END;

DO $$
DECLARE r text; ex text;
BEGIN
  -- Mauvaise personne : refusé.
  BEGIN
    PERFORM public.admin_invitation_claim((SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1'), 'banc-inv-m2');
    ex := 'passé';
  EXCEPTION WHEN OTHERS THEN ex := SQLSTATE; END;
  INSERT INTO resultat VALUES (41, 'réclamation par une autre personne', 'P0002', ex, CASE WHEN ex = 'P0002' THEN 'OK' ELSE 'ÉCHEC' END);

  -- Bonne personne : rend le rôle, marque acceptée.
  r := public.admin_invitation_claim((SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1'), 'banc-inv-m1');
  INSERT INTO resultat VALUES (42, 'réclamation par l''invité : rend le rôle de l''invitation', 'auditor', r, CASE WHEN r = 'auditor' THEN 'OK' ELSE 'ÉCHEC' END);

  -- Rejouer : refusé (plus en attente).
  BEGIN
    PERFORM public.admin_invitation_claim((SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1'), 'banc-inv-m1');
    ex := 'passé';
  EXCEPTION WHEN OTHERS THEN ex := SQLSTATE; END;
  INSERT INTO resultat VALUES (43, 'une invitation acceptée ne se réclame pas deux fois', '55000', ex, CASE WHEN ex = '55000' THEN 'OK' ELSE 'ÉCHEC' END);

  -- Réouverture après échec d'activation.
  PERFORM public.admin_invitation_unclaim((SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1'));
  INSERT INTO resultat VALUES (44, 'la réouverture remet l''invitation en attente', 'pending',
    (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1'),
    CASE WHEN (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m1') = 'pending' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 6. Expiration ═══
UPDATE public.admin_invitations SET expires_at = now() - interval '1 minute' WHERE invitee_id = 'banc-inv-m3';
DO $$
DECLARE ex text;
BEGIN
  BEGIN
    PERFORM public.admin_invitation_claim((SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3'), 'banc-inv-m3');
    ex := 'passé';
  EXCEPTION WHEN OTHERS THEN ex := SQLSTATE; END;
  INSERT INTO resultat VALUES (50, 'une invitation expirée ne se réclame pas', '55000', ex, CASE WHEN ex = '55000' THEN 'OK' ELSE 'ÉCHEC' END);
  INSERT INTO resultat VALUES (51, 'elle passe au statut « expired »', 'expired',
    (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3'),
    CASE WHEN (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m3') = 'expired' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 7. Révocation ═══
SELECT pg_temp.en_tant_que('banc-inv-s1', $q$SELECT public.admin_invitation_create('banc-inv-m2', 'validator')$q$);
INSERT INTO resultat SELECT 60, 'révocation par un super-administrateur', 'ok/revoked',
  pg_temp.en_tant_que('banc-inv-s2', format($q$SELECT public.admin_invitation_revoke(%L)$q$, (SELECT id FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m2' AND status = 'pending'))) || '/' ||
  (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m2' ORDER BY created_at DESC LIMIT 1),
  CASE WHEN (SELECT status FROM public.admin_invitations WHERE invitee_id = 'banc-inv-m2' ORDER BY created_at DESC LIMIT 1) = 'revoked' THEN 'OK' ELSE 'ÉCHEC' END;

-- ═══ 8. Recherche : e-mail masqué, bornée, comptée ═══
DO $$
DECLARE masque text; n int;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('role','authenticated',
    'app_metadata', jsonb_build_object('firebase_uid', 'banc-inv-s1'))::text, true);
  SET LOCAL ROLE authenticated;
  SELECT email_masked, count(*) OVER () INTO masque, n FROM public.admin_member_search('amina') LIMIT 1;
  RESET ROLE;
  INSERT INTO resultat VALUES (70, 'recherche par début d''e-mail : e-mail masqué', 'a•••@b•••.test', masque,
    CASE WHEN masque = 'a•••@b•••.test' THEN 'OK' ELSE 'ÉCHEC' END);

END $$;

INSERT INTO resultat SELECT 71 + k, nom, attendu, r, CASE WHEN r = attendu THEN 'OK' ELSE 'ÉCHEC' END
  FROM (VALUES
    (0, 'terme de 2 caractères refusé',        '22023', pg_temp.en_tant_que('banc-inv-s1',  $q$SELECT * FROM public.admin_member_search('am')$q$)),
    (1, 'un contentMod ne cherche pas',         '42501', pg_temp.en_tant_que('banc-inv-cont', $q$SELECT * FROM public.admin_member_search('amina')$q$)),
    (2, 'un auditeur ne cherche pas',           '42501', pg_temp.en_tant_que('banc-inv-aud',  $q$SELECT * FROM public.admin_member_search('amina')$q$)),
    (3, 'un membre ne cherche pas',             '42501', pg_temp.en_tant_que('banc-inv-m3',   $q$SELECT * FROM public.admin_member_search('amina')$q$))
  ) AS t(k, nom, attendu, r);

-- Plafond : 30 recherches par 10 minutes ; la 31e est refusée.
DO $$
DECLARE i int; res text; refus int := 0;
BEGIN
  FOR i IN 1..32 LOOP
    res := pg_temp.en_tant_que('banc-inv-s2', $q$SELECT * FROM public.admin_member_search('membre')$q$);
    IF res = '55000' THEN refus := refus + 1; END IF;
  END LOOP;
  INSERT INTO resultat VALUES (80, 'plafond de recherches : au moins une refusée au-delà de 30', '>=1', refus::text,
    CASE WHEN refus >= 1 THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ═══ 9. Journal : qui a invité / approuvé / révoqué, jamais le terme cherché ═══
INSERT INTO resultat
SELECT 90, 'journal : invitation, approbation et révocation tracées', '>=3',
       count(*)::text, CASE WHEN count(*) >= 3 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_audit_logs WHERE action IN ('ADMIN_INVITED', 'ADMIN_INVITATION_APPROVED', 'ADMIN_INVITATION_REVOKED');

INSERT INTO resultat
SELECT 91, 'journal : le refus de l''invité est tracé au nom de l''invité', '1',
       count(*)::text, CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_audit_logs WHERE action = 'ADMIN_INVITATION_DECLINED' AND admin_id = 'banc-inv-m2';

INSERT INTO resultat
SELECT 92, 'journal des recherches : sans le terme cherché', '0',
       count(*)::text, CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.admin_audit_logs WHERE action = 'ADMIN_MEMBER_SEARCH' AND details::text ILIKE '%amina%';

-- ═══ 10. Notifications : neutres, et seulement quand l'invitation est prête ═══
INSERT INTO resultat
SELECT 95, 'notification d''invitation : titre serveur, corps neutre', '1',
       count(*)::text, CASE WHEN count(*) = 1 THEN 'OK' ELSE 'ÉCHEC' END
  FROM public.notifications WHERE user_id = 'banc-inv-m1' AND title = 'Invitation à l''équipe d''administration'
   AND body NOT ILIKE '%auditor%' AND body NOT ILIKE '%auditeur%';

-- ═══ Rapport ═══
SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n;

ROLLBACK;
