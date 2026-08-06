-- Demandes d'adhesion et invitations : rendre le parcours praticable par l'admin.
--
-- Avant cette migration, `group_requests` n'avait qu'une seule policy :
--
--   USING (firebase_uid() = requester_id OR firebase_uid() = processed_by)
--
-- Une demande en attente a `processed_by` NULL et `requester_id` = le
-- demandeur. L'admin du groupe ne correspond a aucune des deux branches :
-- `getPendingRequests(groupId)` lui rendait une liste vide, et l'UPDATE
-- d'approbation ne touchait aucune ligne -- sans erreur, PostgREST rendant 200
-- sur un update qui ne matche rien. Faire pointer le datasource vers Supabase
-- (c7f4141) a donc deplace la cecite sans la lever.
--
-- Meme trou sur `group_invites` : la policy `inviter_id OR invitee_id` fait que
-- `getSentInvites(groupId)` ne montre a un admin que les invitations qu'il a
-- lui-meme envoyees.
--
-- Trois choses ici :
--   1. l'admin du groupe voit et traite les demandes / invitations du groupe ;
--   2. `approve_group_request` / `reject_group_request` resolvent l'identite du
--      traitant cote base, via firebase_uid(). Le client ecrivait
--      `auth.currentUser.id`, l'uid *Supabase* (un uuid), la ou toute la
--      colonne et toutes les policies parlent en uid *Firebase* : la ligne
--      existante porte `processed_by = '1b313b0d-...'` face a
--      `requester_id = 'U64HKfrjM5Nw...'`. La branche `processed_by` de la
--      policy ne pouvait jamais matcher ;
--   3. l'approbation inscrit le demandeur dans `group_members`, seule source
--      d'appartenance. Le client l'ecrivait dans `groups.member_ids`, colonne
--      vide sur les 4 groupes et systematiquement recalculee depuis
--      `group_members` au chargement (`group_supabase_datasource.dart:41`) :
--      approuver n'ajoutait personne.
--
-- `group_members` reste ferme en ecriture directe (`group_members_own` :
-- firebase_uid() = user_id). L'insertion passe donc par une fonction
-- SECURITY DEFINER qui verifie elle-meme que l'appelant est admin du groupe,
-- plutot que par une policy qui ouvrirait l'ajout de n'importe qui.

-- ── 1. Acces admin aux demandes et invitations du groupe ────────────────────

DROP POLICY IF EXISTS group_requests_group_admin ON public.group_requests;
CREATE POLICY group_requests_group_admin ON public.group_requests
  FOR ALL
  USING (public.is_group_admin(group_id))
  WITH CHECK (public.is_group_admin(group_id));

DROP POLICY IF EXISTS group_invites_group_admin ON public.group_invites;
CREATE POLICY group_invites_group_admin ON public.group_invites
  FOR ALL
  USING (public.is_group_admin(group_id))
  WITH CHECK (public.is_group_admin(group_id));

-- ── 2. Approbation : statut + appartenance, en une transaction ──────────────

CREATE OR REPLACE FUNCTION public.approve_group_request(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_group_id uuid;
  v_requester_id text;
BEGIN
  SELECT group_id, requester_id
    INTO v_group_id, v_requester_id
    FROM group_requests
   WHERE id = p_request_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Demande introuvable';
  END IF;

  IF NOT is_group_admin(v_group_id) THEN
    RAISE EXCEPTION 'Reserve aux administrateurs du groupe';
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

CREATE OR REPLACE FUNCTION public.reject_group_request(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_group_id uuid;
BEGIN
  SELECT group_id INTO v_group_id
    FROM group_requests
   WHERE id = p_request_id;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Demande introuvable';
  END IF;

  IF NOT is_group_admin(v_group_id) THEN
    RAISE EXCEPTION 'Reserve aux administrateurs du groupe';
  END IF;

  UPDATE group_requests
     SET status = 'rejected',
         processed_at = now(),
         processed_by = (SELECT firebase_uid())
   WHERE id = p_request_id;
END;
$$;

-- `REVOKE ... FROM PUBLIC` ne suffit pas : les privileges par defaut du projet
-- accordent EXECUTE a `anon` sur toute fonction creee dans `public`, par une
-- clause distincte que ce revoke ne touche pas. Verifie apres coup :
-- has_function_privilege('anon', ...) rendait encore true. La fonction
-- refuserait de toute facon (is_group_admin() est faux hors session), mais un
-- garde qui ne tient que par ce qui se passe *a l'interieur* est precisement le
-- motif qui a deja coute quatre endpoints ouverts ici.
REVOKE ALL ON FUNCTION public.approve_group_request(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reject_group_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_group_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_group_request(uuid) TO authenticated;

-- ── 3. Temps reel : les deux tables n'etaient pas publiees ──────────────────
--
-- `getPendingRequests` / `getReceivedInvites` s'abonnent a un `.stream()`,
-- mais ni `group_requests` ni `group_invites` n'appartenaient a la publication
-- `supabase_realtime` : le stream ne faisait que son chargement initial. Une
-- demande arrivee pendant que l'admin regarde l'ecran n'apparaissait qu'a la
-- reouverture. Meme trou que `group_pinned_items` (20260805120000).
--
-- `replica identity full` en plus de la publication : le `.stream()` filtre
-- cote serveur sur `group_id` / `requester_id` / `invitee_id`, et sous
-- l'identite par defaut un DELETE ne transporte que la cle primaire -- une
-- demande annulee (`cancelJoinRequest`) ne passerait jamais le filtre et
-- resterait affichee.

ALTER TABLE public.group_requests REPLICA IDENTITY FULL;
ALTER TABLE public.group_invites REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'group_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_requests;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'group_invites'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_invites;
  END IF;
END
$$;
