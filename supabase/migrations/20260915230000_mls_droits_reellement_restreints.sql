-- Les droits des tables MLS, cette fois pour de vrai.
--
-- CE QUE LE BANC A TROUVÉ, ET POURQUOI PERSONNE NE L'AVAIT VU
-- `20260915120000` écrit, en toutes lettres :
--
--     -- Le ciphertext ne se réécrit jamais : seules les métadonnées.
--     GRANT UPDATE (is_deleted, deleted_at, edited_at, expires_at) …
--
-- C'était faux en production. Supabase pose
-- `ALTER DEFAULT PRIVILEGES … GRANT ALL ON TABLES TO anon, authenticated` :
-- toute table neuve du schéma `public` naît avec **tous** les droits pour
-- `authenticated`. Un `GRANT` supplémentaire n'enlève rien — il faut
-- `REVOKE`. Les migrations MLS révoquaient bien pour `anon`, jamais pour
-- `authenticated`.
--
-- Conséquence mesurée le 2026-09-15 par le cas E3 du banc : l'expéditeur
-- pouvait **réécrire le ciphertext de son propre message**, des heures après
-- l'envoi. Le RLS ne l'en empêchait pas — il filtre des lignes, pas des
-- colonnes. Ce qui est en jeu n'est pas la confidentialité (c'est son
-- message) mais l'intégrité de ce que le serveur conserve : un fil dont
-- l'original peut être remplacé après coup ne prouve plus rien.
--
-- CE QUI RESTE OUVERT, ET N'EST PAS RÉPARÉ ICI
-- `TRUNCATE` est accordé à `authenticated` sur **101 tables** du schéma et à
-- `anon` sur 84 — même cause, le défaut Supabase. Et `TRUNCATE` **ignore le
-- RLS** : aucune policy ne le retient. Il n'est pas joignable par PostgREST,
-- qui n'expose que SELECT/INSERT/UPDATE/DELETE, donc ce n'est pas une porte
-- ouverte aujourd'hui ; ça le deviendrait au premier `security invoker` qui
-- tronque. Le corriger touche tout le schéma, bien au-delà de MLS : à
-- décider à part.

-- ── Le cœur : le ciphertext ne se réécrit pas ──────────────────────────────

REVOKE ALL ON public.mls_messages FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.mls_messages TO authenticated;
GRANT UPDATE (is_deleted, deleted_at, edited_at, expires_at)
  ON public.mls_messages TO authenticated;

-- ── Transport ──────────────────────────────────────────────────────────────

REVOKE ALL ON public.mls_commits FROM authenticated;
-- Un commit ne se modifie ni ne se retire : c'est ce qui rend l'ordre des
-- epochs arbitrable.
GRANT SELECT, INSERT ON public.mls_commits TO authenticated;

REVOKE ALL ON public.mls_welcomes FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.mls_welcomes TO authenticated;
GRANT UPDATE (consumed_at) ON public.mls_welcomes TO authenticated;

REVOKE ALL ON public.mls_key_packages FROM authenticated;
-- Aucun UPDATE : la consommation passe par `claim_key_package`, seule
-- manière d'être atomique. Deux ajouts concurrents consommeraient sinon le
-- même paquet, et le second Welcome serait indéchiffrable.
GRANT SELECT, INSERT, DELETE ON public.mls_key_packages TO authenticated;

REVOKE ALL ON public.mls_diagnostics FROM authenticated;
GRANT SELECT, INSERT ON public.mls_diagnostics TO authenticated;

-- `mls_devices` et `conversation_devices` gardent un UPDATE de table : les
-- deux sont écrites par `upsert` (INSERT … ON CONFLICT DO UPDATE), qui exige
-- le droit sur chaque colonne qu'il pose. Les restreindre colonne par colonne
-- casserait l'inscription d'un appareil — et l'échec ne se verrait qu'à la
-- connexion suivante.
REVOKE ALL ON public.mls_devices FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.mls_devices TO authenticated;

REVOKE ALL ON public.conversation_devices FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.conversation_devices TO authenticated;

-- ── Métadonnées en ligne (décision J) ──────────────────────────────────────

REVOKE ALL ON public.mls_message_receipts FROM authenticated;
-- Ni DELETE — un reçu ne se retire pas — ni déplacement d'un reçu d'un
-- message à l'autre : seules les deux dates avancent.
GRANT SELECT, INSERT ON public.mls_message_receipts TO authenticated;
GRANT UPDATE (delivered_at, read_at) ON public.mls_message_receipts TO authenticated;

REVOKE ALL ON public.mls_message_reactions FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.mls_message_reactions TO authenticated;
GRANT UPDATE (emoji, created_at) ON public.mls_message_reactions TO authenticated;

REVOKE ALL ON public.mls_message_hidden FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.mls_message_hidden TO authenticated;

REVOKE ALL ON public.mls_message_stars FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.mls_message_stars TO authenticated;

REVOKE ALL ON public.mls_message_mentions FROM authenticated;
GRANT SELECT, INSERT, DELETE ON public.mls_message_mentions TO authenticated;

-- ── Et la vue ──────────────────────────────────────────────────────────────

REVOKE ALL ON public.mls_unread_counts FROM authenticated;
GRANT SELECT ON public.mls_unread_counts TO authenticated;
