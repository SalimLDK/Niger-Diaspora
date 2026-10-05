-- Écritures atomiques dans `data`, suite de 20261004100000.
--
-- LE DÉFAUT
-- Restaient en « lire `data`, modifier en mémoire, réécrire `data` entier » :
--   · « Marquer comme lu » (écran et notification) : un message arrivé entre
--     la lecture et l'écriture voyait son incrément de pastille effacé — la
--     pastille du destinataire repartait à zéro alors qu'il avait du nouveau,
--     ou, à l'inverse, une sourdine posée entre-temps disparaissait ;
--   · « Supprimer pour tout le monde », et le vidage de l'aperçu qui suit ;
--   · « Modifier » un message : un « Lu », une réaction, une étoile posés
--     pendant le rechiffrement étaient effacés ;
--   · « Signaler le groupe ».
--
-- LE CORRECTIF
-- Trois fonctions SECURITY INVOKER, sur le modèle de 20261004100000 : la
-- modification se fait DANS l'UPDATE. RLS, droits de colonne et gardes
-- (`messages_garde_update`, `conversations_guard_admin_fields`,
-- `conversations_colonnes_figees`) s'appliquent comme à l'UPDATE direct
-- qu'elles remplacent : aucun droit ouvert.
--
-- Banc : tools/rls_tests/donnees_jsonb_atomiques_suite.sql

-- ── 1. conversations.data : fusion profonde + ajout à des listes ───────────
-- [p_fusion] : un niveau de profondeur (`unreadCount`, `deletedBy`…).
-- [p_ajouts] : chaque valeur est ajoutée à la liste de sa clé, sans doublon
-- (`lastMessageReadBy`, `reportedBy`).
CREATE OR REPLACE FUNCTION public.modifier_donnees_conversation(
  p_conversation_id TEXT,
  p_fusion JSONB DEFAULT '{}'::jsonb,
  p_ajouts JSONB DEFAULT '{}'::jsonb
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH maj AS (
    UPDATE conversations c
       SET data = COALESCE(c.data, '{}'::jsonb)
         || (SELECT COALESCE(jsonb_object_agg(
                      e.k,
                      CASE WHEN jsonb_typeof(c.data -> e.k) = 'object'
                             AND jsonb_typeof(e.v) = 'object'
                           THEN (c.data -> e.k) || e.v
                           ELSE e.v END), '{}'::jsonb)
               FROM jsonb_each(COALESCE(p_fusion, '{}'::jsonb)) AS e(k, v))
         || (SELECT COALESCE(jsonb_object_agg(
                      e.k,
                      CASE
                        WHEN jsonb_typeof(c.data -> e.k) IS DISTINCT FROM 'array'
                          THEN jsonb_build_array(e.v)
                        WHEN (c.data -> e.k) @> jsonb_build_array(e.v)
                          THEN c.data -> e.k
                        ELSE (c.data -> e.k) || jsonb_build_array(e.v)
                      END), '{}'::jsonb)
               FROM jsonb_each(COALESCE(p_ajouts, '{}'::jsonb)) AS e(k, v))
     WHERE c.id = p_conversation_id
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM maj);
$$;

-- ── 2. messages.data : retrait, fusion, ajout, et `is_deleted` ─────────────
-- Dans cet ordre : (data - p_retirer) || p_fusion || ajouts. Le retrait
-- passe AVANT la fusion : une modification retire les charges chiffrées
-- périmées puis pose les neuves sous les mêmes clés.
-- [p_supprime] : `null` laisse `is_deleted` tel quel.
-- Rend le `created_at` du message modifié, `null` si aucune ligne n'a bougé.
CREATE OR REPLACE FUNCTION public.modifier_donnees_message(
  p_message_id TEXT,
  p_fusion JSONB DEFAULT '{}'::jsonb,
  p_retirer TEXT[] DEFAULT '{}'::text[],
  p_ajouts JSONB DEFAULT '{}'::jsonb,
  p_supprime BOOLEAN DEFAULT NULL
)
RETURNS TIMESTAMPTZ
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  UPDATE messages m
     SET is_deleted = COALESCE(p_supprime, m.is_deleted),
         data = (COALESCE(m.data, '{}'::jsonb) - COALESCE(p_retirer, '{}'::text[]))
           || COALESCE(p_fusion, '{}'::jsonb)
           || (SELECT COALESCE(jsonb_object_agg(
                        e.k,
                        CASE
                          WHEN jsonb_typeof(m.data -> e.k) IS DISTINCT FROM 'array'
                            THEN jsonb_build_array(e.v)
                          WHEN (m.data -> e.k) @> jsonb_build_array(e.v)
                            THEN m.data -> e.k
                          ELSE (m.data -> e.k) || jsonb_build_array(e.v)
                        END), '{}'::jsonb)
                 FROM jsonb_each(COALESCE(p_ajouts, '{}'::jsonb)) AS e(k, v))
   WHERE m.id = p_message_id
  RETURNING m.created_at;
$$;

-- ── 3. Vider l'aperçu si le message supprimé était le dernier ──────────────
-- Le critère de `purger_messages_expires` : `last_message_at` est la date du
-- dernier message (recopiée par `apres_envoi_message`, 20261005090000). Le
-- message doit être supprimé : sans quoi n'importe quel participant pourrait
-- effacer l'aperçu du dernier message d'un autre.
CREATE OR REPLACE FUNCTION public.vider_apercu_si_dernier(
  p_conversation_id TEXT,
  p_message_id TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH maj AS (
    UPDATE conversations c
       SET data = (COALESCE(c.data, '{}'::jsonb) - 'lastMessageExpired')
         || jsonb_build_object('lastMessage', '', 'lastMessageDeleted', true)
      FROM messages m
     WHERE c.id = p_conversation_id
       AND m.id = p_message_id
       AND m.conversation_id = c.id
       AND m.is_deleted
       AND c.last_message_at = m.created_at
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM maj);
$$;

REVOKE ALL ON FUNCTION public.modifier_donnees_conversation(TEXT, JSONB, JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.modifier_donnees_message(TEXT, JSONB, TEXT[], JSONB, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.vider_apercu_si_dernier(TEXT, TEXT) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.modifier_donnees_conversation(TEXT, JSONB, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.modifier_donnees_message(TEXT, JSONB, TEXT[], JSONB, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vider_apercu_si_dernier(TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
