-- Banc de l'auto-promotion dans un groupe (group_members.role).
--
--   supabase db query --linked -f tools/rls_tests/auto_promotion_group_members.sql
--
-- Condition : 0 cas en ÉCHEC. Tout est dans un `BEGIN … ROLLBACK`.
--
-- CE QUE LE BANC ÉTABLIT
-- Mesuré en production le 2026-09-17 (transaction annulée, comme ici) : un
-- simple membre du groupe 90a2baa1 s'est nommé owner par un simple
--
--   UPDATE group_members SET role = 'owner' WHERE group_id = … AND user_id = <lui>
--
-- `group_members_own` (FOR ALL USING firebase_uid() = user_id, sans WITH
-- CHECK distinct) ne dit rien de la colonne `role` — cas 3, qui reproduit
-- l'exploit puis vérifie qu'il est refusé depuis la migration
-- 20260917010000_group_members_role_sans_auto_promotion.sql. Cas 7 : le même
-- trou existait aussi à l'INSERT, dans un groupe public. Cas 11 : la même
-- migration ferme au passage une rétrogradation silencieuse — l'upsert de
-- `joinGroup` / l'acceptation d'invitation (`role = 'member'` sur conflit)
-- écrasait un admin ou un owner qui « rejoint » à nouveau son propre groupe.
--
-- Cas 8, 9, 12, 13 : témoins que le garde laisse passer ce qui doit
-- continuer de fonctionner — adhésion simple, upsert idempotent, départ
-- volontaire, création de groupe par la RPC `insert_group` (SECURITY
-- DEFINER, pose role='owner' pour un compte qui n'est pas encore admin du
-- nouveau groupe).
--
-- Données réelles relevées le 2026-09-17 — mêmes que
-- tools/rls_tests/retrait_membre_groupe.sql. Si elles disparaissent, reprendre
-- sa requête de tête pour une conversation de groupe basculée, ou plus
-- simplement :
--   SELECT group_id, user_id, role FROM group_members
--    WHERE role IN ('admin','owner') LIMIT 1;
-- pour l'admin, et n'importe quel co-membre `role='member'` du même groupe.

BEGIN;

CREATE TEMP TABLE resultat(n int, cas text, attendu text, obtenu text, verdict text);
CREATE TEMP TABLE ctx(k text PRIMARY KEY, v text);
GRANT ALL ON resultat, ctx TO authenticated;

INSERT INTO ctx VALUES
  ('groupe', '90a2baa1-3927-4b21-97ac-5907002ed75d'),
  ('admin',  'U64HKfrjM5NwR6HO00XPKo6168z2'),
  ('membre', 'vQZE49dTdyRtLwSG6lMIbhAqoFG2');

-- ═══ Préalables, en postgres ════════════════════════════════════════════════
INSERT INTO resultat
SELECT 0, 'préalable : rôles réels dans le groupe mesuré',
       'admin admin/owner, membre member',
       'admin=' || (SELECT role FROM group_members
                      WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                        AND user_id = (SELECT v FROM ctx WHERE k='admin'))
         || ' membre=' || (SELECT role FROM group_members
                              WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                                AND user_id = (SELECT v FROM ctx WHERE k='membre')),
       CASE WHEN (SELECT role FROM group_members
                    WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                      AND user_id = (SELECT v FROM ctx WHERE k='admin')) IN ('admin','owner')
             AND (SELECT role FROM group_members
                    WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
                      AND user_id = (SELECT v FROM ctx WHERE k='membre')) = 'member'
            THEN 'OK' ELSE 'ÉCHEC' END;

-- Groupe public jetable pour les cas d'INSERT / adhésion / départ, sans
-- toucher aux groupes réels. Même geste que les fonctions officielles
-- (insert_group, get_or_create_official_group) : désactiver les deux
-- déclencheurs qui imposeraient un creator_id différent ou refuseraient
-- is_official, le temps de poser une ligne explicite.
DO $$
DECLARE v_grp uuid := gen_random_uuid();
BEGIN
  ALTER TABLE public.groups DISABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups DISABLE TRIGGER groups_guard_official;

  INSERT INTO public.groups (id, name, creator_id, creator_name, category, is_private, member_count)
  VALUES (v_grp, 'Banc auto-promotion (temp)', (SELECT v FROM ctx WHERE k='membre'), 'Banc', 'general', false, 0);

  ALTER TABLE public.groups ENABLE TRIGGER enforce_group_creator_trigger;
  ALTER TABLE public.groups ENABLE TRIGGER groups_guard_official;

  INSERT INTO ctx VALUES ('groupe_temp', v_grp::text);

  INSERT INTO resultat
  SELECT 1, 'préalable : groupe public temporaire créé pour le banc', 'is_private=false',
         'is_private=' || is_private::text,
         CASE WHEN NOT is_private THEN 'OK' ELSE 'ÉCHEC' END
    FROM public.groups WHERE id = v_grp;
END $$;

-- ═══ Le membre ══════════════════════════════════════════════════════════════
SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000bb","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

INSERT INTO resultat VALUES (2, 'rôle et identité simulés', 'authenticated / vQZE49…',
  current_user || ' / ' || COALESCE(firebase_uid(), '<null>'),
  CASE WHEN current_user = 'authenticated' AND firebase_uid() = 'vQZE49dTdyRtLwSG6lMIbhAqoFG2' THEN 'OK' ELSE 'ÉCHEC' END);

-- ── 3. LA FAILLE MESURÉE : auto-promotion à owner par UPDATE ───────────────
DO $$
BEGIN
  UPDATE group_members SET role = 'owner'
   WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
     AND user_id = (SELECT v FROM ctx WHERE k='membre');
  INSERT INTO resultat VALUES (3, 'la faille mesurée : auto-promotion à owner par UPDATE', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (3, 'la faille mesurée : auto-promotion à owner par UPDATE', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 4. Le rôle en base n'a pas bougé ────────────────────────────────────────
INSERT INTO resultat
SELECT 4, 'le rôle du membre reste ''member'' en base après l''essai', 'member', role,
       CASE WHEN role = 'member' THEN 'OK' ELSE 'ÉCHEC' END
  FROM group_members
 WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
   AND user_id = (SELECT v FROM ctx WHERE k='membre');

-- ── 5. is_group_admin() ne s'est pas mis à répondre oui ─────────────────────
INSERT INTO resultat
SELECT 5, 'is_group_admin(groupe) reste faux pour le membre', 'false', is_group_admin((SELECT v FROM ctx WHERE k='groupe')::uuid)::text,
       CASE WHEN NOT is_group_admin((SELECT v FROM ctx WHERE k='groupe')::uuid) THEN 'OK' ELSE 'ÉCHEC' END;

-- ── 6. group_id de sa propre ligne ne se laisse pas glisser ─────────────────
DO $$
BEGIN
  UPDATE group_members SET group_id = (SELECT v FROM ctx WHERE k='groupe_temp')::uuid
   WHERE group_id = (SELECT v FROM ctx WHERE k='groupe')::uuid
     AND user_id = (SELECT v FROM ctx WHERE k='membre');
  INSERT INTO resultat VALUES (6, 'group_id de sa propre ligne ne se glisse pas vers un autre groupe', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (6, 'group_id de sa propre ligne ne se glisse pas vers un autre groupe', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 7. LE SECOND TROU : auto-promotion à owner par INSERT direct ───────────
-- Dans un groupe PUBLIC, group_members_insert_gate laissait déjà passer
-- l'INSERT (is_group_public) ; group_members_own ne disait rien du rôle.
DO $$
BEGIN
  INSERT INTO group_members (group_id, user_id, role)
  VALUES ((SELECT v FROM ctx WHERE k='groupe_temp')::uuid, (SELECT v FROM ctx WHERE k='membre'), 'owner');
  INSERT INTO resultat VALUES (7, 'le second trou : auto-promotion à owner par INSERT direct', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (7, 'le second trou : auto-promotion à owner par INSERT direct', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

-- ── 8. Témoin : l'adhésion simple continue de fonctionner ──────────────────
DO $$
DECLARE v_n int;
BEGIN
  WITH ins AS (
    INSERT INTO group_members (group_id, user_id, role)
    VALUES ((SELECT v FROM ctx WHERE k='groupe_temp')::uuid, (SELECT v FROM ctx WHERE k='membre'), 'member')
    ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'member'
    RETURNING 1)
  SELECT count(*) INTO v_n FROM ins;
  INSERT INTO resultat VALUES (8, 'témoin : adhésion simple (role=''member'') dans le groupe public', '1 ligne', v_n || ' ligne(s)',
    CASE WHEN v_n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (8, 'témoin : adhésion simple (role=''member'') dans le groupe public', '1 ligne',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

-- ── 9. Témoin : rejouer le même upsert (déjà member) reste permis ──────────
DO $$
DECLARE v_n int;
BEGIN
  WITH ins AS (
    INSERT INTO group_members (group_id, user_id, role)
    VALUES ((SELECT v FROM ctx WHERE k='groupe_temp')::uuid, (SELECT v FROM ctx WHERE k='membre'), 'member')
    ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'member'
    RETURNING 1)
  SELECT count(*) INTO v_n FROM ins;
  INSERT INTO resultat VALUES (9, 'témoin : rejouer l''upsert déjà ''member'' (idempotent)', '1 ligne', v_n || ' ligne(s)',
    CASE WHEN v_n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (9, 'témoin : rejouer l''upsert déjà ''member'' (idempotent)', '1 ligne',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

-- ═══ Simulateur d'une promotion déjà faite (par une RPC), en postgres ══════
RESET ROLE;
UPDATE group_members SET role = 'owner'
 WHERE group_id = (SELECT v FROM ctx WHERE k='groupe_temp')::uuid
   AND user_id = (SELECT v FROM ctx WHERE k='membre');

INSERT INTO resultat
SELECT 10, 'simulateur : le membre est owner du groupe temporaire', 'owner', role,
       CASE WHEN role = 'owner' THEN 'OK' ELSE 'ÉCHEC' END
  FROM group_members
 WHERE group_id = (SELECT v FROM ctx WHERE k='groupe_temp')::uuid
   AND user_id = (SELECT v FROM ctx WHERE k='membre');

SET LOCAL request.jwt.claims =
  '{"sub":"00000000-0000-0000-0000-0000000000bb","app_metadata":{"firebase_uid":"vQZE49dTdyRtLwSG6lMIbhAqoFG2"},"role":"authenticated"}';
SET LOCAL ROLE authenticated;

-- ── 11. LA RÉTROGRADATION SILENCIEUSE : l'upsert n'écrase plus l'owner ─────
DO $$
BEGIN
  INSERT INTO group_members (group_id, user_id, role)
  VALUES ((SELECT v FROM ctx WHERE k='groupe_temp')::uuid, (SELECT v FROM ctx WHERE k='membre'), 'member')
  ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'member';
  INSERT INTO resultat VALUES (11, 'la rétrogradation silencieuse : l''upsert n''écrase plus l''owner', 'refusé 42501', 'ACCEPTÉ', 'ÉCHEC');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (11, 'la rétrogradation silencieuse : l''upsert n''écrase plus l''owner', 'refusé 42501',
    'refusé ' || SQLSTATE, CASE WHEN SQLSTATE = '42501' THEN 'OK' ELSE 'ÉCHEC' END);
END $$;

RESET ROLE;
INSERT INTO resultat
SELECT 11, 'et le rôle owner est resté intact ensuite', 'owner', role,
       CASE WHEN role = 'owner' THEN 'OK' ELSE 'ÉCHEC' END
  FROM group_members
 WHERE group_id = (SELECT v FROM ctx WHERE k='groupe_temp')::uuid
   AND user_id = (SELECT v FROM ctx WHERE k='membre');
SET LOCAL ROLE authenticated;

-- ── 12. Témoin : le départ volontaire reste permis, même en tant qu'owner ──
DO $$
DECLARE v_n int;
BEGIN
  WITH del AS (
    DELETE FROM group_members
     WHERE group_id = (SELECT v FROM ctx WHERE k='groupe_temp')::uuid
       AND user_id = (SELECT v FROM ctx WHERE k='membre')
    RETURNING 1)
  SELECT count(*) INTO v_n FROM del;
  INSERT INTO resultat VALUES (12, 'témoin : leaveGroup (DELETE de sa propre ligne) reste permis', '1 ligne', v_n || ' ligne(s)',
    CASE WHEN v_n = 1 THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (12, 'témoin : leaveGroup (DELETE de sa propre ligne) reste permis', '1 ligne',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

-- ── 13. Témoin : la vraie RPC insert_group pose toujours role='owner' ──────
DO $$
DECLARE
  v_json json;
  v_new_grp uuid;
  v_role text;
BEGIN
  v_json := insert_group(p_name := 'Banc auto-promotion — via RPC');
  v_new_grp := (v_json->>'id')::uuid;
  SELECT role INTO v_role FROM group_members
   WHERE group_id = v_new_grp AND user_id = (SELECT v FROM ctx WHERE k='membre');
  INSERT INTO resultat VALUES (13, 'témoin : insert_group() (SECURITY DEFINER) pose toujours role=''owner''',
    'owner', COALESCE(v_role, '<absent>'),
    CASE WHEN v_role = 'owner' THEN 'OK' ELSE 'ÉCHEC' END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO resultat VALUES (13, 'témoin : insert_group() (SECURITY DEFINER) pose toujours role=''owner''', 'owner',
    'refusé ' || SQLSTATE || ' : ' || left(SQLERRM, 80), 'ÉCHEC');
END $$;

-- ── 14. Mesure structurelle : le garde ne concerne que authenticated/anon ──
-- insert_group, get_or_create_official_group et approve_group_request sont
-- toutes SECURITY DEFINER ; leur propriétaire (celui qui exécute leurs
-- écritures sur group_members) n'est ni authenticated ni anon — c'est ce qui
-- leur laisse passer le garde sans qu'il les connaisse par leur nom. Une
-- future RPC de promotion/rétrogradation (nommer_admin_du_groupe /
-- retirer_admin_du_groupe, en préparation ailleurs) en hérite du même coup,
-- tant qu'elle est SECURITY DEFINER comme elles — pas encore créée, donc pas
-- appelable ici, mais la propriété qui la couvrira est mesurable dès
-- maintenant.
RESET ROLE;
INSERT INTO resultat
SELECT 14, 'mesure structurelle : le propriétaire de insert_group n''est pas authenticated/anon',
       'ni authenticated ni anon',
       (SELECT r.rolname FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner WHERE p.proname = 'insert_group' LIMIT 1),
       CASE WHEN (SELECT r.rolname FROM pg_proc p JOIN pg_roles r ON r.oid = p.proowner WHERE p.proname = 'insert_group' LIMIT 1)
                 NOT IN ('authenticated', 'anon')
            THEN 'OK' ELSE 'ÉCHEC' END;

SELECT n, verdict, cas, attendu, obtenu FROM resultat ORDER BY n, cas;

ROLLBACK;
