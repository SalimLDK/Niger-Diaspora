-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  CIBLE — PHASE 6 DU PLAN MLS. NE PAS APPLIQUER EN L'ÉTAT.               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- Ce fichier n'est **pas** dans `supabase/migrations/` et c'est délibéré :
-- `db push` applique tout ce qui s'y trouve, y compris lancé par quelqu'un qui
-- ne sait pas ce que ce fichier contient. Même convention que
-- `database.rules.strict-cible.json` pour RTDB.
--
-- Pour l'appliquer le jour venu : en faire une migration datée, et la pousser
-- comme les autres.
--
--
-- CE QUE ÇA FAIT
-- Retire à `authenticated` le droit d'insérer dans `messages`. À partir de
-- là, aucun client — à jour ou non — ne peut plus écrire un message en clair.
-- C'est la bascule irréversible **du produit** : tout le trafic passe à MLS.
--
-- Techniquement, en revanche, ce n'est PAS irréversible : une seule ligne
-- défait tout (voir « ANNULATION » en bas). Ce qui ne se défait pas, c'est
-- `conversations.mls_since`, posé au premier message chiffré de chaque
-- conversation — et ça, c'est déjà le cas dès que le drapeau s'ouvre.
--
--
-- ── LES TROIS CONDITIONS, ET LEUR ÉTAT AU 2026-09-15 ──────────────────────
--
-- 1. ❌ **Un verrou de version minimale doit exister.** Il n'y en a pas.
--    `CoordinateurMiseAJour` (`lib/core/services/mise_a_jour_service.dart`)
--    affiche un bandeau **explicitement non bloquant** — « jamais bloquant »
--    est écrit dans le code. Rien n'empêche un vieux build de tourner. Le
--    gel le casserait sans qu'il ait jamais été prévenu, et sans qu'il
--    puisse rien faire : le trigger lève `check_violation` avec « mettez
--    l'application à jour », que l'écran rend en erreur générique.
--
-- 2. ❌ **Le délai doit avoir couru.** Il n'a pas commencé :
--    `DERNIERE_VERSION_APP` vaut `1.2.1+19`, soit exactement la version du
--    `pubspec.yaml`. Le bandeau ne s'est donc jamais affiché pour personne.
--
-- 3. ❌ **Le trafic doit être passé à MLS.** Mesuré le 2026-09-15 sur la
--    production : `messages` = 118 lignes dont **106 des trente derniers
--    jours** ; `mls_messages` = **0** ; conversations basculées = **0**.
--    Appliquer le gel aujourd'hui arrêterait 100 % de la messagerie et
--    n'activerait rien — le drapeau `featureFlags.mlsMessages` est fermé.
--
-- Les trois se vérifient d'une requête (`tools/mls_banc/gel_messages.sql`
-- affiche le tableau de bord avant de jouer le gel).
--
--
-- ── POURQUOI SEULEMENT `INSERT` ───────────────────────────────────────────
-- `UPDATE` et `DELETE` restent accordés, et ce n'est pas un oubli :
-- l'historique legacy reste **lisible et amendable**. Réagir à un vieux
-- message, le masquer pour soi, le supprimer pour tous — tout ça écrit dans
-- `messages.data` d'une ligne qui existe déjà. Retirer `UPDATE` gèlerait
-- aussi ces gestes-là, sur un historique que les gens continuent de
-- consulter des mois.

BEGIN;

REVOKE INSERT ON public.messages FROM authenticated;

-- `anon` n'a jamais eu à écrire ici ; on le dit quand même, une fois pour
-- toutes (un `GRANT` ne restreint rien sous Supabase — cf. CLAUDE.md).
REVOKE INSERT ON public.messages FROM anon;

COMMIT;


-- ── LA SUITE, PLUS TARD ET SÉPARÉMENT ─────────────────────────────────────
-- Une fois le gel tenu quelques semaines sans incident, ces déclencheurs
-- n'ont plus de raison d'être : aucun INSERT ne peut plus les réveiller. Les
-- retirer plus tôt ne gagnerait rien et enlèverait un filet — le premier
-- refuse déjà, à lui seul, les écritures en clair dans une conversation
-- basculée.
--
--   DROP TRIGGER messages_refuse_conversation_mls_trg ON public.messages;
--   DROP TRIGGER trg_notify_recipients_on_message_insert ON public.messages;
--
-- Le reste du démantèlement (les cinq tables `e2ee_*`, les 8 608 lignes de
-- `lib/core/services/e2ee/`, `decrypt_aes_fallback`) est la phase 10, et
-- attend la purge annoncée (décision H).


-- ── ANNULATION ────────────────────────────────────────────────────────────
-- Si le gel se révèle prématuré, une ligne suffit à rouvrir l'écriture :
--
--   GRANT INSERT ON public.messages TO authenticated;
--
-- Les conversations déjà basculées, elles, ne reviennent pas : `mls_since`
-- ne se remet jamais à NULL, et c'est voulu — un message chiffré ne peut pas
-- être relu par un chemin en clair.
