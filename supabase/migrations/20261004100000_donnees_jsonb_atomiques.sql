-- Écritures atomiques dans `conversations.data` et `messages.data`.
--
-- LE DÉFAUT
-- Le client modifiait ces colonnes JSONB en trois temps : lire `data`
-- entier, le modifier en mémoire, réécrire `data` entier. Deux écritures qui
-- se croisent, et la seconde efface la première sans que rien ne le dise :
--   · B met le groupe en sourdine pendant que A envoie un message — la mise à
--     jour d'après-envoi de A réécrit l'ancien `data`, la sourdine disparaît ;
--   · deux membres envoient en même temps — un incrément de `unreadCount` se
--     perd, la pastille sous-compte ;
--   · un favori posé pendant qu'un accusé de lecture arrive — le `readBy` lu
--     avant l'accusé est réécrit par-dessus, le « Lu » disparaît (et le garde
--     `messages_garde_update` l'accepte : ce sont des clés autorisées).
--
-- LE CORRECTIF
-- Cinq fonctions qui font la modification DANS l'UPDATE : la ligne est
-- verrouillée, et en lecture validée (READ COMMITTED) une écriture
-- concurrente fait réévaluer l'expression sur la version la plus récente.
-- Plus de fenêtre entre la lecture et l'écriture.
--
-- SECURITY INVOKER, toutes : elles s'exécutent avec les droits de l'appelant.
-- La RLS (`conversations_update`, `messages_update`), les droits de colonne
-- (`GRANT UPDATE (data, is_deleted)` sur messages) et les gardes
-- (`conversations_guard_admin_fields`, `conversations_colonnes_figees`,
-- `messages_garde_update`) s'appliquent exactement comme à l'UPDATE direct
-- qu'elles remplacent. Elles n'ouvrent aucun droit ; elles ferment une course.
--
-- Chacune rend `true` si une ligne a été modifiée : l'UPDATE direct, lui,
-- réussissait à vide quand la RLS écartait la ligne.
--
-- Banc : tools/rls_tests/donnees_jsonb_atomiques.sql

-- ── 1. Fusion dans conversations.data ──────────────────────────────────────
-- [p_profond] : un niveau de profondeur — une clé objet des deux côtés est
-- fusionnée (`mutedBy`, `pinnedBy`…) au lieu d'être remplacée.
CREATE OR REPLACE FUNCTION public.fusionner_donnees_conversation(
  p_conversation_id TEXT,
  p_partiel JSONB,
  p_profond BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH maj AS (
    UPDATE conversations c
       SET data = COALESCE(c.data, '{}'::jsonb) || CASE
             WHEN p_profond THEN (
               SELECT COALESCE(jsonb_object_agg(
                        e.k,
                        CASE WHEN jsonb_typeof(c.data -> e.k) = 'object'
                               AND jsonb_typeof(e.v) = 'object'
                             THEN (c.data -> e.k) || e.v
                             ELSE e.v END), '{}'::jsonb)
                 FROM jsonb_each(COALESCE(p_partiel, '{}'::jsonb)) AS e(k, v))
             ELSE COALESCE(p_partiel, '{}'::jsonb)
           END
     WHERE c.id = p_conversation_id
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM maj);
$$;

-- ── 2. Retrait d'une sous-clé de conversations.data ────────────────────────
CREATE OR REPLACE FUNCTION public.retirer_cle_donnees_conversation(
  p_conversation_id TEXT,
  p_parent TEXT,
  p_enfant TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH maj AS (
    UPDATE conversations c
       SET data = jsonb_set(c.data, ARRAY[p_parent], (c.data -> p_parent) - p_enfant)
     WHERE c.id = p_conversation_id
       AND jsonb_typeof(c.data -> p_parent) = 'object'
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM maj);
$$;

-- ── 3. Fusion dans messages.data ───────────────────────────────────────────
-- [p_ajout_liste] : chaque valeur est AJOUTÉE à la liste de sa clé, si elle
-- n'y est pas déjà (`deletedFor`, `reportedBy`) — au lieu de la remplacer.
CREATE OR REPLACE FUNCTION public.fusionner_donnees_message(
  p_message_id TEXT,
  p_partiel JSONB,
  p_ajout_liste BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH maj AS (
    UPDATE messages m
       SET data = COALESCE(m.data, '{}'::jsonb) || CASE
             WHEN p_ajout_liste THEN (
               SELECT COALESCE(jsonb_object_agg(
                        e.k,
                        CASE
                          WHEN jsonb_typeof(m.data -> e.k) <> 'array'
                            OR m.data -> e.k IS NULL
                            THEN jsonb_build_array(e.v)
                          WHEN (m.data -> e.k) @> jsonb_build_array(e.v)
                            THEN m.data -> e.k
                          ELSE (m.data -> e.k) || jsonb_build_array(e.v)
                        END), '{}'::jsonb)
                 FROM jsonb_each(COALESCE(p_partiel, '{}'::jsonb)) AS e(k, v))
             ELSE COALESCE(p_partiel, '{}'::jsonb)
           END
     WHERE m.id = p_message_id
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM maj);
$$;

-- ── 4. Bascule d'une valeur dans une liste de messages.data ────────────────
-- Rend l'état APRÈS bascule (`true` = la valeur est dans la liste), `null`
-- si aucune ligne n'a été modifiée. Pour `starredBy`.
CREATE OR REPLACE FUNCTION public.basculer_dans_liste_message(
  p_message_id TEXT,
  p_cle TEXT,
  p_valeur TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  UPDATE messages m
     SET data = jsonb_set(
           COALESCE(m.data, '{}'::jsonb),
           ARRAY[p_cle],
           CASE
             WHEN jsonb_typeof(m.data -> p_cle) = 'array' AND (m.data -> p_cle) ? p_valeur
               THEN (m.data -> p_cle) - p_valeur
             WHEN jsonb_typeof(m.data -> p_cle) = 'array'
               THEN (m.data -> p_cle) || to_jsonb(p_valeur)
             ELSE jsonb_build_array(p_valeur)
           END)
   WHERE m.id = p_message_id
  RETURNING (data -> p_cle) ? p_valeur;
$$;

-- ── 5. Après l'envoi d'un message : aperçu, pastilles, date ────────────────
-- Remplace « lire data, incrémenter unreadCount en mémoire, réécrire ». Les
-- pastilles de tous les participants sauf l'expéditeur — l'APPELANT, lu dans
-- le jeton, jamais fourni par le client — sont incrémentées dans l'UPDATE.
-- Un aperçu de type `system` n'incrémente aucune pastille.
-- `last_message_at` prend l'heure du serveur, comme `messages.created_at`
-- (20261004090000). [p_apercu] porte `lastMessage` (absent si le message est
-- chiffré de bout en bout) et `lastMessageType`.
CREATE OR REPLACE FUNCTION public.apres_envoi_message(
  p_conversation_id TEXT,
  p_apercu JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid TEXT := public.firebase_uid();
  v_maj INTEGER;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'apres_envoi_message : non authentifié' USING ERRCODE = '42501';
  END IF;

  UPDATE conversations c
     SET last_message_at = now(),
         data = (COALESCE(c.data, '{}'::jsonb)
                   - 'lastMessageDeleted' - 'lastMessageExpired')
                || COALESCE(p_apercu, '{}'::jsonb)
                || jsonb_build_object(
                     'lastMessageSenderId', v_uid,
                     'lastMessageStatus', 'sent',
                     'lastMessageReadBy', jsonb_build_array(v_uid),
                     'lastMessageDeliveredTo', jsonb_build_array(v_uid),
                     'unreadCount',
                       CASE WHEN jsonb_typeof(c.data -> 'unreadCount') = 'object'
                            THEN c.data -> 'unreadCount' ELSE '{}'::jsonb END
                       || COALESCE((
                            SELECT jsonb_object_agg(
                                     p.pid,
                                     COALESCE(
                                       CASE WHEN jsonb_typeof(c.data -> 'unreadCount' -> p.pid) = 'number'
                                            THEN (c.data -> 'unreadCount' ->> p.pid)::numeric::integer
                                       END, 0) + 1)
                              FROM unnest(c.participant_ids) AS p(pid)
                             WHERE p.pid IS DISTINCT FROM v_uid
                               -- Un message système n'est pas du courrier :
                               -- la pastille de personne ne bouge (même
                               -- règle que repere_de_lecture).
                               AND COALESCE(p_apercu ->> 'lastMessageType', '')
                                     <> 'system'
                          ), '{}'::jsonb))
   WHERE c.id = p_conversation_id;

  GET DIAGNOSTICS v_maj = ROW_COUNT;
  RETURN v_maj > 0;
END;
$$;

REVOKE ALL ON FUNCTION public.fusionner_donnees_conversation(TEXT, JSONB, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.retirer_cle_donnees_conversation(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fusionner_donnees_message(TEXT, JSONB, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.basculer_dans_liste_message(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.apres_envoi_message(TEXT, JSONB) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fusionner_donnees_conversation(TEXT, JSONB, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retirer_cle_donnees_conversation(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fusionner_donnees_message(TEXT, JSONB, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.basculer_dans_liste_message(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apres_envoi_message(TEXT, JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
