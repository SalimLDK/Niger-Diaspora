// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demarche_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DemarchesCatalogueImpl _$$DemarchesCatalogueImplFromJson(
  Map<String, dynamic> json,
) => _$DemarchesCatalogueImpl(
  version: (json['version'] as num).toInt(),
  source: DemarcheSource.fromJson(json['source'] as Map<String, dynamic>),
  rubriques:
      (json['rubriques'] as List<dynamic>?)
          ?.map((e) => DemarcheRubrique.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <DemarcheRubrique>[],
  demarches:
      (json['demarches'] as List<dynamic>?)
          ?.map((e) => Demarche.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Demarche>[],
);

Map<String, dynamic> _$$DemarchesCatalogueImplToJson(
  _$DemarchesCatalogueImpl instance,
) => <String, dynamic>{
  'version': instance.version,
  'source': instance.source,
  'rubriques': instance.rubriques,
  'demarches': instance.demarches,
};

_$DemarcheSourceImpl _$$DemarcheSourceImplFromJson(Map<String, dynamic> json) =>
    _$DemarcheSourceImpl(
      editeur: json['editeur'] as String,
      url: json['url'] as String,
      consulteLe: json['consulteLe'] as String,
    );

Map<String, dynamic> _$$DemarcheSourceImplToJson(
  _$DemarcheSourceImpl instance,
) => <String, dynamic>{
  'editeur': instance.editeur,
  'url': instance.url,
  'consulteLe': instance.consulteLe,
};

_$DemarcheRubriqueImpl _$$DemarcheRubriqueImplFromJson(
  Map<String, dynamic> json,
) => _$DemarcheRubriqueImpl(
  id: json['id'] as String,
  titre: json['titre'] as String,
  ordre: (json['ordre'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$DemarcheRubriqueImplToJson(
  _$DemarcheRubriqueImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'titre': instance.titre,
  'ordre': instance.ordre,
};

_$DemarcheImpl _$$DemarcheImplFromJson(Map<String, dynamic> json) =>
    _$DemarcheImpl(
      id: json['id'] as String,
      titre: json['titre'] as String,
      titreSource: json['titreSource'] as String?,
      rubrique: json['rubrique'] as String,
      requestType: json['requestType'] as String,
      lieu: json['lieu'] as String? ?? 'consulat',
      exigeCarteConsulaire: json['exigeCarteConsulaire'] as bool? ?? false,
      estPrerequisDeToutLeReste:
          json['estPrerequisDeToutLeReste'] as bool? ?? false,
      resume: json['resume'] as String?,
      pieces:
          (json['pieces'] as List<dynamic>?)
              ?.map((e) => DemarchePiece.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <DemarchePiece>[],
      piecesConditionnelles:
          (json['piecesConditionnelles'] as List<dynamic>?)
              ?.map(
                (e) => DemarchePiecesConditionnelles.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const <DemarchePiecesConditionnelles>[],
      cout: DemarcheCout.fromJson(json['cout'] as Map<String, dynamic>),
      delai: json['delai'] as String?,
      juridictionCompetente:
          json['juridictionCompetente'] == null
              ? null
              : DemarcheJuridiction.fromJson(
                json['juridictionCompetente'] as Map<String, dynamic>,
              ),
      avertissements:
          (json['avertissements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$$DemarcheImplToJson(_$DemarcheImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'titre': instance.titre,
      'titreSource': instance.titreSource,
      'rubrique': instance.rubrique,
      'requestType': instance.requestType,
      'lieu': instance.lieu,
      'exigeCarteConsulaire': instance.exigeCarteConsulaire,
      'estPrerequisDeToutLeReste': instance.estPrerequisDeToutLeReste,
      'resume': instance.resume,
      'pieces': instance.pieces,
      'piecesConditionnelles': instance.piecesConditionnelles,
      'cout': instance.cout,
      'delai': instance.delai,
      'juridictionCompetente': instance.juridictionCompetente,
      'avertissements': instance.avertissements,
    };

_$DemarchePieceImpl _$$DemarchePieceImplFromJson(Map<String, dynamic> json) =>
    _$DemarchePieceImpl(
      libelle: json['libelle'] as String,
      forme: json['forme'] as String? ?? 'copie',
      quantite: (json['quantite'] as num?)?.toInt(),
      obligatoire: json['obligatoire'] as bool? ?? true,
      groupeAlternatif: json['groupeAlternatif'] as String?,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$$DemarchePieceImplToJson(_$DemarchePieceImpl instance) =>
    <String, dynamic>{
      'libelle': instance.libelle,
      'forme': instance.forme,
      'quantite': instance.quantite,
      'obligatoire': instance.obligatoire,
      'groupeAlternatif': instance.groupeAlternatif,
      'note': instance.note,
    };

_$DemarchePiecesConditionnellesImpl
_$$DemarchePiecesConditionnellesImplFromJson(Map<String, dynamic> json) =>
    _$DemarchePiecesConditionnellesImpl(
      condition: json['condition'] as String,
      pieces:
          (json['pieces'] as List<dynamic>?)
              ?.map((e) => DemarchePiece.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <DemarchePiece>[],
      note: json['note'] as String?,
    );

Map<String, dynamic> _$$DemarchePiecesConditionnellesImplToJson(
  _$DemarchePiecesConditionnellesImpl instance,
) => <String, dynamic>{
  'condition': instance.condition,
  'pieces': instance.pieces,
  'note': instance.note,
};

_$DemarcheCoutImpl _$$DemarcheCoutImplFromJson(Map<String, dynamic> json) =>
    _$DemarcheCoutImpl(
      statut: json['statut'] as String? ?? 'inconnu',
      libelle: json['libelle'] as String?,
      montantXof: (json['montantXof'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$DemarcheCoutImplToJson(_$DemarcheCoutImpl instance) =>
    <String, dynamic>{
      'statut': instance.statut,
      'libelle': instance.libelle,
      'montantXof': instance.montantXof,
    };

_$DemarcheJuridictionImpl _$$DemarcheJuridictionImplFromJson(
  Map<String, dynamic> json,
) => _$DemarcheJuridictionImpl(
  autorite: json['autorite'] as String,
  regles:
      (json['regles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$$DemarcheJuridictionImplToJson(
  _$DemarcheJuridictionImpl instance,
) => <String, dynamic>{
  'autorite': instance.autorite,
  'regles': instance.regles,
};
