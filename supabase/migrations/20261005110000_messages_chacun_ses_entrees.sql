-- Dans le message d'un autre, chacun ne touche qu'à SA propre entrée.
--
-- LE DÉFAUT
-- `messages_garde_update` (20260916210000) laisse un non-expéditeur modifier
-- huit clés de `data` — `readBy`, `readAt`, `deliveredTo`, `deliveredAt`,
-- `reactions`, `starredBy`, `deletedFor`, `reportedBy` — parce que ce sont
-- les siennes : son « Lu », sa réaction, son favori. Mais la garde vérifiait
-- seulement QUELLES clés bougent, pas QUELLE entrée à l'intérieur. N'importe
-- quel participant pouvait donc, par un UPDATE direct :
--   · retirer la réaction d'un autre, ou lui en prêter une ;
--   · écrire « Lu » ou « Livré » au nom d'un autre — l'expéditeur voit les
--     coches bleues d'un destinataire qui n'a rien ouvert ;
--   · effacer le signalement d'un autre (`reportedBy`), avant modération ;
--   · retirer un autre de `deletedFor` : le message qu'il avait supprimé
--     pour lui réapparaît dans son fil.
--
-- LE CORRECTIF
-- Pour chacune des huit clés, la garde compare les entrées : élément d'une
-- liste (`readBy`…), clé d'un objet (`readAt`, `reactions`…). Toute entrée
-- qui apparaît, disparaît ou change doit être celle de l'appelant.
--
-- Rien ne change pour les chemins de l'app :
--   · accusés de lecture et de livraison, réactions : fonctions SECURITY
--     DEFINER, exécutées en `postgres`, que la garde laisse passer ;
--   · favori, suppression pour soi, signalement : l'entrée de l'appelant ;
--   · l'expéditeur garde la main pleine sur son message ;
--   · la modération d'un admin (suppression pour tous) reste ouverte.
--
-- Banc : tools/rls_tests/messages_chacun_ses_entrees.sql

CREATE OR REPLACE FUNCTION public.messages_garde_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid          text;
  -- Les seules clés de `data` qu'un NON-expéditeur peut faire bouger — et
  -- seulement dans SON entrée (voir la boucle en fin de garde) :
  --   readBy/readAt, deliveredTo/deliveredAt  mark_messages_as_{read,delivered}
  --   reactions                                set_message_reaction
  --   starredBy                                toggleStarMessage
  --   deletedFor                               deleteMessageForMe
  --   reportedBy                               reportMessage
  v_cles_autrui  constant text[] := ARRAY[
    'readBy', 'readAt', 'deliveredTo', 'deliveredAt',
    'reactions', 'starredBy', 'deletedFor', 'reportedBy'
  ];
  v_cle          text;
  v_avant        jsonb;
  v_apres        jsonb;
  v_type         text;
BEGIN
  -- Chemins de confiance : `postgres` (migrations, déclencheurs, et toute
  -- fonction SECURITY DEFINER — dont les RPC d'accusés et de réactions) et
  -- `service_role` (Edge Functions). Seul ce qui arrive par PostgREST sous
  -- l'identité d'un utilisateur est filtré ici.
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  v_uid := public.firebase_uid();

  -- L'expéditeur garde la main pleine sur son message : c'est « Modifier le
  -- message » et « supprimer pour tout le monde ».
  IF v_uid IS NOT NULL AND v_uid = OLD.sender_id THEN
    RETURN NEW;
  END IF;

  -- À partir d'ici : quelqu'un d'autre que l'expéditeur.

  IF NEW.id              IS DISTINCT FROM OLD.id
     OR NEW.sender_id       IS DISTINCT FROM OLD.sender_id
     OR NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
     OR NEW.type            IS DISTINCT FROM OLD.type
     OR NEW.created_at      IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'messages: seul l''expéditeur peut modifier l''identité de son message'
      USING ERRCODE = '42501';
  END IF;

  -- Modération : un administrateur du groupe peut supprimer le message d'un
  -- membre pour tout le monde — la TRANSITION seulement, contenu vidé.
  IF NEW.is_deleted
     AND NOT OLD.is_deleted
     AND COALESCE(NEW.data->>'deletedForEveryone', 'false') = 'true'
     AND COALESCE(NEW.data->>'content', '') = ''
     AND public.est_admin_conversation(OLD.conversation_id)
  THEN
    RETURN NEW;
  END IF;

  IF NEW.is_deleted IS DISTINCT FROM OLD.is_deleted THEN
    RAISE EXCEPTION 'messages: seul l''expéditeur ou un administrateur du groupe peut supprimer ce message'
      USING ERRCODE = '42501';
  END IF;

  IF (COALESCE(NEW.data, '{}'::jsonb) - v_cles_autrui)
     IS DISTINCT FROM
     (COALESCE(OLD.data, '{}'::jsonb) - v_cles_autrui)
  THEN
    RAISE EXCEPTION 'messages: un participant ne peut pas modifier le contenu du message d''un autre'
      USING ERRCODE = '42501';
  END IF;

  -- Dans les huit clés permises, seule l'entrée de l'appelant bouge.
  FOREACH v_cle IN ARRAY v_cles_autrui LOOP
    v_avant := OLD.data -> v_cle;
    v_apres := NEW.data -> v_cle;
    CONTINUE WHEN v_avant IS NOT DISTINCT FROM v_apres;

    IF v_uid IS NULL OR v_uid = '' THEN
      RAISE EXCEPTION 'messages: % : appelant non identifié', v_cle
        USING ERRCODE = '42501';
    END IF;

    v_type := COALESCE(jsonb_typeof(v_apres), jsonb_typeof(v_avant));
    IF (v_avant IS NOT NULL AND jsonb_typeof(v_avant) IS DISTINCT FROM v_type)
       OR (v_apres IS NOT NULL AND jsonb_typeof(v_apres) IS DISTINCT FROM v_type)
       OR v_type NOT IN ('array', 'object')
    THEN
      RAISE EXCEPTION 'messages: % : forme inattendue', v_cle
        USING ERRCODE = '42501';
    END IF;

    IF v_type = 'array' THEN
      -- Les éléments qui apparaissent ou disparaissent.
      IF EXISTS (
        SELECT 1 FROM (
          (SELECT e FROM jsonb_array_elements(COALESCE(v_avant, '[]'::jsonb)) AS a(e)
           EXCEPT
           SELECT e FROM jsonb_array_elements(COALESCE(v_apres, '[]'::jsonb)) AS b(e))
          UNION
          (SELECT e FROM jsonb_array_elements(COALESCE(v_apres, '[]'::jsonb)) AS b(e)
           EXCEPT
           SELECT e FROM jsonb_array_elements(COALESCE(v_avant, '[]'::jsonb)) AS a(e))
        ) AS d(e)
        WHERE d.e IS DISTINCT FROM to_jsonb(v_uid)
      ) THEN
        RAISE EXCEPTION 'messages: % : on ne modifie que sa propre entrée', v_cle
          USING ERRCODE = '42501';
      END IF;
    ELSE
      -- Les clés dont la valeur apparaît, disparaît ou change.
      IF EXISTS (
        SELECT 1 FROM (
          SELECT jsonb_object_keys(COALESCE(v_avant, '{}'::jsonb))
          UNION
          SELECT jsonb_object_keys(COALESCE(v_apres, '{}'::jsonb))
        ) AS k(cle)
        WHERE (v_avant -> k.cle) IS DISTINCT FROM (v_apres -> k.cle)
          AND k.cle IS DISTINCT FROM v_uid
      ) THEN
        RAISE EXCEPTION 'messages: % : on ne modifie que sa propre entrée', v_cle
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.messages_garde_update() IS
  'Borne ce qu''un non-expéditeur peut changer dans `messages` : huit clés '
  'de `data`, et dans chacune sa seule entrée. Nécessaire parce que tout vit '
  'dans la colonne `data` (jsonb) : ni le privilège de colonne ni la RLS ne '
  'savent y descendre.';

-- Le déclencheur existe depuis 20260916210000 ; le reposer rend la migration
-- complète à elle seule (CREATE OR REPLACE ne touche que le corps).
DROP TRIGGER IF EXISTS messages_garde_update_trg ON public.messages;
CREATE TRIGGER messages_garde_update_trg
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.messages_garde_update();
