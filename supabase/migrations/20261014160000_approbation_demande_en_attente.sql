-- N'approuver qu'une demande d'adhésion encore en attente.
--
-- LE DÉFAUT
-- `approve_group_request` (20260806180000) approuvait toute demande, quel que
-- soit son statut : une demande que la personne avait ANNULÉE, ou que l'on
-- avait déjà refusée, la faisait quand même entrer dans le groupe. Retirer sa
-- demande ne garantissait donc pas de ne pas être ajouté.
--
-- LA CORRECTION
-- La fonction, recopiée de 20260806180000, verrouille la demande et exige
-- `status = 'pending'` (ligne marquée « 20261014 »). Une demande déjà
-- approuvée n'est pas une erreur : rien à refaire.
--
-- Banc : tools/rls_tests/approbation_demande_en_attente.sql

CREATE OR REPLACE FUNCTION public.approve_group_request(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_group_id uuid;
  v_requester_id text;
  v_status text;
BEGIN
  SELECT group_id, requester_id, status
    INTO v_group_id, v_requester_id, v_status
    FROM group_requests
   WHERE id = p_request_id
     FOR UPDATE;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Demande introuvable';
  END IF;

  IF NOT is_group_admin(v_group_id) THEN
    RAISE EXCEPTION 'Reserve aux administrateurs du groupe';
  END IF;

  -- 20261014 : seule une demande en attente s'approuve.
  IF v_status = 'approved' THEN
    RETURN;
  END IF;
  IF v_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'Cette demande n''est plus en attente (%)', v_status
      USING ERRCODE = '22023';
  END IF;

  UPDATE group_requests
     SET status = 'approved',
         processed_at = now(),
         processed_by = (SELECT firebase_uid())
   WHERE id = p_request_id;

  -- `group_members` est la seule source d'appartenance : le trigger
  -- `group_members_count_trigger` remet `groups.member_count` a jour derriere.
  INSERT INTO group_members (group_id, user_id, role)
  VALUES (v_group_id, v_requester_id, 'member')
  ON CONFLICT (group_id, user_id) DO NOTHING;
END;
$$;
