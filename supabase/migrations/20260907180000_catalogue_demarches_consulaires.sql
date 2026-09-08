-- Catalogue des démarches consulaires : passage en base.
--
-- L'écran de demande administrative affichait jusqu'ici deux tables codées en
-- dur dans `administrative_request_screen.dart` : des pièces « propositions
-- indicatives » et surtout des délais entièrement inventés (« Sous 48 à 72
-- heures » pour un laissez-passer, sur quoi un usager peut réserver un vol).
-- La source officielle -- diplomatie.gouv.ne, consultée le 2026-09-07 -- ne
-- publie AUCUN délai et un seul montant sur vingt démarches.
--
-- Trois niveaux de chargement côté app, dans cet ordre :
--   1. `get_demarches_catalogue()` (cette migration),
--   2. cache SharedPreferences du dernier chargement réussi,
--   3. `assets/data/demarches_consulaires.json` embarqué dans l'APK.
-- Le pas 3 garantit que l'écran fonctionne hors ligne à la première ouverture,
-- avant tout accès réseau.
--
-- L'RPC renvoie exactement la forme du fichier JSON : un seul modèle Dart
-- parse les trois sources, et une divergence de schéma se voit tout de suite.

-- ---------------------------------------------------------------- tables

CREATE TABLE IF NOT EXISTS public.demarches_rubriques (
  id    text PRIMARY KEY,
  titre text NOT NULL,
  ordre integer NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.demarches_consulaires (
  id                             text PRIMARY KEY,
  titre                          text NOT NULL,
  -- Renseigné seulement quand `titre` corrige la source. Un seul cas : la
  -- source titre « Passeport (prorogation) » une liste de pièces qui est en
  -- réalité celle d'une première demande.
  titre_source                   text,
  rubrique                       text NOT NULL
                                 REFERENCES public.demarches_rubriques(id)
                                 ON UPDATE CASCADE,
  -- Valeur de l'enum Dart AdministrativeRequestType. Le mapping est 1 -> N
  -- (`legalDocument` couvre six démarches aux pièces différentes) : ce champ
  -- ne sert qu'à l'écriture Firestore, jamais à retrouver les pièces.
  request_type                   text NOT NULL,
  lieu                           text NOT NULL DEFAULT 'consulat',
  exige_carte_consulaire         boolean NOT NULL DEFAULT false,
  est_prerequis_de_tout_le_reste boolean NOT NULL DEFAULT false,
  resume                         text,
  pieces                         jsonb NOT NULL DEFAULT '[]'::jsonb,
  pieces_conditionnelles         jsonb NOT NULL DEFAULT '[]'::jsonb,
  cout                           jsonb NOT NULL,
  -- Toujours NULL : la source ne publie aucun délai de traitement. Ne pas y
  -- mettre d'estimation, c'est le défaut que cette migration corrige.
  delai                          text,
  juridiction_competente         jsonb,
  avertissements                 jsonb NOT NULL DEFAULT '[]'::jsonb,
  ordre                          integer NOT NULL DEFAULT 0,
  updated_at                     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS demarches_consulaires_rubrique_idx
  ON public.demarches_consulaires (rubrique, ordre);

-- Provenance du catalogue, affichée en pied d'écran : la source date de 2017
-- et n'est plus maintenue, l'usager doit pouvoir en juger.
CREATE TABLE IF NOT EXISTS public.demarches_catalogue_meta (
  id          boolean PRIMARY KEY DEFAULT true,
  version     integer NOT NULL,
  editeur     text NOT NULL,
  url         text NOT NULL,
  consulte_le text NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT demarches_catalogue_meta_singleton CHECK (id)
);

-- ------------------------------------------------------------------ RLS
--
-- Donnée de référence publique : lecture ouverte, y compris `anon` (l'écran
-- doit s'afficher avant toute connexion). Écriture réservée aux admins.
--
-- Les REVOKE/GRANT explicites ne sont pas redondants avec les policies :
-- `anon` dispose d'INSERT/UPDATE/DELETE au niveau TABLE sur presque tout ce
-- schéma, la RLS étant la seule barrière. Ici la barrière est double.

ALTER TABLE public.demarches_rubriques        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demarches_consulaires      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.demarches_catalogue_meta   ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.demarches_rubriques      FROM anon, authenticated;
REVOKE ALL ON public.demarches_consulaires    FROM anon, authenticated;
REVOKE ALL ON public.demarches_catalogue_meta FROM anon, authenticated;

GRANT SELECT ON public.demarches_rubriques      TO anon, authenticated;
GRANT SELECT ON public.demarches_consulaires    TO anon, authenticated;
GRANT SELECT ON public.demarches_catalogue_meta TO anon, authenticated;

GRANT INSERT, UPDATE, DELETE ON public.demarches_rubriques      TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.demarches_consulaires    TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.demarches_catalogue_meta TO authenticated;

DROP POLICY IF EXISTS demarches_rubriques_select      ON public.demarches_rubriques;
DROP POLICY IF EXISTS demarches_rubriques_write       ON public.demarches_rubriques;
DROP POLICY IF EXISTS demarches_consulaires_select    ON public.demarches_consulaires;
DROP POLICY IF EXISTS demarches_consulaires_write     ON public.demarches_consulaires;
DROP POLICY IF EXISTS demarches_catalogue_meta_select ON public.demarches_catalogue_meta;
DROP POLICY IF EXISTS demarches_catalogue_meta_write  ON public.demarches_catalogue_meta;

CREATE POLICY demarches_rubriques_select ON public.demarches_rubriques
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY demarches_rubriques_write ON public.demarches_rubriques
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

CREATE POLICY demarches_consulaires_select ON public.demarches_consulaires
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY demarches_consulaires_write ON public.demarches_consulaires
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

CREATE POLICY demarches_catalogue_meta_select ON public.demarches_catalogue_meta
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY demarches_catalogue_meta_write ON public.demarches_catalogue_meta
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- ------------------------------------------------------------------ RPC
--
-- Un seul aller-retour, et surtout une forme de sortie identique au fichier
-- JSON embarqué -- clés camelCase comprises. Le modèle Dart parse les deux
-- sans branche conditionnelle.
--
-- `security invoker` : la lecture reste soumise aux policies ci-dessus.

CREATE OR REPLACE FUNCTION public.get_demarches_catalogue()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $fn$
  SELECT jsonb_build_object(
    'version', m.version,
    'source', jsonb_build_object(
      'editeur',    m.editeur,
      'url',        m.url,
      'consulteLe', m.consulte_le
    ),
    'rubriques', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object('id', r.id, 'titre', r.titre, 'ordre', r.ordre)
        ORDER BY r.ordre
      )
      FROM public.demarches_rubriques r
    ), '[]'::jsonb),
    'demarches', COALESCE((
      SELECT jsonb_agg(
        jsonb_strip_nulls(jsonb_build_object(
          'id',                          d.id,
          'titre',                       d.titre,
          'titreSource',                 d.titre_source,
          'rubrique',                    d.rubrique,
          'requestType',                 d.request_type,
          'lieu',                        d.lieu,
          'exigeCarteConsulaire',        d.exige_carte_consulaire,
          'estPrerequisDeToutLeReste',   d.est_prerequis_de_tout_le_reste,
          'resume',                      d.resume,
          'pieces',                      d.pieces,
          'piecesConditionnelles',       d.pieces_conditionnelles,
          'cout',                        d.cout,
          'delai',                       d.delai,
          'juridictionCompetente',       d.juridiction_competente,
          'avertissements',              d.avertissements
        ))
        ORDER BY d.ordre
      )
      FROM public.demarches_consulaires d
    ), '[]'::jsonb)
  )
  FROM public.demarches_catalogue_meta m
  LIMIT 1;
$fn$;

-- `REVOKE ... FROM PUBLIC` seul laisserait l'EXECUTE hérité à anon ; on le
-- rend ici volontairement, le catalogue étant public par destination.
REVOKE ALL ON FUNCTION public.get_demarches_catalogue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_demarches_catalogue() TO anon, authenticated;

-- ---------------------------------------------------------------- amorce
--
-- Réexécutable : un ON CONFLICT ... DO UPDATE permet de rejouer la migration
-- après mise à jour du fichier JSON sans dupliquer ni perdre de lignes.


INSERT INTO public.demarches_catalogue_meta (id, version, editeur, url, consulte_le) VALUES
  (true, 1, 'Ministère des Affaires étrangères, de la Coopération, de l''Intégration africaine et des Nigériens à l''Extérieur', 'https://diplomatie.gouv.ne/index.php/services-aux-usagers/demarches-administratives', '2026-09-07')
ON CONFLICT (id) DO UPDATE SET
  version     = EXCLUDED.version,
  editeur     = EXCLUDED.editeur,
  url         = EXCLUDED.url,
  consulte_le = EXCLUDED.consulte_le,
  updated_at  = now();


INSERT INTO public.demarches_rubriques (id, titre, ordre) VALUES
  ('immatriculation', 'Immatriculation consulaire', 1),
  ('etat_civil', 'Actes d''état civil', 2),
  ('voyage', 'Documents de voyage', 3),
  ('actes_notaries', 'Actes notariés', 4),
  ('nationalite', 'Nationalité', 5)
ON CONFLICT (id) DO UPDATE SET
  titre = EXCLUDED.titre,
  ordre = EXCLUDED.ordre;


INSERT INTO public.demarches_consulaires (
  id, titre, titre_source, rubrique, request_type, lieu,
  exige_carte_consulaire, est_prerequis_de_tout_le_reste, resume,
  pieces, pieces_conditionnelles, cout, delai, juridiction_competente,
  avertissements, ordre
) VALUES
  ('carte_consulaire', 'Carte consulaire', NULL, 'immatriculation', 'consularId', 'consulat',
   false, true, 'Point d''entrée de tout le système consulaire : 18 des 20 démarches l''exigent en première pièce. À défaut de pièce d''identité nigérienne, deux témoins nigériens déjà immatriculés suffisent.',
   '[{"libelle":"Copie d''une pièce d''identité nigérienne (certificat de nationalité, acte de naissance ou ancienne carte consulaire)","forme":"copie","quantite":1,"obligatoire":true,"groupeAlternatif":"preuve_identite"},{"libelle":"Deux témoins de nationalité nigérienne ayant déjà obtenu la carte consulaire","forme":"temoin","quantite":2,"obligatoire":true,"groupeAlternatif":"preuve_identite","note":"Voie de secours pour qui ne détient aucune pièce d''identité nigérienne."},{"libelle":"Photo d''identité récente","forme":"photo","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["La source écrit « 2 Droits de chancellerie à payer » : le « 2 » est vraisemblablement un report de la ligne des photos qui précède. Le montant n''est pas publié."]'::jsonb, 0),
  ('carte_electeur', 'Carte d''électeur', NULL, 'immatriculation', 'other', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire du déclarant","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Photo d''identité récente","forme":"photo","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '[]'::jsonb, 1),
  ('carte_nationale_identite', 'Carte nationale d''identité (CNI)', NULL, 'etat_civil', 'other', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Copie d''une pièce d''identité nigérienne (certificat de nationalité, acte de naissance ou passeport)","forme":"copie","quantite":1,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '[]'::jsonb, 2),
  ('declaration_naissance', 'Déclaration de naissance', NULL, 'etat_civil', 'birthCertificate', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie des cartes consulaires des deux parents","forme":"copie","quantite":2,"obligatoire":true},{"libelle":"Copie de la pièce d''identité d''un parent nigérien (certificat de nationalité, acte de naissance, passeport ou CNI)","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Originaux des certificats d''accouchement","forme":"original","quantite":null,"obligatoire":true,"note":"La source emploie le pluriel sans préciser combien de certificats sont attendus."}]'::jsonb, '[]'::jsonb, '{"statut":"non_mentionne","libelle":null,"montantXof":null}'::jsonb, NULL, NULL,
   '["Aucun droit de chancellerie n''est mentionné, contrairement à presque toutes les autres démarches. Gratuité ou omission : indéterminable depuis la source."]'::jsonb, 3),
  ('declaration_mariage', 'Déclaration de mariage', NULL, 'etat_civil', 'marriageCertificate', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire du ou des conjoint(s) nigérien(s)","forme":"copie","quantite":null,"obligatoire":true},{"libelle":"Une pièce d''état civil des conjoints","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Deux témoins munis de leur pièce d''état civil nigérienne","forme":"temoin","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"non_mentionne","libelle":null,"montantXof":null}'::jsonb, NULL, NULL,
   '["Aucun droit de chancellerie n''est mentionné, contrairement à presque toutes les autres démarches. Gratuité ou omission : indéterminable depuis la source."]'::jsonb, 4),
  ('declaration_deces', 'Déclaration de décès', NULL, 'etat_civil', 'deathCertificate', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire du déclarant","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Attestation de décès des services de santé","forme":"attestation","quantite":1,"obligatoire":true},{"libelle":"Copie d''une pièce d''état civil nigérienne du défunt","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Deux témoins munis de leur pièce d''état civil nigérienne (certificat de nationalité, acte de naissance, passeport ou CNI)","forme":"temoin","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"variable_par_pays","libelle":"Droits de chancellerie, sans frais dans certains pays","montantXof":null}'::jsonb, NULL, NULL,
   '["La source ne dit pas dans quels pays la démarche est gratuite."]'::jsonb, 5),
  ('transcription_acte_naissance', 'Transcription d''acte de naissance', NULL, 'etat_civil', 'birthCertificate', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire du parent nigérien","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Original de l''acte de naissance de l''enfant mineur","forme":"original","quantite":1,"obligatoire":true},{"libelle":"Copie de l''acte de naissance ou du certificat de nationalité du parent nigérien","forme":"copie","quantite":1,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droit de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '[]'::jsonb, 6),
  ('transcription_acte_mariage', 'Transcription d''acte de mariage', NULL, 'etat_civil', 'marriageCertificate', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire du conjoint nigérien","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Acte de mariage des conjoints","forme":"original_et_copie","quantite":1,"obligatoire":true},{"libelle":"Copie de la pièce d''état civil du conjoint nigérien","forme":"copie","quantite":1,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droit de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '[]'::jsonb, 7),
  ('transcription_acte_deces', 'Transcription d''acte de décès', NULL, 'etat_civil', 'deathCertificate', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire du déclarant","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Acte de décès","forme":"original_et_copie","quantite":1,"obligatoire":true},{"libelle":"Copie des pièces d''identité du défunt nigérien","forme":"copie","quantite":null,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"variable_par_pays","libelle":"Droits de chancellerie, sans droit dans certains pays","montantXof":null}'::jsonb, NULL, NULL,
   '["La source ne dit pas dans quels pays la démarche est gratuite."]'::jsonb, 8),
  ('laissez_passer', 'Laissez-passer / Sauf-conduit', NULL, 'voyage', 'laissezPasser', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Photo d''identité récente","forme":"photo","quantite":2,"obligatoire":true}]'::jsonb, '[{"condition":"Voyage avec un enfant de moins de 2 ans","pieces":[{"libelle":"Photo d''identité de l''enfant","forme":"photo","quantite":2,"obligatoire":true},{"libelle":"Copie de l''acte de naissance de l''enfant","forme":"copie","quantite":1,"obligatoire":true}]},{"condition":"Voyage avec un ou plusieurs enfants de 2 à 16 ans","pieces":[],"note":"Un laissez-passer distinct doit être demandé pour chaque enfant de cette tranche d''âge."}]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["La source écrit « Droits de chancellerie à payer (sans). » — la parenthèse est tronquée et contredit le début de la phrase. Par analogie avec les démarches de décès, il s''agit probablement de « sans frais dans certains pays »."]'::jsonb, 9),
  ('passeport_demande', 'Passeport — première demande ou renouvellement', 'Passeport (prorogation)', 'voyage', 'passportNewRequest', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Copie de l''acte de naissance","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Copie du certificat de nationalité","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Copie de la carte nationale d''identité","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Photo d''identité récente","forme":"photo","quantite":3,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["TITRE CORRIGÉ. La source intitule cette entrée « Passeport (prorogation) », mais la liste de pièces (acte de naissance, certificat de nationalité, CNI, 3 photos, aucun passeport existant) est celle d''une première demande ou d''un renouvellement — pas d''une prorogation. La vraie prorogation est la démarche `prorogation_passeport`. Un usager lisant la page dans l''ordre rassemble quatre pièces inutiles."]'::jsonb, 10),
  ('prorogation_passeport', 'Prorogation de passeport', NULL, 'voyage', 'passportRenewal', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Original du passeport","forme":"original","quantite":1,"obligatoire":true},{"libelle":"Copie des trois premières pages du passeport","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Photo d''identité","forme":"photo","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["Le passeport est traité deux fois dans la source, avec des listes incompatibles. Celle-ci est la seule cohérente avec une prorogation."]'::jsonb, 11),
  ('certificat_demenagement', 'Certificat de déménagement', NULL, 'voyage', 'other', 'consulat',
   true, false, 'Pièce du retour définitif au pays : elle accompagne le transport des effets personnels.',
   '[{"libelle":"Copie de la carte consulaire","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Liste des matériels et objets à transporter, établie par le demandeur","forme":"liste_etablie_par_demandeur","quantite":1,"obligatoire":true},{"libelle":"Photo d''identité récente","forme":"photo","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '[]'::jsonb, 12),
  ('autorisation_parentale', 'Autorisation parentale', NULL, 'actes_notaries', 'legalDocument', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire du parent demandeur","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Copie de l''acte de naissance","forme":"copie","quantite":1,"obligatoire":true,"note":"Titulaire de l''acte non déterminable : voir avertissement."},{"libelle":"Photo d''identité récente de chaque enfant","forme":"photo","quantite":2,"obligatoire":true,"note":"Deux photos par enfant concerné."}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["La source écrit « Copie de l''acte de naissance du parent des enfants voyageant » : la formulation ne permet pas de dire s''il s''agit de l''acte du parent ou de celui des enfants. C''est la pièce centrale de la démarche — à faire confirmer par le consulat avant affichage."]'::jsonb, 13),
  ('fiche_individuelle_etat_civil', 'Fiche individuelle d''état civil', NULL, 'actes_notaries', 'legalDocument', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Une pièce d''état civil nigérienne","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Photo d''identité récente","forme":"photo","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droit de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '[]'::jsonb, 14),
  ('legalisation_document', 'Légalisation de documents nigériens', NULL, 'actes_notaries', 'legalDocument', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Document à légaliser","forme":"original_et_copie","quantite":1,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droit de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '[]'::jsonb, 15),
  ('acte_engagement', 'Acte d''engagement entre Nigériens', NULL, 'actes_notaries', 'legalDocument', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie de la carte consulaire de chaque demandeur","forme":"copie","quantite":null,"obligatoire":true},{"libelle":"Formulaire à remplir","forme":"formulaire","quantite":1,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["Le formulaire n''est ni téléchargeable ni décrit sur le site : il ne peut être rempli qu''au guichet."]'::jsonb, 16),
  ('acte_vente', 'Acte de vente entre Nigériens', NULL, 'actes_notaries', 'legalDocument', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie des cartes consulaires de l''acheteur et du vendeur","forme":"copie","quantite":2,"obligatoire":true},{"libelle":"Formulaire à remplir, mentionnant l''objet de la vente","forme":"formulaire","quantite":1,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["Le formulaire n''est ni téléchargeable ni décrit sur le site : il ne peut être rempli qu''au guichet."]'::jsonb, 17),
  ('proces_verbal', 'Procès-verbal entre Nigériens', NULL, 'actes_notaries', 'legalDocument', 'consulat',
   true, false, NULL,
   '[{"libelle":"Copie des cartes consulaires des intéressés","forme":"copie","quantite":null,"obligatoire":true},{"libelle":"Formulaire à remplir, mentionnant l''objet du litige","forme":"formulaire","quantite":1,"obligatoire":true},{"libelle":"Deux témoins de nationalité nigérienne","forme":"temoin","quantite":2,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"inconnu","libelle":"Droits de chancellerie","montantXof":null}'::jsonb, NULL, NULL,
   '["Le formulaire n''est ni téléchargeable ni décrit sur le site : il ne peut être rempli qu''au guichet."]'::jsonb, 18),
  ('certificat_nationalite', 'Certificat de nationalité', NULL, 'nationalite', 'other', 'tribunal_niger',
   false, false, 'Seule démarche de la page qui ne se traite pas au consulat : la demande s''adresse au président du tribunal de grande instance au Niger.',
   '[{"libelle":"Tout document susceptible de prouver la nationalité nigérienne","forme":"copie","quantite":null,"obligatoire":true},{"libelle":"Copie légalisée de l''acte de naissance du demandeur, de son père ou de sa mère","forme":"copie","quantite":1,"obligatoire":true},{"libelle":"Certificat de résidence ou certificat de scolarité","forme":"copie","quantite":1,"obligatoire":true,"groupeAlternatif":"justificatif_attache"},{"libelle":"Timbre fiscal","forme":"timbre_fiscal","quantite":1,"obligatoire":true}]'::jsonb, '[]'::jsonb, '{"statut":"connu","libelle":"Timbre fiscal","montantXof":1500}'::jsonb, NULL, '{"autorite":"Président du tribunal de grande instance","regles":["Du lieu de résidence si le demandeur réside au Niger","Du lieu de naissance si le demandeur, né au Niger, n''y réside plus","Du lieu de la dernière résidence au Niger si le demandeur, né hors du Niger, n''y réside plus"]}'::jsonb,
   '["Seul montant publié de toute la page. Ce n''est pas un droit de chancellerie mais un timbre fiscal acquitté au Niger.","La source écrit « Du lieu de résidence si le pétitionnaire, né au Niger, n''y réside plus » pour le deuxième cas, ce qui répète le premier et vide la règle de sens. Le critère y est vraisemblablement le lieu de naissance — à confirmer avant affichage."]'::jsonb, 19)
ON CONFLICT (id) DO UPDATE SET
  titre                          = EXCLUDED.titre,
  titre_source                   = EXCLUDED.titre_source,
  rubrique                       = EXCLUDED.rubrique,
  request_type                   = EXCLUDED.request_type,
  lieu                           = EXCLUDED.lieu,
  exige_carte_consulaire         = EXCLUDED.exige_carte_consulaire,
  est_prerequis_de_tout_le_reste = EXCLUDED.est_prerequis_de_tout_le_reste,
  resume                         = EXCLUDED.resume,
  pieces                         = EXCLUDED.pieces,
  pieces_conditionnelles         = EXCLUDED.pieces_conditionnelles,
  cout                           = EXCLUDED.cout,
  delai                          = EXCLUDED.delai,
  juridiction_competente         = EXCLUDED.juridiction_competente,
  avertissements                 = EXCLUDED.avertissements,
  ordre                          = EXCLUDED.ordre,
  updated_at                     = now();

