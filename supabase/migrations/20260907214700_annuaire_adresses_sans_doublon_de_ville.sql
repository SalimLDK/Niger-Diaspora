-- =============================================================================
-- Annuaire : retirer la ville des adresses qui la portent en langue etrangere
--
-- Constate sur SM A515F le 2026-09-07 : la fiche de detail composait
-- « adresse, ville, pays » et affichait « Machnower Str. 24, Berlin, Berlin,
-- Allemagne ». Les adresses postales portent presque toujours la ville, que la
-- ligne ajoutait une seconde fois.
--
-- Le cas general est traite cote app (`_formatLocation` n'ajoute un fragment
-- que s'il n'est pas deja present dans ce qui precede). Restent trois fiches
-- ou la ville figure dans l'adresse sous son nom LOCAL, que la comparaison ne
-- peut pas reconnaitre :
--
--   Rome        « Via Antonio Baiamonti, Roma »        -> Roma / Rome
--   Pekin       « … Beijing 100600 »                   -> Beijing / Pekin
--   Copenhague  « Niels Juels Gade 5, Kobenhavn K »    -> Kobenhavn / Copenhague
--
-- On retire le nom local : la colonne `city` porte deja la ville, et c'est
-- elle que la fiche affiche.
--
-- Migration a part plutot que correction de
-- `20260907190000_annuaire_postes_diplomatiques` : celle-ci est deja appliquee
-- en production, et un fichier deja joue doit rester le reflet exact de ce qui
-- a tourne.
-- =============================================================================

UPDATE public.embassies
   SET address = 'Via Antonio Baiamonti'
 WHERE slug = 'rome-ambassade'
   AND address = 'Via Antonio Baiamonti, Roma';

UPDATE public.embassies
   SET address = '1-21 San Li Tun Diplomatic Compound, 100600'
 WHERE slug = 'pekin-ambassade'
   AND address = '1-21 San Li Tun Diplomatic Compound, Beijing 100600';

UPDATE public.embassies
   SET address = 'Niels Juels Gade 5'
 WHERE slug = 'copenhague-ambassade'
   AND address = 'Niels Juels Gade 5, København K';
