-- La notification gardait une copie du ciphertext que le message avait perdue.
--
-- CE QUE ÇA DÉFAIT
-- `20260916001500_mls_supprimer_pour_tous_efface_vraiment` vide
-- `mls_messages.ciphertext` pour que « le serveur cesse de servir le
-- ciphertext » — c'est sa phrase, et c'est la promesse du § 6.3 du plan. La
-- purge des éphémères (`20260915234500`) fait le même geste à l'expiration.
--
-- Les deux oubliaient la **seconde copie**. Le trigger `mls_notify_recipients`
-- recopie le ciphertext dans `notifications.data->>'mlsCiphertext'` pour que
-- l'appareil reconstruise l'aperçu (§ 8), et cette ligne-là n'était touchée
-- par personne. Or elle est lisible, par PostgREST, par exactement celui qui
-- sait la déchiffrer : la policy `notifications_own` la rend à son
-- destinataire, et c'est un membre du groupe à cet epoch.
--
-- Donc : « supprimer pour tous » vidait la colonne, et le contenu restait à un
-- `select` de distance pour le destinataire qui n'avait pas encore rattrapé —
-- c'est-à-dire précisément le cas que la suppression visait. Mesuré le
-- 2026-09-15 avant correction : **8 messages supprimés sur 50 notifications
-- MLS portaient encore leur ciphertext**, dont 7 déjà vidés côté
-- `mls_messages`.
--
-- POURQUOI UN DÉCLENCHEUR, ET PAS UN APPEL DANS LES DEUX FONCTIONS
-- Il y a déjà deux endroits qui effacent un ciphertext, et il y en aura un
-- troisième. Les patcher un par un, c'est se donner rendez-vous avec celui
-- qu'on oubliera. Le déclencheur est posé là où le ciphertext disparaît
-- vraiment — `UPDATE OF ciphertext` — donc il couvre les deux fonctions
-- existantes sans les modifier, et couvrira la suivante sans rien faire.
--
-- CE QUI N'EST PAS FAIT ICI, ET POURQUOI
-- L'édition **ne marque pas la notification lue** : le message existe
-- toujours, et une notification non lue à juste titre ne doit pas disparaître
-- parce que son auteur a corrigé une faute. Elle perd seulement sa copie du
-- ciphertext, qui porte le texte d'AVANT — c'est le point de l'édition.
--
-- La copie n'est pas non plus retirée après livraison : ce serait une règle de
-- rétention, pas de cycle de vie, et elle casserait le renvoi d'un push par
-- FCM. Consigné, pas fait.

-- ---------------------------------------------------------------------------
-- Le geste, en un seul endroit.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.mls_notifications_oublier(
  p_message_ids TEXT[],
  p_marquer_lues BOOLEAN DEFAULT TRUE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE notifications n
     SET data    = n.data - 'mlsCiphertext',
         is_read = CASE WHEN p_marquer_lues THEN TRUE ELSE n.is_read END
   WHERE n.type IN ('message', 'messageReaction')
     AND n.data->>'messageId' = ANY (p_message_ids)
     -- Ne réécrit que ce qui change : une notification déjà nettoyée et déjà
     -- lue ne repart pas dans le flux temps réel des clients connectés.
     AND (n.data ? 'mlsCiphertext' OR (p_marquer_lues AND NOT n.is_read));
END;
$$;

REVOKE ALL ON FUNCTION private.mls_notifications_oublier(TEXT[], BOOLEAN)
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.mls_notifications_oublier(TEXT[], BOOLEAN) IS
  'Retire la copie du ciphertext portée par les notifications de ces messages MLS, et les marque lues sauf demande contraire.';

-- ---------------------------------------------------------------------------
-- Suppression dure. Par INSTRUCTION : effacer une conversation efface ses
-- messages en cascade, et un déclencheur par ligne relirait `notifications`
-- autant de fois qu'il y a de messages (même raison que
-- `trg_notifications_messages_supprimes` sur la table legacy).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.trg_mls_notifications_supprimes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM private.mls_notifications_oublier(
    ARRAY(SELECT o.id::text FROM mls_messages_supprimes o)
  );
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  -- Un nettoyage de notifications ne fait pas échouer une suppression.
  RAISE WARNING 'trg_mls_notifications_supprimes: %', SQLERRM;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_mls_notifications_supprimes()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_mls_notifications_supprimes ON public.mls_messages;
CREATE TRIGGER trg_mls_notifications_supprimes
  AFTER DELETE ON public.mls_messages
  REFERENCING OLD TABLE AS mls_messages_supprimes
  FOR EACH STATEMENT EXECUTE FUNCTION private.trg_mls_notifications_supprimes();

-- ---------------------------------------------------------------------------
-- Suppression douce, vidage du ciphertext, édition.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.trg_mls_notifications_message_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supprime BOOLEAN;
  v_vide     BOOLEAN;
  v_edite    BOOLEAN;
BEGIN
  v_supprime := COALESCE(NEW.is_deleted, FALSE) AND NOT COALESCE(OLD.is_deleted, FALSE);
  v_vide     := octet_length(NEW.ciphertext) = 0 AND octet_length(OLD.ciphertext) > 0;
  v_edite    := NEW.edited_at IS NOT NULL AND NEW.edited_at IS DISTINCT FROM OLD.edited_at;

  IF v_supprime OR v_vide THEN
    PERFORM private.mls_notifications_oublier(ARRAY[NEW.id::text]);
  ELSIF v_edite THEN
    -- La copie porte le texte d'avant la correction : elle part. La
    -- notification, elle, reste non lue si elle l'était.
    PERFORM private.mls_notifications_oublier(ARRAY[NEW.id::text], FALSE);
  END IF;

  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'trg_mls_notifications_message_change: %', SQLERRM;
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.trg_mls_notifications_message_change()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_mls_notifications_message_change ON public.mls_messages;
CREATE TRIGGER trg_mls_notifications_message_change
  AFTER UPDATE OF is_deleted, ciphertext, edited_at ON public.mls_messages
  FOR EACH ROW EXECUTE FUNCTION private.trg_mls_notifications_message_change();

-- ---------------------------------------------------------------------------
-- Rattrapage : les copies déjà orphelines en base.
-- ---------------------------------------------------------------------------
SELECT private.mls_notifications_oublier(
  ARRAY(
    SELECT m.id::text
      FROM public.mls_messages m
     WHERE COALESCE(m.is_deleted, FALSE) OR octet_length(m.ciphertext) = 0
  )
);

-- Et celles dont le message a entièrement disparu de la table : plus rien ne
-- les rattachera jamais, et elles portent encore de quoi lire le contenu.
UPDATE public.notifications n
   SET data = n.data - 'mlsCiphertext', is_read = TRUE
 WHERE n.type IN ('message', 'messageReaction')
   AND n.data ? 'mlsCiphertext'
   AND NOT EXISTS (
     SELECT 1 FROM public.mls_messages m WHERE m.id::text = n.data->>'messageId'
   );
