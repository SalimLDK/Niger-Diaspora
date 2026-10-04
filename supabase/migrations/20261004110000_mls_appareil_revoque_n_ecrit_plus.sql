-- MLS : un appareil révoqué ne publie plus rien — ni commit, ni message.
--
-- LE DÉFAUT
-- Les policies d'insertion de `mls_commits` et `mls_messages`
-- (20260915120000) vérifient que `sender_device_id` appartient à l'appelant,
-- jamais qu'il n'est pas RÉVOQUÉ. Révoquer un téléphone volé (`revoked_at`
-- posé depuis un autre appareil) laissait donc la session du voleur, encore
-- valide, publier :
--   · des messages, au nom du propriétaire ;
--   · surtout un COMMIT EXTERNE depuis l'arbre public
--     (`conversations.mls_group_info`) — c'est-à-dire se faire rentrer dans
--     le groupe dont on venait de le retirer, et lire la suite.
-- La garde côté client (`_refuserSiRevoque`, 6bb8cdb4) ne vaut que pour un
-- client honnête : le voleur n'en a pas besoin.
--
-- LE CORRECTIF
-- Les deux policies exigent `d.revoked_at IS NULL`. Noms conservés
-- (`ALTER POLICY`) : rien d'autre ne change de ce qu'elles autorisent.
--
-- Hors champ, noté : la policy d'insertion de `mls_welcomes` ne vérifie
-- aucun appareil émetteur (défaut M8 de l'audit du 2026-10-03).
--
-- Banc : tools/rls_tests/mls_appareil_revoque_n_ecrit_plus.sql

ALTER POLICY "mls_commits: publier depuis son appareil" ON public.mls_commits
  WITH CHECK (
    public.is_conversation_participant(conversation_id)
    AND EXISTS (
      SELECT 1 FROM public.mls_devices d
      WHERE d.id = sender_device_id
        AND d.user_id = (SELECT firebase_uid())
        AND d.revoked_at IS NULL
    )
  );

ALTER POLICY "mls_messages: emettre depuis son appareil" ON public.mls_messages
  WITH CHECK (
    sender_id = (SELECT firebase_uid())
    AND public.is_conversation_participant(conversation_id)
    AND EXISTS (
      SELECT 1 FROM public.mls_devices d
      WHERE d.id = sender_device_id
        AND d.user_id = (SELECT firebase_uid())
        AND d.revoked_at IS NULL
    )
  );
