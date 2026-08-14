-- `has_seen_onboarding`, `has_seen_coach_marks`, `has_given_consent`,
-- `consent_date` et `profile_config_complete` existent deja en production sur
-- `public.users`, mais aucune migration du depot ne les documentait -- derive
-- detectee en corrigeant `OnboardingRemoteDataSourceImpl`, qui lisait/ecrivait
-- ces drapeaux sur Cloud Firestore (`users/{uid}`) au lieu de cette table.
-- Firestore etait un reliquat de l'architecture pre-Supabase : ce document
-- n'est jamais lu ni ecrit par le reste de l'app, donc l'etage "serveur" de
-- l'onboarding ne servait a rien en pratique -- seul le drapeau local
-- (efface a chaque reinstallation) faisait foi.
--
-- `IF NOT EXISTS` : sans effet la ou les colonnes existent deja (production),
-- les cree sur tout environnement qui ne les aurait pas encore.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS has_seen_onboarding boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_seen_coach_marks boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_given_consent boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS consent_date timestamptz,
  ADD COLUMN IF NOT EXISTS profile_config_complete boolean NOT NULL DEFAULT false;
