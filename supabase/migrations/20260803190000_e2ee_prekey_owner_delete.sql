-- =============================================================================
-- Restreindre la suppression des prékeys à leur propriétaire.
--
-- Problème corrigé
-- ----------------
-- La policy « e2ee_one_time_prekeys: authenticated delete » avait pour
-- condition littéralement `true`, sans aucune clause de propriété — alors que
-- l'INSERT de la même table est bien restreint au propriétaire. N'importe quel
-- compte authentifié pouvait donc supprimer les prékeys de n'importe qui.
--
-- L'effet n'est pas une panne, et c'est précisément ce qui le rend gênant :
-- une fois le vivier d'une cible vidé, ses correspondants continuent d'ouvrir
-- des sessions, mais sans DH4 — X3DH ne calcule ce quatrième échange que si
-- une prékey à usage unique est disponible (messaging_e2ee_service.dart:212).
-- On perd alors la protection du message initial contre une compromission
-- ultérieure de la signed pre-key, et ce message devient rejouable. C'est donc
-- un moyen simple et silencieux de dégrader le chiffrement d'une personne
-- choisie, sans que rien ne le signale.
--
-- Pourquoi ça ne casse pas la consommation normale
-- ------------------------------------------------
-- La prékey d'un destinataire est consommée par l'EXPÉDITEUR, ce qui semblait
-- exiger une suppression par un tiers. Vérifié avant écriture : la RPC
-- consume_one_time_prekey est SECURITY DEFINER, elle contourne donc RLS et
-- reste pleinement fonctionnelle après ce resserrement.
--
-- Côté application, la seule suppression directe est celle de
-- _publishOneTimePreKeysToSupabase (key_manager_service.dart), qui purge ses
-- propres clés en filtrant sur user_id + device_id avant de republier un lot.
-- Elle reste autorisée.
--
-- La policy est renommée « owner delete » pour s'aligner sur « owner insert »,
-- l'ancien nom décrivant une permission qui n'existe plus.
-- =============================================================================

DROP POLICY IF EXISTS "e2ee_one_time_prekeys: authenticated delete"
  ON e2ee_one_time_prekeys;
DROP POLICY IF EXISTS "e2ee_one_time_prekeys: owner delete"
  ON e2ee_one_time_prekeys;

CREATE POLICY "e2ee_one_time_prekeys: owner delete" ON e2ee_one_time_prekeys
  AS PERMISSIVE
  FOR DELETE
  TO public
  USING (user_id = (SELECT firebase_uid()));
