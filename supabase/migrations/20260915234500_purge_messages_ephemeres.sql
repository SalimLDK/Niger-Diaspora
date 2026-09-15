-- Messages éphémères : la purge qui n'a jamais existé.
--
-- CE QUI MANQUAIT
-- L'écran de réglage écrivait `conversations.data->>'autoDeleteAfterSeconds'`,
-- `MessageModel.expiresAt` se sérialisait, et entre les deux : rien. Le
-- datasource Supabase — le seul branché en production — ne lisait jamais le
-- minuteur à l'envoi, et aucun balayage ne supprimait quoi que ce soit. Seul
-- l'ancien datasource Firestore posait `expiresAt`, dans cinq copies du même
-- calcul, dont aucune n'a été reportée au portage. Activer le minuteur
-- n'avait donc aucun effet observable, et rien ne le disait.
--
-- CE QUE LA PURGE FAIT — ET NE FAIT PAS
-- Elle pose une **pierre tombale**, elle ne supprime pas la ligne : mêmes
-- marques que « supprimer pour tout le monde » (`is_deleted`,
-- `deletedForEveryone`, contenu vidé), plus `expiredAt` pour distinguer
-- l'échéance d'une suppression décidée. Le fil garde ainsi sa continuité et
-- le temps réel propage la disparition comme il propage déjà une suppression
-- — un DELETE, lui, ne réveille aucun écran ouvert.
--
-- CE QU'ELLE NE PEUT PAS FAIRE DISPARAÎTRE RÉTROACTIVEMENT
-- Au 2026-09-15, avant cette migration : 0 conversation sur 19 porte
-- `autoDeleteAfterSeconds`, 0 message sur 118 porte `expiresAt`, et
-- `mls_messages` est vide. Aucune ligne existante n'a d'échéance, donc aucune
-- ne peut expirer. Le minuteur ne mordra que sur les messages envoyés après
-- ce correctif, dans une conversation où quelqu'un l'aura explicitement
-- activé. C'est la condition qui rendait le déploiement sûr.
--
-- LES DEUX TABLES N'ONT PAS LA MÊME FORME
-- `messages` (legacy) n'a **pas** de colonne `expires_at` : tout vit dans le
-- JSONB `data`, et l'échéance s'y lit en `data->>'expiresAt'`. `mls_messages`
-- a la colonne, posée par 20260915120000 sans que personne ne l'écrive.

-- ── Ce qu'on balaie, et rien d'autre ───────────────────────────────────────
-- Index PARTIELS : leur prédicat fait tout le travail. Les messages
-- éphémères encore vivants sont une poignée de lignes ; l'index les isole du
-- reste de la table sans avoir à indexer une expression de date, que
-- PostgreSQL refuserait de toute façon (`text` → `timestamptz` n'est pas
-- immuable, il dépend du fuseau de la session).

CREATE INDEX IF NOT EXISTS messages_ephemeres_idx
  ON public.messages ((data->>'expiresAt'))
  WHERE NOT is_deleted AND data ? 'expiresAt';

CREATE INDEX IF NOT EXISTS mls_messages_ephemeres_idx
  ON public.mls_messages (expires_at)
  WHERE NOT is_deleted AND expires_at IS NOT NULL;

-- ── La purge ───────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.purger_messages_expires()
RETURNS TABLE (legacy integer, mls integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_maintenant timestamptz := now();
  v_legacy integer := 0;
  v_mls    integer := 0;
BEGIN
  -- 1. Legacy. L'échéance est du texte dans un JSONB : le garde `~` écarte
  --    toute valeur qui n'a pas la forme ISO-8601 écrite par le client. Sans
  --    lui, une seule valeur mal formée ferait échouer le cast — donc toute
  --    la purge, pour tout le monde, en silence côté application.
  WITH expires AS (
    SELECT m.id, m.data
      FROM public.messages m
     WHERE NOT m.is_deleted
       AND m.data ? 'expiresAt'
       AND m.data->>'expiresAt' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
       AND (m.data->>'expiresAt')::timestamptz <= v_maintenant
  ), pose AS (
    UPDATE public.messages m
       SET is_deleted = true,
           -- Mêmes champs que `deleteMessageForEveryone` côté client : le
           -- contenu, mais aussi l'aperçu de partage et la clé du média
           -- chiffré. Laisser la clé rendrait le blob Storage encore
           -- ouvrable ; laisser l'aperçu laisserait titre, extrait et URL
           -- cible en base, ce qui a déjà survécu à une suppression une fois.
           data = (e.data
                     - 'content'
                     - 'fileUrl'
                     - 'thumbnailUrl'
                     - 'encAnnexes'
                     - 'encMedia'
                     - 'postData'
                     - 'eventData'
                     - 'productData'
                     - 'linkPreviewData'
                     - 'replyToMessageData'
                     - 'audioWaveform')
                  || jsonb_build_object(
                       'content', '',
                       'deletedForEveryone', true,
                       'deletedAt', to_char(v_maintenant AT TIME ZONE 'UTC',
                                            'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
                       -- Ce qui distingue « a expiré » de « a été supprimé ».
                       'expiredAt', to_char(v_maintenant AT TIME ZONE 'UTC',
                                            'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))
      FROM expires e
     WHERE m.id = e.id
    RETURNING m.id, m.conversation_id, m.created_at
  ),
  -- L'aperçu de la liste de discussions, dans la MÊME instruction : un CTE
  -- n'existe pas au-delà d'elle.
  --
  -- `conversations.data->>'lastMessage'` porte le texte du dernier message
  -- **en clair** (c'est `_updateConversationLastMessage` qui l'y écrit).
  -- Vider la bulle sans le vider laisserait le message expiré parfaitement
  -- lisible une ligne plus haut, dans la liste des discussions — la fonction
  -- se dirait accomplie pendant que son contenu reste à l'écran.
  --
  -- `last_message_at` vient du `created_at` du message : leur égalité
  -- identifie le dernier message sans dépendre de `last_message_id`, que ce
  -- chemin d'écriture ne renseigne pas.
  derniers AS (
    SELECT conversation_id, max(created_at) AS quand
      FROM pose GROUP BY conversation_id
  ), apercu AS (
    UPDATE public.conversations c
       SET data = c.data || jsonb_build_object('lastMessage', '')
      FROM derniers d
     WHERE c.id = d.conversation_id
       AND c.last_message_at = d.quand
    RETURNING c.id
  )
  SELECT count(*) INTO v_legacy FROM pose;

  -- 2. MLS. Le ciphertext est `NOT NULL` : on le vide plutôt que de
  --    l'annuler. Le client ne tente plus de le déchiffrer dès que
  --    `is_deleted` est vrai (cf. le garde « pierre tombale » du rattrapage),
  --    sans quoi chaque rattrapage écrirait un `decrypt_failed` de plus.
  WITH pose AS (
    UPDATE public.mls_messages
       SET is_deleted = true,
           deleted_at = v_maintenant,
           ciphertext = '\x'::bytea
     WHERE NOT is_deleted
       AND expires_at IS NOT NULL
       AND expires_at <= v_maintenant
    RETURNING id
  )
  SELECT count(*) INTO v_mls FROM pose;

  RETURN QUERY SELECT v_legacy, v_mls;
END;
$function$;

-- Personne ne l'appelle depuis l'application : c'est un travail de fond, et
-- l'exposer donnerait à n'importe quel client le moyen de faire expirer les
-- messages des autres en boucle.
REVOKE ALL ON FUNCTION public.purger_messages_expires() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purger_messages_expires() FROM anon, authenticated;

-- ── Le balayage ────────────────────────────────────────────────────────────
-- Toutes les 15 minutes. Les durées proposées par l'écran de réglage sont de
-- 24 h, 7 j et 30 j : un quart d'heure de retard sur une échéance d'un jour
-- ne se voit pas, et l'écran de l'appareil, lui, sait déjà lire
-- `MessageEntity.isExpired` sans attendre le serveur.
--
-- `cron.schedule` est un upsert par nom (pg_cron ≥ 1.4) : rejouer cette
-- migration ne crée pas un second job.
SELECT cron.schedule(
  'purger-messages-expires',
  '*/15 * * * *',
  $cron$SELECT public.purger_messages_expires()$cron$
);
