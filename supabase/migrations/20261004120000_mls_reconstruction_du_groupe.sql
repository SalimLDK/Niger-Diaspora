-- MLS : reconstruire le groupe d'une conversation dont l'arbre est bloqué.
--
-- LE DÉFAUT
-- Le serveur ne peut pas distinguer un commit valide d'octets quelconques :
-- tout est chiffré. La policy d'insertion de `mls_commits` laisse donc
-- n'importe quel membre réserver l'epoch N+1 (clé primaire
-- `(conversation_id, epoch)`) avec des octets invalides. Tous les autres
-- tombent sur `commit_illisible`, leurs propres commits prennent 23505, et
-- rien ne permettait d'en sortir : le groupe était mort, définitivement.
-- Les groupes officiels de ville sont ouverts à tous.
--
-- Restreindre la publication aux appareils déjà membres a été écarté : la
-- jointure externe publie son commit AVANT d'être inscrite dans
-- `conversation_devices`, et c'est elle qui fait entrer les membres d'un
-- groupe ouvert. La parade retenue est la RÉPARATION, plus une alerte côté
-- client.
--
-- LE CORRECTIF
-- `reconstruire_groupe_mls(conversation)` remet le transport MLS de la
-- conversation à zéro :
--   · supprime ses `mls_commits` et ses `mls_welcomes` non consommés ou non :
--     la numérotation des epochs repart de 0, et un Welcome de l'ancien arbre
--     ne doit plus être pris pour une invitation au nouveau ;
--   · vide `mls_group_info` (l'arbre public de l'ancien groupe) ;
--   · repasse ses `conversation_devices` en `pending` ;
--   · pose `mls_rebuilt_at = now()`.
-- `mls_since` reste posé : la conversation reste chiffrée, le serveur refuse
-- toujours le clair. Les `mls_messages` restent : leur clair ne vit que dans
-- le cache de chaque appareil, comme avant.
--
-- Chaque appareil qui lit `mls_rebuilt_at` plus récent que sa dernière
-- reconstruction connue oublie son groupe local, place son curseur à cette
-- date, et rejoint le nouveau groupe — créé par le premier appareil qui en a
-- besoin, les autres ajoutés par Welcome (`MlsConversationService`).
--
-- QUI PEUT RECONSTRUIRE
--   · conversation de groupe : un administrateur (`data.adminIds`, rôle
--     admin/owner dans `group_members`, ou créateur) ;
--   · conversation hors groupe : l'un des participants.
-- Une reconstruction au plus toutes les 5 minutes par conversation : sinon
-- un participant malveillant d'une 1:1 la rendrait inutilisable en boucle.
-- Le membre qui a bloqué l'arbre redeviendra membre du nouveau groupe : à un
-- administrateur de l'exclure d'abord.
--
-- `mls_rebuilt_at` rejoint les colonnes figées pour le client
-- (`guard_conversations_colonnes_figees`, 20261003120000) : sans ça,
-- n'importe quel participant forcerait tout le monde à oublier son groupe.
--
-- Banc : tools/rls_tests/mls_reconstruction_du_groupe.sql

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS mls_rebuilt_at timestamptz;

CREATE OR REPLACE FUNCTION public.reconstruire_groupe_mls(p_conversation_id TEXT)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid   TEXT := public.firebase_uid();
  v_conv  public.conversations%ROWTYPE;
  v_group UUID;
  v_admin BOOLEAN;
  v_maintenant timestamptz := now();
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'reconstruire_groupe_mls : non authentifié' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_conv FROM conversations WHERE id = p_conversation_id FOR UPDATE;
  IF NOT FOUND OR NOT (v_conv.participant_ids @> ARRAY[v_uid]) THEN
    RAISE EXCEPTION 'reconstruire_groupe_mls : conversation inaccessible' USING ERRCODE = '42501';
  END IF;
  IF v_conv.mls_since IS NULL THEN
    RAISE EXCEPTION 'reconstruire_groupe_mls : conversation non chiffrée' USING ERRCODE = '22023';
  END IF;

  IF v_conv.group_id IS NOT NULL THEN
    BEGIN
      v_group := NULLIF(v_conv.group_id, '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      v_group := NULL;
    END;
    v_admin := COALESCE(v_conv.data -> 'adminIds', '[]'::jsonb) ? v_uid
            OR v_conv.created_by = v_uid
            OR (v_group IS NOT NULL AND public.is_group_admin(v_group));
    IF NOT v_admin THEN
      RAISE EXCEPTION 'reconstruire_groupe_mls : réservé aux administrateurs du groupe'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF v_conv.mls_rebuilt_at IS NOT NULL
     AND v_conv.mls_rebuilt_at > v_maintenant - interval '5 minutes' THEN
    RAISE EXCEPTION 'reconstruire_groupe_mls : déjà reconstruit il y a moins de 5 minutes'
      USING ERRCODE = '55P03';
  END IF;

  DELETE FROM mls_commits  WHERE conversation_id = p_conversation_id;
  DELETE FROM mls_welcomes WHERE conversation_id = p_conversation_id;
  UPDATE conversation_devices
     SET status = 'pending', updated_at = v_maintenant
   WHERE conversation_id = p_conversation_id;
  UPDATE conversations
     SET mls_group_info = NULL, mls_rebuilt_at = v_maintenant
   WHERE id = p_conversation_id;

  RETURN v_maintenant;
END;
$$;

REVOKE ALL ON FUNCTION public.reconstruire_groupe_mls(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconstruire_groupe_mls(TEXT) TO authenticated;

-- `mls_rebuilt_at` figé pour le client : la redéfinition reprend
-- 20261003120000 à l'identique, la colonne en plus.
CREATE OR REPLACE FUNCTION public.guard_conversations_colonnes_figees()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.type IS DISTINCT FROM OLD.type
     OR NEW.group_id IS DISTINCT FROM OLD.group_id
     OR NEW.created_by IS DISTINCT FROM OLD.created_by
     OR NEW.mls_rebuilt_at IS DISTINCT FROM OLD.mls_rebuilt_at THEN
    RAISE EXCEPTION
      'id, type, group_id, created_by et mls_rebuilt_at d''une conversation ne se réécrivent pas'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.group_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.participant_ids IS DISTINCT FROM OLD.participant_ids THEN
    RAISE EXCEPTION
      'Hors groupe, les participants d''une conversation ne changent pas par écriture directe'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
