-- Banc des invitations de groupe -- rejoue le parcours reel et les
-- contournements connus, dans une transaction ANNULEE (rien n'est ecrit).
--
--   supabase db query --linked -f supabase/diagnostics/2026-09-09_invitations_groupe.sql
--
-- Passer le fichier avec `-f`, PAS en argument via "$(cat …)" : le banc
-- contient des accents et des barres de cadre, et cette forme le fait echouer
-- sur un message tronque qui ressemble a un vrai « ECHEC 1 ». Une minute
-- perdue a croire le correctif casse, le 2026-09-09.
--
-- Sortie attendue : la ligne « banc termine ». N'IMPORTE QUEL « ECHEC n » leve
-- une exception et interrompt tout -- c'est le signal.
--
-- ⚠️ `db query --linked` se connecte en `postgres`, qui contourne RLS
-- entierement : chaque etape passe donc par `SET LOCAL ROLE authenticated` et
-- `request.jwt.claims`. Sans ces deux lignes, le banc rend un faux « tout va
-- bien » (l'orniere deja rencontree le 2026-08-14).
--
-- Les identites sont celles de la base de production au 2026-09-09 :
--   vQZE49… administrateur de « Groupe de test prive » (prive)
--   U64HK… membre de « Diaspora Niger - Canada » (public), etranger au prive
--   DfSyAW… membre de « Diaspora Niger - NE », etranger au prive et non invite
-- Si ces appartenances changent, les etapes 3 a 7 mesurent autre chose que ce
-- qu'elles annoncent : reverifier avant de conclure.

BEGIN;
-- ═══ 1. Attaque : je m'invite moi-meme dans un groupe prive ═══
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"11111111-1111-4111-8111-111111111111","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"}}';
DO $t$
BEGIN
  INSERT INTO group_invites (group_id, group_name, inviter_id, inviter_name,
                             invitee_id, invitee_name, status)
  VALUES ('2b24986f-08b5-4840-9931-dbe046ffb394', 'prive', 'U64HKfrjM5NwR6HO00XPKo6168z2', 'moi', 'U64HKfrjM5NwR6HO00XPKo6168z2', 'moi', 'pending');
  RAISE EXCEPTION 'ECHEC 1 : auto-invitation acceptee';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'OK 1 auto-invitation refusee';
END
$t$;

-- ═══ 2. Attaque : detourner le group_id d'une invitation legitime ═══
RESET ROLE;
INSERT INTO group_invites (id, group_id, group_name, inviter_id, inviter_name,
                           invitee_id, invitee_name, status)
VALUES ('aaaaaaaa-0000-4000-8000-000000000001', '03077217-24d5-4cfa-9ec6-ed5b593c3cd2', 'Canada',
        'czk5UoUclLOFmbRtUIZ5XYLYKo52', 'plateforme',
        'U64HKfrjM5NwR6HO00XPKo6168z2', 'invite', 'pending');
SET LOCAL ROLE authenticated;
DO $t$
BEGIN
  UPDATE group_invites SET group_id = '2b24986f-08b5-4840-9931-dbe046ffb394' WHERE id = 'aaaaaaaa-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'ECHEC 2 : group_id detourne';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'OK 2 detournement de group_id refuse';
END
$t$;

-- ═══ 3. Un simple membre ne peut pas inviter ═══
DO $t$
BEGIN
  INSERT INTO group_invites (group_id, group_name, inviter_id, inviter_name,
                             invitee_id, invitee_name, status)
  VALUES ('03077217-24d5-4cfa-9ec6-ed5b593c3cd2', 'Canada', 'U64HKfrjM5NwR6HO00XPKo6168z2', 'simple membre',
          'DfSyAWiGuSQfCFpbhp1SVk5eQ8F2', 'cible', 'pending');
  RAISE EXCEPTION 'ECHEC 3 : un simple membre a pu inviter';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'OK 3 invitation par un non-administrateur refusee';
END
$t$;

-- ═══ 4. Nominal : l'administrateur du groupe prive invite ═══
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"22222222-2222-4222-8222-222222222222","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"}}';
DO $t$
BEGIN
  INSERT INTO group_invites (id, group_id, group_name, inviter_id, inviter_name,
                             invitee_id, invitee_name, status)
  VALUES ('aaaaaaaa-0000-4000-8000-000000000002', '2b24986f-08b5-4840-9931-dbe046ffb394', 'prive', 'vQZE49dTdyRtLwSG6lMIbhAqoFG2', 'admin',
          'U64HKfrjM5NwR6HO00XPKo6168z2', 'invite', 'pending');
  RAISE NOTICE 'OK 4 invitation par un administrateur acceptee';
END
$t$;

-- ═══ 5. Nominal : l'invite lit la fiche du groupe prive ═══
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"33333333-3333-4333-8333-333333333333","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"}}';
DO $t$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM groups WHERE id = '2b24986f-08b5-4840-9931-dbe046ffb394') THEN
    RAISE EXCEPTION 'ECHEC 5 : l''invite ne voit pas le groupe prive';
  END IF;
  RAISE NOTICE 'OK 5 l''invite lit la fiche du groupe prive';
END
$t$;

-- ═══ 6. Un etranger sans invitation ne la lit toujours pas ═══
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"44444444-4444-4444-8444-444444444444","app_metadata":{"firebase_uid":"DfSyAWiGuSQfCFpbhp1SVk5eQ8F2"}}';
DO $t$
BEGIN
  IF EXISTS (SELECT 1 FROM groups WHERE id = '2b24986f-08b5-4840-9931-dbe046ffb394') THEN
    RAISE EXCEPTION 'ECHEC 6 : groupe prive lisible sans invitation';
  END IF;
  RAISE NOTICE 'OK 6 groupe prive invisible sans invitation';
END
$t$;

-- ═══ 7. Nominal : l'invite accepte, puis entre dans le groupe ═══
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"55555555-5555-4555-8555-555555555555","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"}}';
DO $t$
BEGIN
  UPDATE group_invites SET status = 'accepted', responded_at = now()
   WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002';
  IF NOT FOUND THEN RAISE EXCEPTION 'ECHEC 7 : acceptation bloquee'; END IF;
  INSERT INTO group_members (group_id, user_id, role)
  VALUES ('2b24986f-08b5-4840-9931-dbe046ffb394', 'U64HKfrjM5NwR6HO00XPKo6168z2', 'member');
  RAISE NOTICE 'OK 7 acceptation puis entree dans le groupe';
END
$t$;

-- ═══ 8. Une invitation REFUSEE ne fait plus entrer ═══
RESET ROLE;
DELETE FROM group_members WHERE group_id = '2b24986f-08b5-4840-9931-dbe046ffb394' AND user_id = 'U64HKfrjM5NwR6HO00XPKo6168z2';
UPDATE group_invites SET status = 'declined' WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002';
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"role":"authenticated","sub":"66666666-6666-4666-8666-666666666666","app_metadata":{"firebase_uid":"U64HKfrjM5NwR6HO00XPKo6168z2"}}';
DO $t$
BEGIN
  IF public.has_group_invite('2b24986f-08b5-4840-9931-dbe046ffb394'::uuid) THEN
    RAISE EXCEPTION 'ECHEC 8 : invitation refusee encore valable';
  END IF;
  INSERT INTO group_members (group_id, user_id, role)
  VALUES ('2b24986f-08b5-4840-9931-dbe046ffb394', 'U64HKfrjM5NwR6HO00XPKo6168z2', 'member');
  RAISE EXCEPTION 'ECHEC 8b : entree malgre un refus';
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'OK 8 une invitation refusee ne fait plus entrer';
END
$t$;
RESET ROLE;

SELECT 'banc termine' AS resultat;
ROLLBACK;
