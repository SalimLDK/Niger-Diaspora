-- `public.orders` : plus de création ni de mise à jour par une partie.
--
-- Dernière pièce de la chaîne de paiement (voir le durcissement de
-- `firestore.rules` du même jour, et les douze collections fermées).
--
-- CE QUI ÉTAIT OUVERT.
--
--   · `orders_insert_buyer` n'exigeait que `firebase_uid() = buyer_id`. Le
--     client posait donc `total_amount`, `unit_price`, `status`,
--     `escrow_status` et `seller_id` à sa guise — le prix n'était jamais relu
--     depuis `products`.
--   · `orders_update_parties` est un `FOR UPDATE` **sans `WITH CHECK`**, sans
--     restriction de colonnes et sans déclencheur de garde : l'acheteur comme
--     le vendeur pouvaient réécrire n'importe quelle colonne, montant et
--     statut de séquestre compris.
--
-- Le commentaire de `initial_schema.sql:288` affirme que les parties peuvent
-- « uniquement annuler ». Aucun code ne l'imposait.
--
-- PERSONNE N'EN DÉPEND. Mesuré le 2026-09-21 :
--
--   · `public.orders` est VIDE (0 ligne), comme `products`, `transactions`,
--     `escrow_transactions` et le reste de la chaîne ;
--   · `lib/` ne crée AUCUNE commande Supabase. Ses trois seules références
--     sont dans le back-office (`admin_provider.dart`) : deux lectures, et
--     une écriture qui ne touche que les six colonnes de litige ;
--   · le parcours marketplace vit dans FIRESTORE
--     (`marketplace_remote_datasource.dart`), fermé le même jour ;
--   · le drapeau `marketplace` est fermé.
--
-- CE QUE ÇA LAISSE. La lecture par les parties ne bouge pas. Le back-office
-- garde sa résolution de litige, mais réservée aux administrateurs et limitée
-- aux six colonnes qu'il écrit vraiment — la restriction par colonnes est un
-- GRANT, pas une policy : le RLS filtre des lignes, jamais des colonnes.
--
-- CORRIGÉ AU PASSAGE, ET C'EST DÉLIBÉRÉ : le back-office ne pouvait NI lire
-- les commandes, NI résoudre un litige. `orders_select_parties` exige d'être
-- acheteur ou vendeur, et un administrateur ne l'est pas. Pour la lecture
-- (`admin_provider.dart:1327`) c'est évident ; pour l'écriture ça l'est
-- moins — Postgres applique les policies de SELECT aux lignes qu'un
-- `UPDATE … WHERE` doit d'abord retrouver, donc la résolution de litige
-- touchait 0 ligne, en silence. Mesuré : le banc échoue sur ce cas AVANT
-- comme après, tant qu'aucune policy d'administration n'existe.
--
-- D'où `orders_select_admin`. C'est un élargissement — un administrateur voit
-- désormais toutes les commandes — mais c'est la raison d'être du back-office,
-- et la table est vide. Sans elle, la seule écriture cliente qu'on garde
-- serait morte-née.
--
-- Rouvrir demandera un séquestre tenu par le serveur : prix relu depuis
-- `products`, paiement confirmé auprès de Stripe, et les passages à `paid` et
-- `completed` réservés à une fonction.
--
-- Banc : tools/rls_tests/orders_ecriture_fermee.sql

REVOKE ALL ON public.orders FROM anon;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.orders FROM authenticated;

-- Les six colonnes que le back-office écrit, et elles seules.
GRANT UPDATE (
  dispute_resolution, dispute_note, dispute_resolved_by,
  dispute_resolved_at, is_in_dispute, has_dispute
) ON public.orders TO authenticated;

DROP POLICY IF EXISTS orders_insert_buyer  ON public.orders;
DROP POLICY IF EXISTS orders_update_parties ON public.orders;

CREATE POLICY orders_update_litige_admin ON public.orders
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- La lecture par les parties reste, mais pour un compte connecté seulement.
ALTER POLICY orders_select_parties ON public.orders TO authenticated;

-- Sans elle, `orders_update_litige_admin` ne trouverait aucune ligne : voir
-- l'explication en tête.
CREATE POLICY orders_select_admin ON public.orders
  FOR SELECT TO authenticated
  USING (public.is_admin());
