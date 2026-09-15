-- Réparer ce que `20260915230000` a cassé : plus aucune réaction ne passait.
--
-- CE QUI S'EST PASSÉ
-- Le durcissement des droits a remplacé l'UPDATE de table par un UPDATE
-- colonne par colonne — `GRANT UPDATE (emoji, created_at)` pour les
-- réactions. C'est juste sur le papier, et faux en pratique : PostgREST
-- traduit un `upsert` en
--
--     INSERT … ON CONFLICT (message_id, user_id) DO UPDATE
--        SET message_id = excluded.message_id,
--            user_id    = excluded.user_id,
--            emoji      = excluded.emoji, …
--
-- Il réécrit **toutes** les colonnes envoyées, y compris celles de la clé
-- primaire, qu'il faut bien envoyer pour pouvoir insérer. Sans droit dessus :
-- 42501, et la réaction disparaît.
--
-- POURQUOI PERSONNE NE L'A VU
-- Le provider de réactions applique le changement à l'écran, puis le **retire
-- en silence** si l'appel échoue (`catch` qui restaure l'état). Sur le
-- téléphone, ça se lit comme « le tap n'a pas pris ». Rien dans les journaux,
-- rien dans `mls_diagnostics`. Trouvé le 2026-09-15 en posant une réaction
-- sur un vrai message et en constatant la table vide.
--
-- LE CHOIX FAIT ICI
-- Deux formes de conflit, deux traitements :
--
-- - **Les réactions ont une charge qui change** (l'emoji) : le conflit doit
--   écraser. On accorde donc l'UPDATE sur les quatre colonnes, et on resserre
--   la policy — jusqu'ici elle ne vérifiait que `user_id`, ce qui laissait
--   déplacer sa propre réaction vers **n'importe quel** message, y compris
--   d'une conversation où l'on n'est pas. Le `WITH CHECK` exige maintenant
--   d'être participant du message visé.
-- - **Favoris, masquages et mentions n'ont aucune charge** : la ligne existe
--   ou n'existe pas. Côté client, leur `upsert` passe en
--   `ON CONFLICT DO NOTHING` (`ignoreDuplicates`), qui ne demande aucun droit
--   d'UPDATE. Leurs droits restent donc fermés, et c'est le client qui
--   s'aligne sur eux — pas l'inverse.

GRANT UPDATE (message_id, user_id, emoji, created_at)
  ON public.mls_message_reactions TO authenticated;

DROP POLICY IF EXISTS "mls_message_reactions: changer la sienne" ON public.mls_message_reactions;
CREATE POLICY "mls_message_reactions: changer la sienne" ON public.mls_message_reactions
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (user_id = (SELECT firebase_uid()))
  WITH CHECK (
    user_id = (SELECT firebase_uid())
    AND public.mls_message_participant(message_id)
  );
