-- =============================================================================
-- `position_uncertain` : une coordonnee qu'on affiche sans y croire
--
-- Copenhague expose une contradiction que la table ne savait pas dire : la
-- fiche porte des coordonnees ET une reserve expliquant qu'elles sont a 5 km
-- d'une autre source. A l'ecran, le bouton « Y aller » etait donc actif,
-- en orange, exactement comme sur une fiche sure -- alors que le texte
-- juste au-dessus prevenait du contraire. Le bouton et la reserve se
-- contredisaient.
--
-- `latitude IS NOT NULL` ne suffit plus a decider : « on a une position » et
-- « on lui fait confiance » sont deux choses differentes. D'ou cette colonne,
-- explicite plutot que devinee -- l'alternative aurait ete de chercher un
-- « ⚠ » dans `data_notes`, ce qui ferait dependre le comportement d'une
-- tournure de phrase.
--
-- Par defaut `false` : les 29 autres fiches geocodees gardent leur bouton.
-- =============================================================================

ALTER TABLE public.embassies
  ADD COLUMN IF NOT EXISTS position_uncertain boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.embassies.position_uncertain IS
  'Vrai quand la position est connue mais douteuse : l''app refuse alors d''ouvrir '
  'la carte plutot que d''envoyer l''usager au mauvais endroit. La raison se lit '
  'dans data_notes.';

-- Copenhague : l'annuaire du ministere indique Niels Juels Gade, les donnees
-- cartographiques ouvertes placent l'ambassade a Osterbro -- 5 km d'ecart, et
-- rien pour departager de l'exterieur. Courriel de clarification prepare dans
-- `docs/ops/DEMANDE_POSITIONS_POSTES.md` (§12) ; a repasser a `false` des que
-- le poste aura repondu.
UPDATE public.embassies
   SET position_uncertain = true
 WHERE slug = 'copenhague-ambassade';
