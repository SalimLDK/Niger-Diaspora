-- Trouvé en creusant le signalement "la gestion des groupes se passe pas
-- bien" : delete_group() (appelée par le bouton « Supprimer le groupe » de
-- la fiche d'édition, admin/créateur seulement) ne supprimait QUE la ligne
-- `groups`. Contrairement à `events`/`post_polls`/`group_pinned_items`
-- (déjà ON DELETE CASCADE depuis groups.id), `group_members` et
-- `conversations` n'ont AUCUNE contrainte de clé étrangère vers `groups` :
--
-- - `group_members` restait avec des lignes orphelines pointant vers un
--   groupe qui n'existe plus ;
-- - la conversation et TOUS ses messages restaient intacts et lisibles
--   indéfiniment par tous les anciens membres -- « supprimer le groupe » ne
--   supprimait pas la discussion du tout.
--
-- Décision de Salim : supprimer un groupe doit le dissoudre pour TOUT LE
-- MONDE, comme quitter mais appliqué à tous les membres d'un coup -- pas
-- une suppression seulement pour l'admin qui agit. `messages`,
-- `group_pinned_items` et `events` cascadent déjà depuis
-- `conversations.id` (ON DELETE CASCADE), donc supprimer la conversation
-- liée suffit à tout nettoyer derrière.
--
-- L'autorisation reste `creator_id = v_uid` uniquement, inchangée : la
-- suppression reste une action plus lourde que la gestion courante,
-- réservée au compte plateforme pour un groupe officiel (voir
-- docs/ops/GROUPES_OFFICIELS.md) -- pas étendue au superAdmin comme
-- `groups_update_admin` l'a été.

CREATE OR REPLACE FUNCTION public.delete_group(p_group_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_uid TEXT;
BEGIN
  v_uid := COALESCE(
    auth.jwt()->'app_metadata'->>'firebase_uid',
    (SELECT am.firebase_uid FROM public.auth_mappings am
       WHERE am.supabase_id = auth.uid() LIMIT 1)
  );

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.groups WHERE id = p_group_id AND creator_id = v_uid
  ) THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Dissout le groupe pour tout le monde : plus personne ne peut lire la
  -- conversation après coup (cascade vers messages/group_pinned_items/events
  -- liés à la conversation), et group_members ne garde aucune trace
  -- orpheline du groupe supprimé.
  DELETE FROM public.conversations WHERE group_id = p_group_id::text;
  DELETE FROM public.group_members WHERE group_id = p_group_id;
  DELETE FROM public.groups WHERE id = p_group_id;
END;
$function$;
