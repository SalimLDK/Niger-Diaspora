-- Banc « l'exclusion est enregistrée, et tout membre ouvre sa discussion ».
-- Transaction ANNULEE : rien n'est écrit.
--
--   supabase db query --linked -f supabase/diagnostics/2026-09-09_exclusion_et_ouverture_discussion.sql
--
-- Passer le fichier avec `-f`, PAS en argument via "$(cat …)" : les accents
-- le font échouer sur un message tronqué qui ressemble à un vrai « ECHEC ».
--
-- Sortie attendue : « banc termine » + le détail des étapes. Tout « ECHEC »
-- lève une exception et interrompt tout.
--
-- ⚠️ Identités : `db query --linked` se connecte en `postgres`, qui contourne
-- RLS -- chaque étape passe donc par `SET LOCAL ROLE authenticated` +
-- `request.jwt.claims`. Et le garde a une branche « superAdmin plateforme sur
-- groupe officiel » : tester avec `U64HK…` (`users.is_admin = true`) sur un
-- groupe officiel rend un faux « ça passe ». D'où :
--   vQZE49…  admin de « Groupe de test prive » (privé, NON officiel)
--   DfSyAW…  is_admin = false -> joue le membre simple, puis l'exclu
--   0D3PEm…  is_admin = false -> joue le tiers

BEGIN;
CREATE TEMP TABLE banc(etape text, resultat text);
GRANT INSERT, SELECT ON banc TO authenticated;

-- Mise en place : membre réel du groupe, absent de la discussion. C'est
-- l'état de quelqu'un qui a rejoint après la création de la conversation.
INSERT INTO group_members (group_id, user_id, role)
VALUES ('2b24986f-08b5-4840-9931-dbe046ffb394',
        'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2', 'member')
ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'member';

-- ═══ A. Un membre simple ouvre sa discussion ═══
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"44444444-4444-4444-4444-444444444444","app_metadata":{"firebase_uid":"DfSyAWiGuSQfCFpbhp1SVk5eQ8F2"}}';
DO $t$
DECLARE v_id text;
BEGIN
  v_id := public.join_group_conversation('2b24986f-08b5-4840-9931-dbe046ffb394');
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'ECHEC A : la RPC rend NULL pour un membre reel';
  END IF;
  INSERT INTO banc VALUES ('A', 'OK membre simple raccroche');
EXCEPTION WHEN insufficient_privilege THEN
  RAISE EXCEPTION 'ECHEC A : raccrochage encore refuse (42501)';
END
$t$;

-- ═══ B. Un tiers ne peut pas être ajouté par un non-admin ═══
DO $t$
BEGIN
  UPDATE conversations
     SET participant_ids =
           array_append(participant_ids, '0D3PEmyTHWg36l89yDhvZUnnFtq2')
   WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394';
  RAISE EXCEPTION 'ECHEC B : un non-admin a pu ajouter un tiers';
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO banc VALUES ('B', 'OK ajout d''un tiers refuse');
END
$t$;

-- ═══ C. L'administrateur exclut -> l'appartenance est SUPPRIMEE ═══
-- Reproduit exactement ce que fait `removeUserFromGroup` : retrait de
-- participant_ids et de data.adminIds, rien d'autre.
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"}}';
UPDATE conversations
   SET participant_ids =
         array_remove(participant_ids, 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2')
 WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394';
RESET ROLE;
DO $t$
BEGIN
  IF EXISTS (
    SELECT 1 FROM group_members
     WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394'
       AND user_id = 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2'
  ) THEN
    RAISE EXCEPTION 'ECHEC C : l''exclu est toujours membre du groupe';
  END IF;
  INSERT INTO banc VALUES ('C', 'OK exclusion enregistree dans group_members');
END
$t$;

-- ═══ D. L'exclu ne revient PAS en ouvrant la discussion ═══
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"44444444-4444-4444-4444-444444444444","app_metadata":{"firebase_uid":"DfSyAWiGuSQfCFpbhp1SVk5eQ8F2"}}';
DO $t$
DECLARE v_id text;
BEGIN
  v_id := public.join_group_conversation('2b24986f-08b5-4840-9931-dbe046ffb394');
  IF v_id IS NOT NULL THEN
    RAISE EXCEPTION 'ECHEC D : l''exclu a recupere la conversation %', v_id;
  END IF;
  INSERT INTO banc VALUES ('D', 'OK exclu ecarte (RPC rend NULL)');
EXCEPTION WHEN insufficient_privilege THEN
  INSERT INTO banc VALUES ('D', 'OK exclu ecarte (42501)');
END
$t$;
RESET ROLE;
DO $t$
BEGIN
  IF EXISTS (
    SELECT 1 FROM conversations
     WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394'
       AND participant_ids @> ARRAY['DfSyAWiGuSQfCFpbhp1SVk5eQ8F2']
  ) THEN
    RAISE EXCEPTION 'ECHEC D2 : l''exclu est de retour dans participant_ids';
  END IF;
  INSERT INTO banc VALUES ('D2', 'OK participant_ids sans l''exclu');
END
$t$;

-- ═══ E. Un message ordinaire ne fait sortir personne ═══
-- `_updateConversationLastMessage` n'écrit que `data`. Le déclencheur est posé
-- sur `UPDATE OF participant_ids` : il ne doit pas se réveiller ici.
UPDATE conversations
   SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('lastMessage', 'sonde')
 WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394';
DO $t$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM group_members
     WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394'
       AND user_id = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2'
  ) THEN
    RAISE EXCEPTION 'ECHEC E : une ecriture de data a supprime une appartenance';
  END IF;
  INSERT INTO banc VALUES ('E', 'OK ecriture de data sans effet de bord');
END
$t$;

-- ═══ F. Le départ volontaire reste possible ═══
-- Par la RPC `leave_group_conversation`, PAS par un UPDATE direct : la policy
-- `conversations_update` n'a pas de WITH CHECK explicite, Postgres réutilise
-- donc son USING (`participant_ids @> [firebase_uid()]`), qui exige d'être
-- encore participant APRÈS l'update -- ce qu'un départ contredit par
-- définition. Un UPDATE direct rend « new row violates row-level security
-- policy », et pas du tout un refus du garde : ne pas confondre les deux en
-- lisant ce banc.
INSERT INTO group_members (group_id, user_id, role)
VALUES ('2b24986f-08b5-4840-9931-dbe046ffb394',
        'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2', 'member')
ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'member';
UPDATE conversations
   SET participant_ids =
         array_append(participant_ids, 'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2')
 WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394';
SET LOCAL ROLE authenticated;
DO $t$
BEGIN
  PERFORM public.leave_group_conversation('2b24986f-08b5-4840-9931-dbe046ffb394');
  INSERT INTO banc VALUES ('F', 'OK depart volontaire accepte');
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'ECHEC F : depart volontaire refuse (% / %)',
    SQLSTATE, SQLERRM;
END
$t$;
RESET ROLE;
DO $t$
BEGIN
  IF EXISTS (
    SELECT 1 FROM conversations
     WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394'
       AND participant_ids @> ARRAY['DfSyAWiGuSQfCFpbhp1SVk5eQ8F2']
  ) THEN
    RAISE EXCEPTION 'ECHEC F2 : le partant est encore participant';
  END IF;
  INSERT INTO banc VALUES ('F2', 'OK partant retire de la discussion');
END
$t$;

SELECT 'banc termine' AS resultat,
       (SELECT string_agg(etape || ' ' || resultat, ' | ' ORDER BY etape)
          FROM banc) AS detail;
ROLLBACK;
