-- =============================================================================
-- Reprise des drapeaux d'onboarding restes sur Firestore avant la bascule.
--
-- Jusqu'au commit `160d417` (2026-08-13 20:01 EDT, soit 2026-08-14 00:01 UTC),
-- `OnboardingRemoteDataSourceImpl` lisait et ecrivait les quatre drapeaux
-- d'onboarding sur Cloud Firestore, dans `users/{uid}`, en camelCase :
-- `hasSeenOnboarding`, `hasSeenCoachMarks`, `hasGivenConsent`,
-- `profileConfigComplete`, plus `consentDate`. Depuis ce commit il lit les
-- colonnes snake_case de `public.users`, creees avec `DEFAULT false`
-- (`20260813235500_document_onboarding_flags_drift.sql`).
--
-- Un compte qui a termine son onboarding AVANT la bascule a donc ses drapeaux
-- a `true` cote Firestore et a `false` ici. Rien ne le rattrape : le drapeau
-- local suffit tant que l'app reste installee, mais il part avec elle, et la
-- reinstallation rejoue les cinq ecrans d'intro sur un compte qui les a deja
-- vus. Ce n'est pas ce que corrige `e071491` -- celui-la empeche qu'un *echec
-- de lecture* soit pris pour « jamais vu » ; ici la lecture reussit et rend
-- un `false` sincere mais perime.
--
-- ## Ce que l'inventaire a trouve (2026-09-10)
--
-- Firestore `users/` (projet `diaspo-niger`, base par defaut, lu par l'API
-- REST) ne contient plus que **5 documents**, contre 17 lignes dans
-- `public.users`. Deux seulement portent des drapeaux d'onboarding :
--
--   * `U64HKfrjM5NwR6HO00XPKo6168z2` -- les quatre a `true`,
--     `consentDate = 2026-02-25T05:50:38.862Z`. Deja repris ici : la ligne
--     Supabase porte les quatre a `true` et **exactement le meme**
--     `consent_date`. C'est la preuve qu'une reprise Firestore -> Supabase a
--     bien eu lieu, avant la bascule du code.
--   * `czk5UoUclLOFmbRtUIZ5XYLYKo52` -- les quatre a `true`,
--     `consentDate = 2026-08-13T22:29:10.098Z`. Ligne Supabase : les quatre a
--     `false`, `consent_date` NUL.
--
-- Ce compte est ne le 2026-08-13 a 22:29:01 UTC et a fait tout son onboarding
-- dans les 90 secondes -- soit **une heure et demie avant** que `160d417` ne
-- bascule le code. Il est passe entre la reprise (deja faite) et la bascule
-- (pas encore faite) : c'est le seul, et la fenetre explique pourquoi.
--
-- Les trois autres documents Firestore (`6vL7z8i...`, `DfSyAWi...`,
-- `vQZE49d...`) ne portent aucun drapeau -- ils ne contiennent que de la
-- position, du `session_id` ou des `friendIds`. `vQZE49d...` a d'ailleurs ete
-- cree le 2026-08-14 a 00:15 UTC, soit APRES la bascule : ses drapeaux sont
-- nes directement dans Supabase. La coupure se lit dans les donnees.
--
-- Les 8 autres comptes a `false` dans `public.users` n'ont **aucun** document
-- Firestore. Firestore n'a donc rien a dire sur eux : leur `false` n'est pas
-- perime, il est simplement vrai. Aucune reprise possible, et aucune ligne
-- ecrite ici pour eux.
--
-- ## Pourquoi les drapeaux ne peuvent que monter
--
-- `or` colonne par colonne, jamais une affectation seche : un `true` deja
-- pose reste `true` quoi qu'il arrive, et rejouer la migration ne change
-- rien. `consent_date` passe par `coalesce`, donc une date deja enregistree
-- n'est jamais remplacee -- seul un NUL se remplit.
--
-- Aucun declencheur ne s'y oppose : `users_guard_admin_flags` ne se reveille
-- que si `is_admin` ou `admin_role` changent, ce que cette migration ne
-- touche pas ; `users_updated_at` se contente de dater la ligne.
--
-- ## Reserve a verifier sur appareil
--
-- `czk5UoUclLOFmbRtUIZ5XYLYKo52` a `handle = 'diaspo_ne'` et
-- `country_code = 'NE'`, mais `display_name` NUL : l'assistant de profil a
-- bien tourne le 2026-08-13, son enregistrement n'est arrive qu'en partie.
-- Monter `profile_config_complete` fait donc entrer ce compte dans l'app sans
-- nom affiche -- etat que le bandeau de completude du profil (§11f) sait
-- traiter, mais qui n'a jamais ete regarde sur un vrai telephone.
-- Consigne dans `TESTS_APPAREIL_A_FAIRE.md`.
-- =============================================================================

WITH drapeaux_firestore (
  id,
  onboarding,
  coach_marks,
  consentement,
  profil,
  date_consentement
) AS (
  VALUES (
    'czk5UoUclLOFmbRtUIZ5XYLYKo52',
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    TIMESTAMPTZ '2026-08-13 22:29:10.098+00'
  )
)
UPDATE public.users AS u
SET
  has_seen_onboarding     = u.has_seen_onboarding     OR f.onboarding,
  has_seen_coach_marks    = u.has_seen_coach_marks    OR f.coach_marks,
  has_given_consent       = u.has_given_consent       OR f.consentement,
  profile_config_complete = u.profile_config_complete OR f.profil,
  consent_date            = COALESCE(u.consent_date, f.date_consentement)
FROM drapeaux_firestore AS f
WHERE u.id = f.id;
