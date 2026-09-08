import 'package:freezed_annotation/freezed_annotation.dart';

import 'administrative_request_model.dart';

part 'demarche_model.freezed.dart';
part 'demarche_model.g.dart';

/// Catalogue des démarches consulaires nigériennes, chargé depuis
/// `assets/data/demarches_consulaires.json`.
///
/// La donnée est extraite du site du ministère des Affaires étrangères. Elle
/// est **datée et lacunaire par nature**, et le modèle le reflète : la source
/// ne publie aucun délai de traitement et un seul montant sur vingt
/// démarches. [Demarche.delai] est donc nul partout et
/// [DemarcheCout.montantXof] presque partout — c'est un fait de la source,
/// pas un trou d'extraction.
///
/// Ne jamais combler ces vides par des estimations. L'écran de demande
/// affichait auparavant une table `_indicativeDelay` entièrement inventée
/// (« Sous 48 à 72 heures » pour un laissez-passer, sur quoi un usager peut
/// réserver un vol) ; c'est précisément ce que ce catalogue remplace.
@freezed
class DemarchesCatalogue with _$DemarchesCatalogue {
  const DemarchesCatalogue._();

  const factory DemarchesCatalogue({
    required int version,
    required DemarcheSource source,
    @Default(<DemarcheRubrique>[]) List<DemarcheRubrique> rubriques,
    @Default(<Demarche>[]) List<Demarche> demarches,
  }) = _DemarchesCatalogue;

  factory DemarchesCatalogue.fromJson(Map<String, dynamic> json) =>
      _$DemarchesCatalogueFromJson(json);

  /// Démarches d'une rubrique, dans l'ordre du fichier.
  List<Demarche> parRubrique(String rubriqueId) =>
      demarches.where((d) => d.rubrique == rubriqueId).toList();

  /// Rubriques triées par `ordre`, celles restées vides écartées.
  List<DemarcheRubrique> get rubriquesTriees {
    final liste =
        rubriques.where((r) => parRubrique(r.id).isNotEmpty).toList()
          ..sort((a, b) => a.ordre.compareTo(b.ordre));
    return liste;
  }

  /// Démarche portant cet identifiant, ou `null` si l'id est inconnu.
  Demarche? parId(String? id) {
    if (id == null) return null;
    for (final d in demarches) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Première démarche du catalogue — la carte consulaire, prérequis de 18
  /// des 20 autres. Sert de sélection par défaut.
  Demarche? get premiere => demarches.isEmpty ? null : demarches.first;
}

/// Provenance du catalogue, affichée en pied d'écran.
///
/// Toujours la montrer à côté des pièces : la source date de 2017 et n'est
/// plus maintenue, l'usager doit pouvoir en juger.
@freezed
class DemarcheSource with _$DemarcheSource {
  const factory DemarcheSource({
    required String editeur,
    required String url,
    required String consulteLe,
  }) = _DemarcheSource;

  factory DemarcheSource.fromJson(Map<String, dynamic> json) =>
      _$DemarcheSourceFromJson(json);
}

/// Regroupement de démarches (immatriculation, état civil, voyage…).
@freezed
class DemarcheRubrique with _$DemarcheRubrique {
  const factory DemarcheRubrique({
    required String id,
    required String titre,
    @Default(0) int ordre,
  }) = _DemarcheRubrique;

  factory DemarcheRubrique.fromJson(Map<String, dynamic> json) =>
      _$DemarcheRubriqueFromJson(json);
}

/// Une démarche consulaire et les pièces qu'elle exige.
@freezed
class Demarche with _$Demarche {
  const Demarche._();

  const factory Demarche({
    required String id,
    required String titre,

    /// Intitulé d'origine, présent uniquement quand [titre] le corrige.
    ///
    /// Un seul cas aujourd'hui : la source titre « Passeport (prorogation) »
    /// une liste de pièces qui est en réalité celle d'une première demande.
    String? titreSource,
    required String rubrique,
    required String requestType,

    /// `consulat` ou `tribunal_niger` — le certificat de nationalité est la
    /// seule démarche de la page qui ne se traite pas au consulat.
    @Default('consulat') String lieu,
    @Default(false) bool exigeCarteConsulaire,
    @Default(false) bool estPrerequisDeToutLeReste,
    String? resume,
    @Default(<DemarchePiece>[]) List<DemarchePiece> pieces,
    @Default(<DemarchePiecesConditionnelles>[])
    List<DemarchePiecesConditionnelles> piecesConditionnelles,
    required DemarcheCout cout,

    /// Toujours nul : la source ne publie aucun délai de traitement.
    String? delai,
    DemarcheJuridiction? juridictionCompetente,

    /// Défauts de la source touchant cette démarche (intitulé faux, pièce
    /// ambiguë, parenthèse tronquée…). Non vide sur 13 démarches sur 20.
    @Default(<String>[]) List<String> avertissements,
  }) = _Demarche;

  factory Demarche.fromJson(Map<String, dynamic> json) =>
      _$DemarcheFromJson(json);

  /// Type écrit en base pour cette démarche.
  ///
  /// Le mapping démarche → type est **1 → N** : `legalDocument` couvre six
  /// démarches notariées aux pièces toutes différentes, `birthCertificate`
  /// couvre la déclaration *et* la transcription de naissance. Indexer les
  /// pièces par ce type perdrait l'information — d'où un écran qui
  /// sélectionne une démarche, le type ne servant plus qu'à l'écriture
  /// Firestore et à la compatibilité des demandes déjà enregistrées.
  ///
  /// Une valeur inconnue retombe sur [AdministrativeRequestType.other] au
  /// lieu de lever : le `$enumDecode` de `AdministrativeRequestModel` n'a
  /// pas d'`unknownEnumValue`, une valeur hors enum ferait planter la
  /// désérialisation côté lecture.
  AdministrativeRequestType get typeDemande => switch (requestType) {
    'passportRenewal' => AdministrativeRequestType.passportRenewal,
    'passportNewRequest' => AdministrativeRequestType.passportNewRequest,
    'visaApplication' => AdministrativeRequestType.visaApplication,
    'birthCertificate' => AdministrativeRequestType.birthCertificate,
    'marriageCertificate' => AdministrativeRequestType.marriageCertificate,
    'deathCertificate' => AdministrativeRequestType.deathCertificate,
    'consularId' => AdministrativeRequestType.consularId,
    'legalDocument' => AdministrativeRequestType.legalDocument,
    'laissezPasser' => AdministrativeRequestType.laissezPasser,
    'powerOfAttorney' => AdministrativeRequestType.powerOfAttorney,
    'inscription' => AdministrativeRequestType.inscription,
    _ => AdministrativeRequestType.other,
  };

  /// Pièces regroupées pour l'affichage : les alternatives partagent un
  /// `groupeAlternatif` et se retrouvent dans la même sous-liste.
  ///
  /// Une seule pièce d'un groupe de plus d'un élément suffit — la carte
  /// consulaire s'obtient « avec une pièce d'identité nigérienne **ou**
  /// deux témoins déjà immatriculés ». Traiter ces lignes comme autant de
  /// pièces obligatoires exigerait des documents que le consulat n'exige
  /// pas, et masquerait la seule voie ouverte à qui n'a aucun papier.
  List<List<DemarchePiece>> get groupesDePieces {
    final groupes = <List<DemarchePiece>>[];
    final indexParGroupe = <String, int>{};

    for (final piece in pieces) {
      final cle = piece.groupeAlternatif;
      if (cle == null) {
        groupes.add([piece]);
        continue;
      }
      final existant = indexParGroupe[cle];
      if (existant == null) {
        indexParGroupe[cle] = groupes.length;
        groupes.add([piece]);
      } else {
        groupes[existant].add(piece);
      }
    }
    return groupes;
  }

  /// Nombre de pièces réellement à réunir : un groupe d'alternatives
  /// compte pour une.
  int get nombreDePiecesRequises => groupesDePieces.length;
}

/// Une pièce à fournir.
@freezed
class DemarchePiece with _$DemarchePiece {
  const DemarchePiece._();

  const factory DemarchePiece({
    required String libelle,

    /// `copie`, `original`, `original_et_copie`, `photo`, `temoin`,
    /// `formulaire`, `timbre_fiscal`, `attestation`, `document`,
    /// `liste_etablie_par_demandeur`.
    @Default('copie') String forme,

    /// Nul quand la source reste vague (« copie des pièces d'identité du
    /// défunt », sans dire combien).
    int? quantite,
    @Default(true) bool obligatoire,

    /// Pièces partageant cette clé : une seule d'entre elles suffit.
    String? groupeAlternatif,
    String? note,
  }) = _DemarchePiece;

  factory DemarchePiece.fromJson(Map<String, dynamic> json) =>
      _$DemarchePieceFromJson(json);

  /// Libellé enrichi de la quantité et de la forme quand elles ajoutent
  /// une information que le libellé ne porte pas déjà.
  String get libelleAffichable {
    final buffer = StringBuffer();
    if (quantite != null && quantite! > 1 && forme == 'photo') {
      buffer.write('$quantite × ');
    }
    buffer.write(libelle);
    if (forme == 'original_et_copie') {
      buffer.write(' (original et copie)');
    }
    return buffer.toString();
  }
}

/// Pièces exigées seulement dans un cas de figure donné.
///
/// Le laissez-passer en porte deux, dont une règle qui n'est pas une pièce :
/// un laissez-passer distinct par enfant de 2 à 16 ans.
@freezed
class DemarchePiecesConditionnelles with _$DemarchePiecesConditionnelles {
  const factory DemarchePiecesConditionnelles({
    required String condition,
    @Default(<DemarchePiece>[]) List<DemarchePiece> pieces,
    String? note,
  }) = _DemarchePiecesConditionnelles;

  factory DemarchePiecesConditionnelles.fromJson(Map<String, dynamic> json) =>
      _$DemarchePiecesConditionnellesFromJson(json);
}

/// Coût d'une démarche, et surtout **ce qu'on en sait**.
///
/// Les quatre statuts ne sont pas de la coquetterie : « aucun frais
/// mentionné » (déclarations de naissance et de mariage) n'est pas
/// « montant inconnu » (les 15 autres), et la différence est exactement ce
/// qu'un usager veut savoir avant de se déplacer.
@freezed
class DemarcheCout with _$DemarcheCout {
  const DemarcheCout._();

  const factory DemarcheCout({
    /// `connu`, `inconnu`, `non_mentionne` ou `variable_par_pays`.
    @Default('inconnu') String statut,
    String? libelle,
    int? montantXof,
  }) = _DemarcheCout;

  factory DemarcheCout.fromJson(Map<String, dynamic> json) =>
      _$DemarcheCoutFromJson(json);

  bool get estConnu => statut == 'connu' && montantXof != null;

  /// Phrase affichable. N'invente jamais de montant quand il manque : dire
  /// « non publié » est la seule chose vraie que la source permette.
  String get libelleAffichable => switch (statut) {
    'connu' => '${libelle ?? 'Montant'} : ${_montantFormate(montantXof!)} F CFA',
    'non_mentionne' => 'Aucun frais mentionné par la source',
    'variable_par_pays' =>
      libelle ?? 'Droits de chancellerie, sans frais dans certains pays',
    _ => '${libelle ?? 'Droits de chancellerie'} — montant non publié',
  };

  static String _montantFormate(int montant) {
    final chiffres = montant.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < chiffres.length; i++) {
      if (i > 0 && (chiffres.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(chiffres[i]);
    }
    return buffer.toString();
  }
}

/// Juridiction compétente, quand la démarche ne relève pas du consulat.
@freezed
class DemarcheJuridiction with _$DemarcheJuridiction {
  const factory DemarcheJuridiction({
    required String autorite,
    @Default(<String>[]) List<String> regles,
  }) = _DemarcheJuridiction;

  factory DemarcheJuridiction.fromJson(Map<String, dynamic> json) =>
      _$DemarcheJuridictionFromJson(json);
}
