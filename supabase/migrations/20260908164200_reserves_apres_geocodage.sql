-- =============================================================================
-- Reserves (`data_notes`) : rattraper ce que le geocodage a rendu faux
--
-- 30 des 32 postes ont desormais des coordonnees
-- (`20260908120000_coordonnees_postes_diplomatiques`, puis
-- `20260908150000_coordonnees_postes_google`). Une reserve affichee a l'usager
-- doit rester vraie : celles qui parlaient d'un geocodage encore a faire ne le
-- sont plus.
--
-- Sur les 20 fiches qui portent une reserve, **deux seulement** sont
-- concernees. Les 18 autres parlent de numeros de telephone, d'adresses
-- e-mail ou d'orthographes -- que le geocodage ne change en rien, et qu'on ne
-- touche donc pas. Une reserve exacte qu'on reecrit pour faire propre, c'est
-- du bruit dans un fichier que quelqu'un relira dans six mois.
--
-- S'y ajoute une reserve NOUVELLE pour Copenhague : le geocodage y a revele
-- une contradiction qui n'existait pas avant, et qui porte precisement sur ce
-- que l'usager voit.
-- =============================================================================

-- 1. Berlin : la clause de geocodage est caduque ------------------------------
--    Le reste de la reserve tient : l'adresse PUBLIEE reste amputee de son
--    code postal et de sa ville. C'est bien la source qui est fautive, meme si
--    la position, elle, est desormais connue par ailleurs.
UPDATE public.embassies
   SET data_notes = 'Code postal non repris : le site publie « Machnower Str. 24 14 65 », '
                    'soit quatre chiffres là où un code allemand en compte cinq, et sans '
                    'mention de la ville. La position affichée ne vient donc pas de cette '
                    'adresse mais des données cartographiques.'
 WHERE slug = 'berlin-ambassade';

-- 2. La Havane : « aucune coordonnée » devenait ambigu ------------------------
--    « Coordonnee » y designait les moyens de contact, pas la position. Depuis
--    que la fiche porte un point sur la carte, la phrase se lit a contresens :
--    l'usager voit une epingle ET « aucune coordonnee publiee ».
--    Ce qui reste vrai, et qui est l'essentiel : le poste est injoignable.
UPDATE public.embassies
   SET data_notes = 'Aucun moyen de contact publié : le ministère annonce le poste avec '
                    '« -- » dans les quatre champs — ni téléphone, ni fax, ni adresse, ni '
                    'e-mail. La position vient des données cartographiques, pas de '
                    'l''annuaire. Le poste reste injoignable en l''état.'
 WHERE slug = 'la-havane-ambassade';

-- 3. Copenhague : reserve NOUVELLE, ouverte par le geocodage ------------------
--    Deux sources placent l'ambassade a 5,1 km l'une de l'autre, et rien ne
--    permet de trancher de l'exterieur. C'est la seule fiche ou la position
--    affichee peut envoyer quelqu'un a l'autre bout de la ville : le dire est
--    exactement ce a quoi `data_notes` sert. Courriel de clarification prepare
--    dans `docs/ops/DEMANDE_POSITIONS_POSTES.md` (§12).
UPDATE public.embassies
   SET data_notes = 'Code postal non repris : le site publie « Dk-059 », or les codes '
                    'danois comptent quatre chiffres. ⚠ Deux sources situent l''ambassade '
                    'à 5 km l''une de l''autre — l''annuaire indique Niels Juels Gade, les '
                    'données cartographiques ouvertes la placent à Østerbro. La position '
                    'affichée est donc à confirmer auprès du poste.'
 WHERE slug = 'copenhague-ambassade';
