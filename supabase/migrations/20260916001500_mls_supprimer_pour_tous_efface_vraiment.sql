-- « Supprimer pour tous » laissait le ciphertext sur le serveur.
--
-- CE QUE LE PLAN PROMET, ET CE QUI SE PASSAIT
-- Le tableau du § 6.3 dit, pour « Supprimer pour tous » : `is_deleted` +
-- `deleted_at`, « le serveur cesse de servir le ciphertext ». Il ne cessait
-- pas. `MlsMetadonnees.supprimerPourTous` posait les deux colonnes et rien
-- d'autre, et il ne pouvait pas faire mieux : `UPDATE` n'est accordé à
-- `authenticated` que sur `expires_at, deleted_at, is_deleted, edited_at` —
-- pas sur `ciphertext`, et c'est très bien ainsi, cette restriction existe
-- pour que l'expéditeur ne puisse pas réécrire son propre message après coup.
--
-- Résultat : quelqu'un demandait la suppression pour tous, l'écran obéissait,
-- et le contenu restait en base. Un destinataire qui n'avait pas encore
-- rattrapé pouvait encore le déchiffrer.
--
-- POURQUOI UNE FONCTION, ET PAS UN DROIT DE PLUS
-- Accorder `UPDATE (ciphertext)` rouvrirait exactement le trou qu'on vient de
-- fermer. Une fonction `SECURITY DEFINER` fait le geste précis — vider — sans
-- donner le moyen d'écrire n'importe quoi.
--
-- Le vidage suit la purge des éphémères (`20260915234500`), qui pose déjà
-- `ciphertext = '\x'` : la colonne est `NOT NULL`, on vide au lieu d'annuler,
-- et le client ne tente plus de déchiffrer dès que `is_deleted` est vrai.
--
-- ELLE REND L'IDENTIFIANT, ET C'EST LE POINT
-- Un `update` refusé par le RLS réussit avec zéro ligne, sans erreur. Ce dépôt
-- l'a déjà payé avec une révocation d'appareil qui mentait. La fonction rend
-- donc l'identifiant touché, ou rien — et l'appelant lève quand il ne reçoit
-- rien.

CREATE OR REPLACE FUNCTION public.mls_supprimer_pour_tous(p_message_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_id uuid;
BEGIN
  UPDATE public.mls_messages
     SET is_deleted = true,
         deleted_at = now(),
         ciphertext = '\x'::bytea
   WHERE id = p_message_id
     -- Réservé à l'expéditeur, comme la policy `UPDATE` de la table. La
     -- fonction étant `SECURITY DEFINER`, elle passe outre le RLS : la
     -- condition doit donc être écrite ici, explicitement.
     AND sender_id = public.firebase_uid()
  RETURNING id INTO v_id;

  RETURN v_id;  -- NULL si rien n'a été touché : l'appelant doit s'en émouvoir.
END;
$function$;

COMMENT ON FUNCTION public.mls_supprimer_pour_tous(uuid) IS
  'Supprime pour tous un message MLS : pose is_deleted/deleted_at ET vide le ciphertext. Réservée à l''expéditeur. Rend l''id touché, ou NULL.';

-- Un GRANT n'enlève rien : révoquer d'abord, pour les deux rôles.
REVOKE ALL ON FUNCTION public.mls_supprimer_pour_tous(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mls_supprimer_pour_tous(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.mls_supprimer_pour_tous(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.mls_supprimer_pour_tous(uuid) TO authenticated;
