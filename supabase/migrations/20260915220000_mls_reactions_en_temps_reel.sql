-- Les réactions entrent dans la publication temps réel.
--
-- CORRECTION D'UN RAISONNEMENT FAUX
-- `20260915200000` n'a mis que les reçus dans `supabase_realtime`, au motif
-- qu'« une réaction, une édition, un masquage arrivent déjà par un message de
-- contrôle MLS ». C'était vrai du plan, pas du code : le branchement Dart du
-- même jour fait voyager les réactions **par la table seule**. Un message de
-- contrôle n'est émis que pour la modification, dont le texte, lui, doit
-- vraiment être chiffré.
--
-- Conséquence du raisonnement faux : une réaction posée en face ne serait
-- apparue qu'au rechargement de la discussion. Pas une panne — un décalage
-- silencieux, du genre qu'on met des semaines à remarquer et qu'on met sur le
-- compte du réseau.
--
-- Le masquage et les favoris restent dehors : ils ne concernent qu'un seul
-- utilisateur, et tant qu'un compte n'a qu'un appareil (le multi-appareil est
-- la phase 7), personne d'autre n'a à en être averti.

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND tablename = 'mls_message_reactions'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.mls_message_reactions;
    END IF;
  END IF;
END
$do$;
