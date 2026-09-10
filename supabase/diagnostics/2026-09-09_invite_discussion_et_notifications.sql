-- Banc « l'invité entre dans la discussion, et tout le monde est prévenu ».
-- Transaction ANNULEE : rien n'est écrit, aucun push n'est envoyé (pg_net
-- met la requête en file dans la transaction, le worker ne la voit jamais).
--
--   supabase db query --linked -f supabase/diagnostics/2026-09-09_invite_discussion_et_notifications.sql
--
-- Passer le fichier avec `-f`, PAS en argument via "$(cat …)" : les accents
-- le font échouer sur un message tronqué qui ressemble à un vrai « ECHEC ».
--
-- Sortie attendue : la ligne « banc termine ». Tout « ECHEC n » interrompt.
--
-- ⚠️ Le choix des identités n'est pas cosmétique. `db query --linked` se
-- connecte en `postgres`, qui contourne RLS : chaque étape passe donc par
-- `SET LOCAL ROLE authenticated` + `request.jwt.claims`. Et le garde
-- `conversations_guard_admin_fields` a une branche « superAdmin plateforme sur
-- groupe officiel » : tester avec `U64HK…` (qui est `users.is_admin = true`)
-- sur un groupe officiel rend un faux « ça passe ». D'où :
--   vQZE49…  administrateur de « Groupe de test prive » (privé, NON officiel)
--   DfSyAW…  is_admin = false, étranger à ce groupe -> joue l'invité
--   0D3PEm…  is_admin = false, étranger aussi      -> joue le tiers

BEGIN;
CREATE TEMP TABLE banc(etape text, resultat text);
GRANT INSERT, SELECT ON banc TO authenticated;

-- ═══ Mise en place : l'invité devient membre, sans être dans la discussion ═══
INSERT INTO group_members (group_id, user_id, role)
VALUES ('2b24986f-08b5-4840-9931-dbe046ffb394',
        'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2', 'member')
ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'member';

-- ═══ A. (retiree) ═══
-- Cette etape exigeait qu'un membre SANS invitation soit refuse a la
-- discussion. C'etait la conception d'un premier correctif, abandonnee : la
-- version livree (20260909234500) autorise TOUT membre reel a entrer dans la
-- discussion de son groupe, et fait tenir l'exclusion autrement -- en
-- supprimant l'appartenance quand on retire quelqu'un des participants.
--
-- Laissee telle quelle, l'etape faisait echouer le banc sur du code correct.
-- Ce qu'elle voulait mesurer -- un exclu ne revient pas -- est teste, dans la
-- bonne formulation, par
-- `2026-09-09_exclusion_et_ouverture_discussion.sql` (etapes C et D).
SET LOCAL ROLE authenticated;

-- ═══ B. L'administrateur invite -> une notification part ═══
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"}}';
INSERT INTO group_invites (id, group_id, group_name, inviter_id, inviter_name,
                           invitee_id, invitee_name, status)
VALUES ('bbbbbbbb-0000-4000-8000-000000000001',
        '2b24986f-08b5-4840-9931-dbe046ffb394', 'Groupe de test prive',
        'vQZE49dTdyRtLwSG6lMIbhAqoFG2', 'admin',
        'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2', 'invite', 'pending');
RESET ROLE;
DO $t$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM notifications
   WHERE user_id = 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2'
     AND type = 'groupInvite'
     AND data->>'targetId' = '2b24986f-08b5-4840-9931-dbe046ffb394';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'ECHEC B : % notification(s) d''invitation au lieu de 1', v_n;
  END IF;
  INSERT INTO banc VALUES ('B', 'OK notification d''invitation creee');
END
$t$;

-- ═══ C. L'invité peut maintenant entrer dans la discussion ═══
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"44444444-4444-4444-4444-444444444444","app_metadata":{"firebase_uid":"DfSyAWiGuSQfCFpbhp1SVk5eQ8F2"}}';
DO $t$
DECLARE v_id text;
BEGIN
  v_id := public.join_group_conversation('2b24986f-08b5-4840-9931-dbe046ffb394');
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'ECHEC C : la RPC rend NULL';
  END IF;
  INSERT INTO banc VALUES ('C', 'OK invite raccroche a la discussion');
EXCEPTION WHEN insufficient_privilege THEN
  RAISE EXCEPTION 'ECHEC C : raccrochage de l''invite encore refuse';
END
$t$;
RESET ROLE;
DO $t$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM conversations
     WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394'
       AND participant_ids @> ARRAY['DfSyAWiGuSQfCFpbhp1SVk5eQ8F2']
  ) THEN
    RAISE EXCEPTION 'ECHEC C2 : participant_ids ne contient pas l''invite';
  END IF;
  INSERT INTO banc VALUES ('C2', 'OK participant_ids mis a jour');
END
$t$;

-- ═══ D. L'exemption ne sert qu'à SOI : pas à ajouter un tiers ═══
SET LOCAL ROLE authenticated;
DO $t$
BEGIN
  UPDATE conversations
     SET participant_ids =
           array_append(participant_ids, '0D3PEmyTHWg36l89yDhvZUnnFtq2')
   WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394';
  RAISE EXCEPTION 'ECHEC D : un non-admin a pu ajouter un tiers';
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO banc VALUES ('D', 'OK ajout d''un tiers refuse');
END
$t$;

-- ═══ E. Accepter l'invitation ne renotifie pas ═══
UPDATE group_invites SET status = 'accepted', responded_at = now()
 WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001';
RESET ROLE;
DO $t$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM notifications
   WHERE user_id = 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2' AND type = 'groupInvite';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'ECHEC E : % notifications apres acceptation', v_n;
  END IF;
  INSERT INTO banc VALUES ('E', 'OK acceptation sans notification en plus');
END
$t$;

-- ═══ F. Demande d'adhésion -> notification aux administrateurs ═══
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"55555555-5555-5555-5555-555555555555","app_metadata":{"firebase_uid":"0D3PEmyTHWg36l89yDhvZUnnFtq2"}}';
INSERT INTO group_requests (id, group_id, group_name, requester_id,
                            requester_name, status)
VALUES ('bbbbbbbb-0000-4000-8000-000000000002',
        '2b24986f-08b5-4840-9931-dbe046ffb394', 'Groupe de test prive',
        '0D3PEmyTHWg36l89yDhvZUnnFtq2', 'demandeur', 'pending');
RESET ROLE;
DO $t$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM notifications
   WHERE user_id = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'
     AND type = 'groupJoinRequest';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'ECHEC F : % notification(s) a l''admin au lieu de 1', v_n;
  END IF;
  INSERT INTO banc VALUES ('F', 'OK administrateur prevenu de la demande');
END
$t$;

-- ═══ G. Approbation -> notification au demandeur ═══
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"}}';
SELECT public.approve_group_request('bbbbbbbb-0000-4000-8000-000000000002'::uuid);
RESET ROLE;
DO $t$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM notifications
   WHERE user_id = '0D3PEmyTHWg36l89yDhvZUnnFtq2'
     AND type = 'groupRequestApproved';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'ECHEC G : % notification(s) au demandeur au lieu de 1', v_n;
  END IF;
  INSERT INTO banc VALUES ('G', 'OK demandeur prevenu de l''approbation');
END
$t$;

SELECT 'banc termine' AS resultat,
       (SELECT string_agg(etape || ' ' || resultat, ' | ' ORDER BY etape)
          FROM banc) AS detail;
ROLLBACK;
