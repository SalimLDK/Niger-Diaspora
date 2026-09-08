// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'demarche_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DemarchesCatalogue _$DemarchesCatalogueFromJson(Map<String, dynamic> json) {
  return _DemarchesCatalogue.fromJson(json);
}

/// @nodoc
mixin _$DemarchesCatalogue {
  int get version => throw _privateConstructorUsedError;
  DemarcheSource get source => throw _privateConstructorUsedError;
  List<DemarcheRubrique> get rubriques => throw _privateConstructorUsedError;
  List<Demarche> get demarches => throw _privateConstructorUsedError;

  /// Serializes this DemarchesCatalogue to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DemarchesCatalogue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarchesCatalogueCopyWith<DemarchesCatalogue> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarchesCatalogueCopyWith<$Res> {
  factory $DemarchesCatalogueCopyWith(
    DemarchesCatalogue value,
    $Res Function(DemarchesCatalogue) then,
  ) = _$DemarchesCatalogueCopyWithImpl<$Res, DemarchesCatalogue>;
  @useResult
  $Res call({
    int version,
    DemarcheSource source,
    List<DemarcheRubrique> rubriques,
    List<Demarche> demarches,
  });

  $DemarcheSourceCopyWith<$Res> get source;
}

/// @nodoc
class _$DemarchesCatalogueCopyWithImpl<$Res, $Val extends DemarchesCatalogue>
    implements $DemarchesCatalogueCopyWith<$Res> {
  _$DemarchesCatalogueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DemarchesCatalogue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? source = null,
    Object? rubriques = null,
    Object? demarches = null,
  }) {
    return _then(
      _value.copyWith(
            version:
                null == version
                    ? _value.version
                    : version // ignore: cast_nullable_to_non_nullable
                        as int,
            source:
                null == source
                    ? _value.source
                    : source // ignore: cast_nullable_to_non_nullable
                        as DemarcheSource,
            rubriques:
                null == rubriques
                    ? _value.rubriques
                    : rubriques // ignore: cast_nullable_to_non_nullable
                        as List<DemarcheRubrique>,
            demarches:
                null == demarches
                    ? _value.demarches
                    : demarches // ignore: cast_nullable_to_non_nullable
                        as List<Demarche>,
          )
          as $Val,
    );
  }

  /// Create a copy of DemarchesCatalogue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DemarcheSourceCopyWith<$Res> get source {
    return $DemarcheSourceCopyWith<$Res>(_value.source, (value) {
      return _then(_value.copyWith(source: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DemarchesCatalogueImplCopyWith<$Res>
    implements $DemarchesCatalogueCopyWith<$Res> {
  factory _$$DemarchesCatalogueImplCopyWith(
    _$DemarchesCatalogueImpl value,
    $Res Function(_$DemarchesCatalogueImpl) then,
  ) = __$$DemarchesCatalogueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int version,
    DemarcheSource source,
    List<DemarcheRubrique> rubriques,
    List<Demarche> demarches,
  });

  @override
  $DemarcheSourceCopyWith<$Res> get source;
}

/// @nodoc
class __$$DemarchesCatalogueImplCopyWithImpl<$Res>
    extends _$DemarchesCatalogueCopyWithImpl<$Res, _$DemarchesCatalogueImpl>
    implements _$$DemarchesCatalogueImplCopyWith<$Res> {
  __$$DemarchesCatalogueImplCopyWithImpl(
    _$DemarchesCatalogueImpl _value,
    $Res Function(_$DemarchesCatalogueImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DemarchesCatalogue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? source = null,
    Object? rubriques = null,
    Object? demarches = null,
  }) {
    return _then(
      _$DemarchesCatalogueImpl(
        version:
            null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                    as int,
        source:
            null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                    as DemarcheSource,
        rubriques:
            null == rubriques
                ? _value._rubriques
                : rubriques // ignore: cast_nullable_to_non_nullable
                    as List<DemarcheRubrique>,
        demarches:
            null == demarches
                ? _value._demarches
                : demarches // ignore: cast_nullable_to_non_nullable
                    as List<Demarche>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarchesCatalogueImpl extends _DemarchesCatalogue {
  const _$DemarchesCatalogueImpl({
    required this.version,
    required this.source,
    final List<DemarcheRubrique> rubriques = const <DemarcheRubrique>[],
    final List<Demarche> demarches = const <Demarche>[],
  }) : _rubriques = rubriques,
       _demarches = demarches,
       super._();

  factory _$DemarchesCatalogueImpl.fromJson(Map<String, dynamic> json) =>
      _$$DemarchesCatalogueImplFromJson(json);

  @override
  final int version;
  @override
  final DemarcheSource source;
  final List<DemarcheRubrique> _rubriques;
  @override
  @JsonKey()
  List<DemarcheRubrique> get rubriques {
    if (_rubriques is EqualUnmodifiableListView) return _rubriques;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rubriques);
  }

  final List<Demarche> _demarches;
  @override
  @JsonKey()
  List<Demarche> get demarches {
    if (_demarches is EqualUnmodifiableListView) return _demarches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_demarches);
  }

  @override
  String toString() {
    return 'DemarchesCatalogue(version: $version, source: $source, rubriques: $rubriques, demarches: $demarches)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarchesCatalogueImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.source, source) || other.source == source) &&
            const DeepCollectionEquality().equals(
              other._rubriques,
              _rubriques,
            ) &&
            const DeepCollectionEquality().equals(
              other._demarches,
              _demarches,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    version,
    source,
    const DeepCollectionEquality().hash(_rubriques),
    const DeepCollectionEquality().hash(_demarches),
  );

  /// Create a copy of DemarchesCatalogue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarchesCatalogueImplCopyWith<_$DemarchesCatalogueImpl> get copyWith =>
      __$$DemarchesCatalogueImplCopyWithImpl<_$DemarchesCatalogueImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarchesCatalogueImplToJson(this);
  }
}

abstract class _DemarchesCatalogue extends DemarchesCatalogue {
  const factory _DemarchesCatalogue({
    required final int version,
    required final DemarcheSource source,
    final List<DemarcheRubrique> rubriques,
    final List<Demarche> demarches,
  }) = _$DemarchesCatalogueImpl;
  const _DemarchesCatalogue._() : super._();

  factory _DemarchesCatalogue.fromJson(Map<String, dynamic> json) =
      _$DemarchesCatalogueImpl.fromJson;

  @override
  int get version;
  @override
  DemarcheSource get source;
  @override
  List<DemarcheRubrique> get rubriques;
  @override
  List<Demarche> get demarches;

  /// Create a copy of DemarchesCatalogue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarchesCatalogueImplCopyWith<_$DemarchesCatalogueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DemarcheSource _$DemarcheSourceFromJson(Map<String, dynamic> json) {
  return _DemarcheSource.fromJson(json);
}

/// @nodoc
mixin _$DemarcheSource {
  String get editeur => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  String get consulteLe => throw _privateConstructorUsedError;

  /// Serializes this DemarcheSource to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DemarcheSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarcheSourceCopyWith<DemarcheSource> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarcheSourceCopyWith<$Res> {
  factory $DemarcheSourceCopyWith(
    DemarcheSource value,
    $Res Function(DemarcheSource) then,
  ) = _$DemarcheSourceCopyWithImpl<$Res, DemarcheSource>;
  @useResult
  $Res call({String editeur, String url, String consulteLe});
}

/// @nodoc
class _$DemarcheSourceCopyWithImpl<$Res, $Val extends DemarcheSource>
    implements $DemarcheSourceCopyWith<$Res> {
  _$DemarcheSourceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DemarcheSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? editeur = null,
    Object? url = null,
    Object? consulteLe = null,
  }) {
    return _then(
      _value.copyWith(
            editeur:
                null == editeur
                    ? _value.editeur
                    : editeur // ignore: cast_nullable_to_non_nullable
                        as String,
            url:
                null == url
                    ? _value.url
                    : url // ignore: cast_nullable_to_non_nullable
                        as String,
            consulteLe:
                null == consulteLe
                    ? _value.consulteLe
                    : consulteLe // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DemarcheSourceImplCopyWith<$Res>
    implements $DemarcheSourceCopyWith<$Res> {
  factory _$$DemarcheSourceImplCopyWith(
    _$DemarcheSourceImpl value,
    $Res Function(_$DemarcheSourceImpl) then,
  ) = __$$DemarcheSourceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String editeur, String url, String consulteLe});
}

/// @nodoc
class __$$DemarcheSourceImplCopyWithImpl<$Res>
    extends _$DemarcheSourceCopyWithImpl<$Res, _$DemarcheSourceImpl>
    implements _$$DemarcheSourceImplCopyWith<$Res> {
  __$$DemarcheSourceImplCopyWithImpl(
    _$DemarcheSourceImpl _value,
    $Res Function(_$DemarcheSourceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DemarcheSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? editeur = null,
    Object? url = null,
    Object? consulteLe = null,
  }) {
    return _then(
      _$DemarcheSourceImpl(
        editeur:
            null == editeur
                ? _value.editeur
                : editeur // ignore: cast_nullable_to_non_nullable
                    as String,
        url:
            null == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                    as String,
        consulteLe:
            null == consulteLe
                ? _value.consulteLe
                : consulteLe // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarcheSourceImpl implements _DemarcheSource {
  const _$DemarcheSourceImpl({
    required this.editeur,
    required this.url,
    required this.consulteLe,
  });

  factory _$DemarcheSourceImpl.fromJson(Map<String, dynamic> json) =>
      _$$DemarcheSourceImplFromJson(json);

  @override
  final String editeur;
  @override
  final String url;
  @override
  final String consulteLe;

  @override
  String toString() {
    return 'DemarcheSource(editeur: $editeur, url: $url, consulteLe: $consulteLe)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarcheSourceImpl &&
            (identical(other.editeur, editeur) || other.editeur == editeur) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.consulteLe, consulteLe) ||
                other.consulteLe == consulteLe));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, editeur, url, consulteLe);

  /// Create a copy of DemarcheSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarcheSourceImplCopyWith<_$DemarcheSourceImpl> get copyWith =>
      __$$DemarcheSourceImplCopyWithImpl<_$DemarcheSourceImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarcheSourceImplToJson(this);
  }
}

abstract class _DemarcheSource implements DemarcheSource {
  const factory _DemarcheSource({
    required final String editeur,
    required final String url,
    required final String consulteLe,
  }) = _$DemarcheSourceImpl;

  factory _DemarcheSource.fromJson(Map<String, dynamic> json) =
      _$DemarcheSourceImpl.fromJson;

  @override
  String get editeur;
  @override
  String get url;
  @override
  String get consulteLe;

  /// Create a copy of DemarcheSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarcheSourceImplCopyWith<_$DemarcheSourceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DemarcheRubrique _$DemarcheRubriqueFromJson(Map<String, dynamic> json) {
  return _DemarcheRubrique.fromJson(json);
}

/// @nodoc
mixin _$DemarcheRubrique {
  String get id => throw _privateConstructorUsedError;
  String get titre => throw _privateConstructorUsedError;
  int get ordre => throw _privateConstructorUsedError;

  /// Serializes this DemarcheRubrique to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DemarcheRubrique
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarcheRubriqueCopyWith<DemarcheRubrique> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarcheRubriqueCopyWith<$Res> {
  factory $DemarcheRubriqueCopyWith(
    DemarcheRubrique value,
    $Res Function(DemarcheRubrique) then,
  ) = _$DemarcheRubriqueCopyWithImpl<$Res, DemarcheRubrique>;
  @useResult
  $Res call({String id, String titre, int ordre});
}

/// @nodoc
class _$DemarcheRubriqueCopyWithImpl<$Res, $Val extends DemarcheRubrique>
    implements $DemarcheRubriqueCopyWith<$Res> {
  _$DemarcheRubriqueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DemarcheRubrique
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? titre = null, Object? ordre = null}) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            titre:
                null == titre
                    ? _value.titre
                    : titre // ignore: cast_nullable_to_non_nullable
                        as String,
            ordre:
                null == ordre
                    ? _value.ordre
                    : ordre // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DemarcheRubriqueImplCopyWith<$Res>
    implements $DemarcheRubriqueCopyWith<$Res> {
  factory _$$DemarcheRubriqueImplCopyWith(
    _$DemarcheRubriqueImpl value,
    $Res Function(_$DemarcheRubriqueImpl) then,
  ) = __$$DemarcheRubriqueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String titre, int ordre});
}

/// @nodoc
class __$$DemarcheRubriqueImplCopyWithImpl<$Res>
    extends _$DemarcheRubriqueCopyWithImpl<$Res, _$DemarcheRubriqueImpl>
    implements _$$DemarcheRubriqueImplCopyWith<$Res> {
  __$$DemarcheRubriqueImplCopyWithImpl(
    _$DemarcheRubriqueImpl _value,
    $Res Function(_$DemarcheRubriqueImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DemarcheRubrique
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? titre = null, Object? ordre = null}) {
    return _then(
      _$DemarcheRubriqueImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        titre:
            null == titre
                ? _value.titre
                : titre // ignore: cast_nullable_to_non_nullable
                    as String,
        ordre:
            null == ordre
                ? _value.ordre
                : ordre // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarcheRubriqueImpl implements _DemarcheRubrique {
  const _$DemarcheRubriqueImpl({
    required this.id,
    required this.titre,
    this.ordre = 0,
  });

  factory _$DemarcheRubriqueImpl.fromJson(Map<String, dynamic> json) =>
      _$$DemarcheRubriqueImplFromJson(json);

  @override
  final String id;
  @override
  final String titre;
  @override
  @JsonKey()
  final int ordre;

  @override
  String toString() {
    return 'DemarcheRubrique(id: $id, titre: $titre, ordre: $ordre)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarcheRubriqueImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.titre, titre) || other.titre == titre) &&
            (identical(other.ordre, ordre) || other.ordre == ordre));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, titre, ordre);

  /// Create a copy of DemarcheRubrique
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarcheRubriqueImplCopyWith<_$DemarcheRubriqueImpl> get copyWith =>
      __$$DemarcheRubriqueImplCopyWithImpl<_$DemarcheRubriqueImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarcheRubriqueImplToJson(this);
  }
}

abstract class _DemarcheRubrique implements DemarcheRubrique {
  const factory _DemarcheRubrique({
    required final String id,
    required final String titre,
    final int ordre,
  }) = _$DemarcheRubriqueImpl;

  factory _DemarcheRubrique.fromJson(Map<String, dynamic> json) =
      _$DemarcheRubriqueImpl.fromJson;

  @override
  String get id;
  @override
  String get titre;
  @override
  int get ordre;

  /// Create a copy of DemarcheRubrique
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarcheRubriqueImplCopyWith<_$DemarcheRubriqueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Demarche _$DemarcheFromJson(Map<String, dynamic> json) {
  return _Demarche.fromJson(json);
}

/// @nodoc
mixin _$Demarche {
  String get id => throw _privateConstructorUsedError;
  String get titre => throw _privateConstructorUsedError;

  /// Intitulé d'origine, présent uniquement quand [titre] le corrige.
  ///
  /// Un seul cas aujourd'hui : la source titre « Passeport (prorogation) »
  /// une liste de pièces qui est en réalité celle d'une première demande.
  String? get titreSource => throw _privateConstructorUsedError;
  String get rubrique => throw _privateConstructorUsedError;
  String get requestType => throw _privateConstructorUsedError;

  /// `consulat` ou `tribunal_niger` — le certificat de nationalité est la
  /// seule démarche de la page qui ne se traite pas au consulat.
  String get lieu => throw _privateConstructorUsedError;
  bool get exigeCarteConsulaire => throw _privateConstructorUsedError;
  bool get estPrerequisDeToutLeReste => throw _privateConstructorUsedError;
  String? get resume => throw _privateConstructorUsedError;
  List<DemarchePiece> get pieces => throw _privateConstructorUsedError;
  List<DemarchePiecesConditionnelles> get piecesConditionnelles =>
      throw _privateConstructorUsedError;
  DemarcheCout get cout => throw _privateConstructorUsedError;

  /// Toujours nul : la source ne publie aucun délai de traitement.
  String? get delai => throw _privateConstructorUsedError;
  DemarcheJuridiction? get juridictionCompetente =>
      throw _privateConstructorUsedError;

  /// Défauts de la source touchant cette démarche (intitulé faux, pièce
  /// ambiguë, parenthèse tronquée…). Non vide sur 13 démarches sur 20.
  List<String> get avertissements => throw _privateConstructorUsedError;

  /// Serializes this Demarche to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Demarche
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarcheCopyWith<Demarche> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarcheCopyWith<$Res> {
  factory $DemarcheCopyWith(Demarche value, $Res Function(Demarche) then) =
      _$DemarcheCopyWithImpl<$Res, Demarche>;
  @useResult
  $Res call({
    String id,
    String titre,
    String? titreSource,
    String rubrique,
    String requestType,
    String lieu,
    bool exigeCarteConsulaire,
    bool estPrerequisDeToutLeReste,
    String? resume,
    List<DemarchePiece> pieces,
    List<DemarchePiecesConditionnelles> piecesConditionnelles,
    DemarcheCout cout,
    String? delai,
    DemarcheJuridiction? juridictionCompetente,
    List<String> avertissements,
  });

  $DemarcheCoutCopyWith<$Res> get cout;
  $DemarcheJuridictionCopyWith<$Res>? get juridictionCompetente;
}

/// @nodoc
class _$DemarcheCopyWithImpl<$Res, $Val extends Demarche>
    implements $DemarcheCopyWith<$Res> {
  _$DemarcheCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Demarche
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? titre = null,
    Object? titreSource = freezed,
    Object? rubrique = null,
    Object? requestType = null,
    Object? lieu = null,
    Object? exigeCarteConsulaire = null,
    Object? estPrerequisDeToutLeReste = null,
    Object? resume = freezed,
    Object? pieces = null,
    Object? piecesConditionnelles = null,
    Object? cout = null,
    Object? delai = freezed,
    Object? juridictionCompetente = freezed,
    Object? avertissements = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            titre:
                null == titre
                    ? _value.titre
                    : titre // ignore: cast_nullable_to_non_nullable
                        as String,
            titreSource:
                freezed == titreSource
                    ? _value.titreSource
                    : titreSource // ignore: cast_nullable_to_non_nullable
                        as String?,
            rubrique:
                null == rubrique
                    ? _value.rubrique
                    : rubrique // ignore: cast_nullable_to_non_nullable
                        as String,
            requestType:
                null == requestType
                    ? _value.requestType
                    : requestType // ignore: cast_nullable_to_non_nullable
                        as String,
            lieu:
                null == lieu
                    ? _value.lieu
                    : lieu // ignore: cast_nullable_to_non_nullable
                        as String,
            exigeCarteConsulaire:
                null == exigeCarteConsulaire
                    ? _value.exigeCarteConsulaire
                    : exigeCarteConsulaire // ignore: cast_nullable_to_non_nullable
                        as bool,
            estPrerequisDeToutLeReste:
                null == estPrerequisDeToutLeReste
                    ? _value.estPrerequisDeToutLeReste
                    : estPrerequisDeToutLeReste // ignore: cast_nullable_to_non_nullable
                        as bool,
            resume:
                freezed == resume
                    ? _value.resume
                    : resume // ignore: cast_nullable_to_non_nullable
                        as String?,
            pieces:
                null == pieces
                    ? _value.pieces
                    : pieces // ignore: cast_nullable_to_non_nullable
                        as List<DemarchePiece>,
            piecesConditionnelles:
                null == piecesConditionnelles
                    ? _value.piecesConditionnelles
                    : piecesConditionnelles // ignore: cast_nullable_to_non_nullable
                        as List<DemarchePiecesConditionnelles>,
            cout:
                null == cout
                    ? _value.cout
                    : cout // ignore: cast_nullable_to_non_nullable
                        as DemarcheCout,
            delai:
                freezed == delai
                    ? _value.delai
                    : delai // ignore: cast_nullable_to_non_nullable
                        as String?,
            juridictionCompetente:
                freezed == juridictionCompetente
                    ? _value.juridictionCompetente
                    : juridictionCompetente // ignore: cast_nullable_to_non_nullable
                        as DemarcheJuridiction?,
            avertissements:
                null == avertissements
                    ? _value.avertissements
                    : avertissements // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }

  /// Create a copy of Demarche
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DemarcheCoutCopyWith<$Res> get cout {
    return $DemarcheCoutCopyWith<$Res>(_value.cout, (value) {
      return _then(_value.copyWith(cout: value) as $Val);
    });
  }

  /// Create a copy of Demarche
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DemarcheJuridictionCopyWith<$Res>? get juridictionCompetente {
    if (_value.juridictionCompetente == null) {
      return null;
    }

    return $DemarcheJuridictionCopyWith<$Res>(_value.juridictionCompetente!, (
      value,
    ) {
      return _then(_value.copyWith(juridictionCompetente: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DemarcheImplCopyWith<$Res>
    implements $DemarcheCopyWith<$Res> {
  factory _$$DemarcheImplCopyWith(
    _$DemarcheImpl value,
    $Res Function(_$DemarcheImpl) then,
  ) = __$$DemarcheImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String titre,
    String? titreSource,
    String rubrique,
    String requestType,
    String lieu,
    bool exigeCarteConsulaire,
    bool estPrerequisDeToutLeReste,
    String? resume,
    List<DemarchePiece> pieces,
    List<DemarchePiecesConditionnelles> piecesConditionnelles,
    DemarcheCout cout,
    String? delai,
    DemarcheJuridiction? juridictionCompetente,
    List<String> avertissements,
  });

  @override
  $DemarcheCoutCopyWith<$Res> get cout;
  @override
  $DemarcheJuridictionCopyWith<$Res>? get juridictionCompetente;
}

/// @nodoc
class __$$DemarcheImplCopyWithImpl<$Res>
    extends _$DemarcheCopyWithImpl<$Res, _$DemarcheImpl>
    implements _$$DemarcheImplCopyWith<$Res> {
  __$$DemarcheImplCopyWithImpl(
    _$DemarcheImpl _value,
    $Res Function(_$DemarcheImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Demarche
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? titre = null,
    Object? titreSource = freezed,
    Object? rubrique = null,
    Object? requestType = null,
    Object? lieu = null,
    Object? exigeCarteConsulaire = null,
    Object? estPrerequisDeToutLeReste = null,
    Object? resume = freezed,
    Object? pieces = null,
    Object? piecesConditionnelles = null,
    Object? cout = null,
    Object? delai = freezed,
    Object? juridictionCompetente = freezed,
    Object? avertissements = null,
  }) {
    return _then(
      _$DemarcheImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        titre:
            null == titre
                ? _value.titre
                : titre // ignore: cast_nullable_to_non_nullable
                    as String,
        titreSource:
            freezed == titreSource
                ? _value.titreSource
                : titreSource // ignore: cast_nullable_to_non_nullable
                    as String?,
        rubrique:
            null == rubrique
                ? _value.rubrique
                : rubrique // ignore: cast_nullable_to_non_nullable
                    as String,
        requestType:
            null == requestType
                ? _value.requestType
                : requestType // ignore: cast_nullable_to_non_nullable
                    as String,
        lieu:
            null == lieu
                ? _value.lieu
                : lieu // ignore: cast_nullable_to_non_nullable
                    as String,
        exigeCarteConsulaire:
            null == exigeCarteConsulaire
                ? _value.exigeCarteConsulaire
                : exigeCarteConsulaire // ignore: cast_nullable_to_non_nullable
                    as bool,
        estPrerequisDeToutLeReste:
            null == estPrerequisDeToutLeReste
                ? _value.estPrerequisDeToutLeReste
                : estPrerequisDeToutLeReste // ignore: cast_nullable_to_non_nullable
                    as bool,
        resume:
            freezed == resume
                ? _value.resume
                : resume // ignore: cast_nullable_to_non_nullable
                    as String?,
        pieces:
            null == pieces
                ? _value._pieces
                : pieces // ignore: cast_nullable_to_non_nullable
                    as List<DemarchePiece>,
        piecesConditionnelles:
            null == piecesConditionnelles
                ? _value._piecesConditionnelles
                : piecesConditionnelles // ignore: cast_nullable_to_non_nullable
                    as List<DemarchePiecesConditionnelles>,
        cout:
            null == cout
                ? _value.cout
                : cout // ignore: cast_nullable_to_non_nullable
                    as DemarcheCout,
        delai:
            freezed == delai
                ? _value.delai
                : delai // ignore: cast_nullable_to_non_nullable
                    as String?,
        juridictionCompetente:
            freezed == juridictionCompetente
                ? _value.juridictionCompetente
                : juridictionCompetente // ignore: cast_nullable_to_non_nullable
                    as DemarcheJuridiction?,
        avertissements:
            null == avertissements
                ? _value._avertissements
                : avertissements // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarcheImpl extends _Demarche {
  const _$DemarcheImpl({
    required this.id,
    required this.titre,
    this.titreSource,
    required this.rubrique,
    required this.requestType,
    this.lieu = 'consulat',
    this.exigeCarteConsulaire = false,
    this.estPrerequisDeToutLeReste = false,
    this.resume,
    final List<DemarchePiece> pieces = const <DemarchePiece>[],
    final List<DemarchePiecesConditionnelles> piecesConditionnelles =
        const <DemarchePiecesConditionnelles>[],
    required this.cout,
    this.delai,
    this.juridictionCompetente,
    final List<String> avertissements = const <String>[],
  }) : _pieces = pieces,
       _piecesConditionnelles = piecesConditionnelles,
       _avertissements = avertissements,
       super._();

  factory _$DemarcheImpl.fromJson(Map<String, dynamic> json) =>
      _$$DemarcheImplFromJson(json);

  @override
  final String id;
  @override
  final String titre;

  /// Intitulé d'origine, présent uniquement quand [titre] le corrige.
  ///
  /// Un seul cas aujourd'hui : la source titre « Passeport (prorogation) »
  /// une liste de pièces qui est en réalité celle d'une première demande.
  @override
  final String? titreSource;
  @override
  final String rubrique;
  @override
  final String requestType;

  /// `consulat` ou `tribunal_niger` — le certificat de nationalité est la
  /// seule démarche de la page qui ne se traite pas au consulat.
  @override
  @JsonKey()
  final String lieu;
  @override
  @JsonKey()
  final bool exigeCarteConsulaire;
  @override
  @JsonKey()
  final bool estPrerequisDeToutLeReste;
  @override
  final String? resume;
  final List<DemarchePiece> _pieces;
  @override
  @JsonKey()
  List<DemarchePiece> get pieces {
    if (_pieces is EqualUnmodifiableListView) return _pieces;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pieces);
  }

  final List<DemarchePiecesConditionnelles> _piecesConditionnelles;
  @override
  @JsonKey()
  List<DemarchePiecesConditionnelles> get piecesConditionnelles {
    if (_piecesConditionnelles is EqualUnmodifiableListView)
      return _piecesConditionnelles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_piecesConditionnelles);
  }

  @override
  final DemarcheCout cout;

  /// Toujours nul : la source ne publie aucun délai de traitement.
  @override
  final String? delai;
  @override
  final DemarcheJuridiction? juridictionCompetente;

  /// Défauts de la source touchant cette démarche (intitulé faux, pièce
  /// ambiguë, parenthèse tronquée…). Non vide sur 13 démarches sur 20.
  final List<String> _avertissements;

  /// Défauts de la source touchant cette démarche (intitulé faux, pièce
  /// ambiguë, parenthèse tronquée…). Non vide sur 13 démarches sur 20.
  @override
  @JsonKey()
  List<String> get avertissements {
    if (_avertissements is EqualUnmodifiableListView) return _avertissements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_avertissements);
  }

  @override
  String toString() {
    return 'Demarche(id: $id, titre: $titre, titreSource: $titreSource, rubrique: $rubrique, requestType: $requestType, lieu: $lieu, exigeCarteConsulaire: $exigeCarteConsulaire, estPrerequisDeToutLeReste: $estPrerequisDeToutLeReste, resume: $resume, pieces: $pieces, piecesConditionnelles: $piecesConditionnelles, cout: $cout, delai: $delai, juridictionCompetente: $juridictionCompetente, avertissements: $avertissements)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarcheImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.titre, titre) || other.titre == titre) &&
            (identical(other.titreSource, titreSource) ||
                other.titreSource == titreSource) &&
            (identical(other.rubrique, rubrique) ||
                other.rubrique == rubrique) &&
            (identical(other.requestType, requestType) ||
                other.requestType == requestType) &&
            (identical(other.lieu, lieu) || other.lieu == lieu) &&
            (identical(other.exigeCarteConsulaire, exigeCarteConsulaire) ||
                other.exigeCarteConsulaire == exigeCarteConsulaire) &&
            (identical(
                  other.estPrerequisDeToutLeReste,
                  estPrerequisDeToutLeReste,
                ) ||
                other.estPrerequisDeToutLeReste == estPrerequisDeToutLeReste) &&
            (identical(other.resume, resume) || other.resume == resume) &&
            const DeepCollectionEquality().equals(other._pieces, _pieces) &&
            const DeepCollectionEquality().equals(
              other._piecesConditionnelles,
              _piecesConditionnelles,
            ) &&
            (identical(other.cout, cout) || other.cout == cout) &&
            (identical(other.delai, delai) || other.delai == delai) &&
            (identical(other.juridictionCompetente, juridictionCompetente) ||
                other.juridictionCompetente == juridictionCompetente) &&
            const DeepCollectionEquality().equals(
              other._avertissements,
              _avertissements,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    titre,
    titreSource,
    rubrique,
    requestType,
    lieu,
    exigeCarteConsulaire,
    estPrerequisDeToutLeReste,
    resume,
    const DeepCollectionEquality().hash(_pieces),
    const DeepCollectionEquality().hash(_piecesConditionnelles),
    cout,
    delai,
    juridictionCompetente,
    const DeepCollectionEquality().hash(_avertissements),
  );

  /// Create a copy of Demarche
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarcheImplCopyWith<_$DemarcheImpl> get copyWith =>
      __$$DemarcheImplCopyWithImpl<_$DemarcheImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarcheImplToJson(this);
  }
}

abstract class _Demarche extends Demarche {
  const factory _Demarche({
    required final String id,
    required final String titre,
    final String? titreSource,
    required final String rubrique,
    required final String requestType,
    final String lieu,
    final bool exigeCarteConsulaire,
    final bool estPrerequisDeToutLeReste,
    final String? resume,
    final List<DemarchePiece> pieces,
    final List<DemarchePiecesConditionnelles> piecesConditionnelles,
    required final DemarcheCout cout,
    final String? delai,
    final DemarcheJuridiction? juridictionCompetente,
    final List<String> avertissements,
  }) = _$DemarcheImpl;
  const _Demarche._() : super._();

  factory _Demarche.fromJson(Map<String, dynamic> json) =
      _$DemarcheImpl.fromJson;

  @override
  String get id;
  @override
  String get titre;

  /// Intitulé d'origine, présent uniquement quand [titre] le corrige.
  ///
  /// Un seul cas aujourd'hui : la source titre « Passeport (prorogation) »
  /// une liste de pièces qui est en réalité celle d'une première demande.
  @override
  String? get titreSource;
  @override
  String get rubrique;
  @override
  String get requestType;

  /// `consulat` ou `tribunal_niger` — le certificat de nationalité est la
  /// seule démarche de la page qui ne se traite pas au consulat.
  @override
  String get lieu;
  @override
  bool get exigeCarteConsulaire;
  @override
  bool get estPrerequisDeToutLeReste;
  @override
  String? get resume;
  @override
  List<DemarchePiece> get pieces;
  @override
  List<DemarchePiecesConditionnelles> get piecesConditionnelles;
  @override
  DemarcheCout get cout;

  /// Toujours nul : la source ne publie aucun délai de traitement.
  @override
  String? get delai;
  @override
  DemarcheJuridiction? get juridictionCompetente;

  /// Défauts de la source touchant cette démarche (intitulé faux, pièce
  /// ambiguë, parenthèse tronquée…). Non vide sur 13 démarches sur 20.
  @override
  List<String> get avertissements;

  /// Create a copy of Demarche
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarcheImplCopyWith<_$DemarcheImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DemarchePiece _$DemarchePieceFromJson(Map<String, dynamic> json) {
  return _DemarchePiece.fromJson(json);
}

/// @nodoc
mixin _$DemarchePiece {
  String get libelle => throw _privateConstructorUsedError;

  /// `copie`, `original`, `original_et_copie`, `photo`, `temoin`,
  /// `formulaire`, `timbre_fiscal`, `attestation`, `document`,
  /// `liste_etablie_par_demandeur`.
  String get forme => throw _privateConstructorUsedError;

  /// Nul quand la source reste vague (« copie des pièces d'identité du
  /// défunt », sans dire combien).
  int? get quantite => throw _privateConstructorUsedError;
  bool get obligatoire => throw _privateConstructorUsedError;

  /// Pièces partageant cette clé : une seule d'entre elles suffit.
  String? get groupeAlternatif => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Serializes this DemarchePiece to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DemarchePiece
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarchePieceCopyWith<DemarchePiece> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarchePieceCopyWith<$Res> {
  factory $DemarchePieceCopyWith(
    DemarchePiece value,
    $Res Function(DemarchePiece) then,
  ) = _$DemarchePieceCopyWithImpl<$Res, DemarchePiece>;
  @useResult
  $Res call({
    String libelle,
    String forme,
    int? quantite,
    bool obligatoire,
    String? groupeAlternatif,
    String? note,
  });
}

/// @nodoc
class _$DemarchePieceCopyWithImpl<$Res, $Val extends DemarchePiece>
    implements $DemarchePieceCopyWith<$Res> {
  _$DemarchePieceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DemarchePiece
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? libelle = null,
    Object? forme = null,
    Object? quantite = freezed,
    Object? obligatoire = null,
    Object? groupeAlternatif = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            libelle:
                null == libelle
                    ? _value.libelle
                    : libelle // ignore: cast_nullable_to_non_nullable
                        as String,
            forme:
                null == forme
                    ? _value.forme
                    : forme // ignore: cast_nullable_to_non_nullable
                        as String,
            quantite:
                freezed == quantite
                    ? _value.quantite
                    : quantite // ignore: cast_nullable_to_non_nullable
                        as int?,
            obligatoire:
                null == obligatoire
                    ? _value.obligatoire
                    : obligatoire // ignore: cast_nullable_to_non_nullable
                        as bool,
            groupeAlternatif:
                freezed == groupeAlternatif
                    ? _value.groupeAlternatif
                    : groupeAlternatif // ignore: cast_nullable_to_non_nullable
                        as String?,
            note:
                freezed == note
                    ? _value.note
                    : note // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DemarchePieceImplCopyWith<$Res>
    implements $DemarchePieceCopyWith<$Res> {
  factory _$$DemarchePieceImplCopyWith(
    _$DemarchePieceImpl value,
    $Res Function(_$DemarchePieceImpl) then,
  ) = __$$DemarchePieceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String libelle,
    String forme,
    int? quantite,
    bool obligatoire,
    String? groupeAlternatif,
    String? note,
  });
}

/// @nodoc
class __$$DemarchePieceImplCopyWithImpl<$Res>
    extends _$DemarchePieceCopyWithImpl<$Res, _$DemarchePieceImpl>
    implements _$$DemarchePieceImplCopyWith<$Res> {
  __$$DemarchePieceImplCopyWithImpl(
    _$DemarchePieceImpl _value,
    $Res Function(_$DemarchePieceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DemarchePiece
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? libelle = null,
    Object? forme = null,
    Object? quantite = freezed,
    Object? obligatoire = null,
    Object? groupeAlternatif = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _$DemarchePieceImpl(
        libelle:
            null == libelle
                ? _value.libelle
                : libelle // ignore: cast_nullable_to_non_nullable
                    as String,
        forme:
            null == forme
                ? _value.forme
                : forme // ignore: cast_nullable_to_non_nullable
                    as String,
        quantite:
            freezed == quantite
                ? _value.quantite
                : quantite // ignore: cast_nullable_to_non_nullable
                    as int?,
        obligatoire:
            null == obligatoire
                ? _value.obligatoire
                : obligatoire // ignore: cast_nullable_to_non_nullable
                    as bool,
        groupeAlternatif:
            freezed == groupeAlternatif
                ? _value.groupeAlternatif
                : groupeAlternatif // ignore: cast_nullable_to_non_nullable
                    as String?,
        note:
            freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarchePieceImpl extends _DemarchePiece {
  const _$DemarchePieceImpl({
    required this.libelle,
    this.forme = 'copie',
    this.quantite,
    this.obligatoire = true,
    this.groupeAlternatif,
    this.note,
  }) : super._();

  factory _$DemarchePieceImpl.fromJson(Map<String, dynamic> json) =>
      _$$DemarchePieceImplFromJson(json);

  @override
  final String libelle;

  /// `copie`, `original`, `original_et_copie`, `photo`, `temoin`,
  /// `formulaire`, `timbre_fiscal`, `attestation`, `document`,
  /// `liste_etablie_par_demandeur`.
  @override
  @JsonKey()
  final String forme;

  /// Nul quand la source reste vague (« copie des pièces d'identité du
  /// défunt », sans dire combien).
  @override
  final int? quantite;
  @override
  @JsonKey()
  final bool obligatoire;

  /// Pièces partageant cette clé : une seule d'entre elles suffit.
  @override
  final String? groupeAlternatif;
  @override
  final String? note;

  @override
  String toString() {
    return 'DemarchePiece(libelle: $libelle, forme: $forme, quantite: $quantite, obligatoire: $obligatoire, groupeAlternatif: $groupeAlternatif, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarchePieceImpl &&
            (identical(other.libelle, libelle) || other.libelle == libelle) &&
            (identical(other.forme, forme) || other.forme == forme) &&
            (identical(other.quantite, quantite) ||
                other.quantite == quantite) &&
            (identical(other.obligatoire, obligatoire) ||
                other.obligatoire == obligatoire) &&
            (identical(other.groupeAlternatif, groupeAlternatif) ||
                other.groupeAlternatif == groupeAlternatif) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    libelle,
    forme,
    quantite,
    obligatoire,
    groupeAlternatif,
    note,
  );

  /// Create a copy of DemarchePiece
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarchePieceImplCopyWith<_$DemarchePieceImpl> get copyWith =>
      __$$DemarchePieceImplCopyWithImpl<_$DemarchePieceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarchePieceImplToJson(this);
  }
}

abstract class _DemarchePiece extends DemarchePiece {
  const factory _DemarchePiece({
    required final String libelle,
    final String forme,
    final int? quantite,
    final bool obligatoire,
    final String? groupeAlternatif,
    final String? note,
  }) = _$DemarchePieceImpl;
  const _DemarchePiece._() : super._();

  factory _DemarchePiece.fromJson(Map<String, dynamic> json) =
      _$DemarchePieceImpl.fromJson;

  @override
  String get libelle;

  /// `copie`, `original`, `original_et_copie`, `photo`, `temoin`,
  /// `formulaire`, `timbre_fiscal`, `attestation`, `document`,
  /// `liste_etablie_par_demandeur`.
  @override
  String get forme;

  /// Nul quand la source reste vague (« copie des pièces d'identité du
  /// défunt », sans dire combien).
  @override
  int? get quantite;
  @override
  bool get obligatoire;

  /// Pièces partageant cette clé : une seule d'entre elles suffit.
  @override
  String? get groupeAlternatif;
  @override
  String? get note;

  /// Create a copy of DemarchePiece
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarchePieceImplCopyWith<_$DemarchePieceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DemarchePiecesConditionnelles _$DemarchePiecesConditionnellesFromJson(
  Map<String, dynamic> json,
) {
  return _DemarchePiecesConditionnelles.fromJson(json);
}

/// @nodoc
mixin _$DemarchePiecesConditionnelles {
  String get condition => throw _privateConstructorUsedError;
  List<DemarchePiece> get pieces => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Serializes this DemarchePiecesConditionnelles to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DemarchePiecesConditionnelles
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarchePiecesConditionnellesCopyWith<DemarchePiecesConditionnelles>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarchePiecesConditionnellesCopyWith<$Res> {
  factory $DemarchePiecesConditionnellesCopyWith(
    DemarchePiecesConditionnelles value,
    $Res Function(DemarchePiecesConditionnelles) then,
  ) =
      _$DemarchePiecesConditionnellesCopyWithImpl<
        $Res,
        DemarchePiecesConditionnelles
      >;
  @useResult
  $Res call({String condition, List<DemarchePiece> pieces, String? note});
}

/// @nodoc
class _$DemarchePiecesConditionnellesCopyWithImpl<
  $Res,
  $Val extends DemarchePiecesConditionnelles
>
    implements $DemarchePiecesConditionnellesCopyWith<$Res> {
  _$DemarchePiecesConditionnellesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DemarchePiecesConditionnelles
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? condition = null,
    Object? pieces = null,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            condition:
                null == condition
                    ? _value.condition
                    : condition // ignore: cast_nullable_to_non_nullable
                        as String,
            pieces:
                null == pieces
                    ? _value.pieces
                    : pieces // ignore: cast_nullable_to_non_nullable
                        as List<DemarchePiece>,
            note:
                freezed == note
                    ? _value.note
                    : note // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DemarchePiecesConditionnellesImplCopyWith<$Res>
    implements $DemarchePiecesConditionnellesCopyWith<$Res> {
  factory _$$DemarchePiecesConditionnellesImplCopyWith(
    _$DemarchePiecesConditionnellesImpl value,
    $Res Function(_$DemarchePiecesConditionnellesImpl) then,
  ) = __$$DemarchePiecesConditionnellesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String condition, List<DemarchePiece> pieces, String? note});
}

/// @nodoc
class __$$DemarchePiecesConditionnellesImplCopyWithImpl<$Res>
    extends
        _$DemarchePiecesConditionnellesCopyWithImpl<
          $Res,
          _$DemarchePiecesConditionnellesImpl
        >
    implements _$$DemarchePiecesConditionnellesImplCopyWith<$Res> {
  __$$DemarchePiecesConditionnellesImplCopyWithImpl(
    _$DemarchePiecesConditionnellesImpl _value,
    $Res Function(_$DemarchePiecesConditionnellesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DemarchePiecesConditionnelles
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? condition = null,
    Object? pieces = null,
    Object? note = freezed,
  }) {
    return _then(
      _$DemarchePiecesConditionnellesImpl(
        condition:
            null == condition
                ? _value.condition
                : condition // ignore: cast_nullable_to_non_nullable
                    as String,
        pieces:
            null == pieces
                ? _value._pieces
                : pieces // ignore: cast_nullable_to_non_nullable
                    as List<DemarchePiece>,
        note:
            freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarchePiecesConditionnellesImpl
    implements _DemarchePiecesConditionnelles {
  const _$DemarchePiecesConditionnellesImpl({
    required this.condition,
    final List<DemarchePiece> pieces = const <DemarchePiece>[],
    this.note,
  }) : _pieces = pieces;

  factory _$DemarchePiecesConditionnellesImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$DemarchePiecesConditionnellesImplFromJson(json);

  @override
  final String condition;
  final List<DemarchePiece> _pieces;
  @override
  @JsonKey()
  List<DemarchePiece> get pieces {
    if (_pieces is EqualUnmodifiableListView) return _pieces;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pieces);
  }

  @override
  final String? note;

  @override
  String toString() {
    return 'DemarchePiecesConditionnelles(condition: $condition, pieces: $pieces, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarchePiecesConditionnellesImpl &&
            (identical(other.condition, condition) ||
                other.condition == condition) &&
            const DeepCollectionEquality().equals(other._pieces, _pieces) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    condition,
    const DeepCollectionEquality().hash(_pieces),
    note,
  );

  /// Create a copy of DemarchePiecesConditionnelles
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarchePiecesConditionnellesImplCopyWith<
    _$DemarchePiecesConditionnellesImpl
  >
  get copyWith => __$$DemarchePiecesConditionnellesImplCopyWithImpl<
    _$DemarchePiecesConditionnellesImpl
  >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarchePiecesConditionnellesImplToJson(this);
  }
}

abstract class _DemarchePiecesConditionnelles
    implements DemarchePiecesConditionnelles {
  const factory _DemarchePiecesConditionnelles({
    required final String condition,
    final List<DemarchePiece> pieces,
    final String? note,
  }) = _$DemarchePiecesConditionnellesImpl;

  factory _DemarchePiecesConditionnelles.fromJson(Map<String, dynamic> json) =
      _$DemarchePiecesConditionnellesImpl.fromJson;

  @override
  String get condition;
  @override
  List<DemarchePiece> get pieces;
  @override
  String? get note;

  /// Create a copy of DemarchePiecesConditionnelles
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarchePiecesConditionnellesImplCopyWith<
    _$DemarchePiecesConditionnellesImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

DemarcheCout _$DemarcheCoutFromJson(Map<String, dynamic> json) {
  return _DemarcheCout.fromJson(json);
}

/// @nodoc
mixin _$DemarcheCout {
  /// `connu`, `inconnu`, `non_mentionne` ou `variable_par_pays`.
  String get statut => throw _privateConstructorUsedError;
  String? get libelle => throw _privateConstructorUsedError;
  int? get montantXof => throw _privateConstructorUsedError;

  /// Serializes this DemarcheCout to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DemarcheCout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarcheCoutCopyWith<DemarcheCout> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarcheCoutCopyWith<$Res> {
  factory $DemarcheCoutCopyWith(
    DemarcheCout value,
    $Res Function(DemarcheCout) then,
  ) = _$DemarcheCoutCopyWithImpl<$Res, DemarcheCout>;
  @useResult
  $Res call({String statut, String? libelle, int? montantXof});
}

/// @nodoc
class _$DemarcheCoutCopyWithImpl<$Res, $Val extends DemarcheCout>
    implements $DemarcheCoutCopyWith<$Res> {
  _$DemarcheCoutCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DemarcheCout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statut = null,
    Object? libelle = freezed,
    Object? montantXof = freezed,
  }) {
    return _then(
      _value.copyWith(
            statut:
                null == statut
                    ? _value.statut
                    : statut // ignore: cast_nullable_to_non_nullable
                        as String,
            libelle:
                freezed == libelle
                    ? _value.libelle
                    : libelle // ignore: cast_nullable_to_non_nullable
                        as String?,
            montantXof:
                freezed == montantXof
                    ? _value.montantXof
                    : montantXof // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DemarcheCoutImplCopyWith<$Res>
    implements $DemarcheCoutCopyWith<$Res> {
  factory _$$DemarcheCoutImplCopyWith(
    _$DemarcheCoutImpl value,
    $Res Function(_$DemarcheCoutImpl) then,
  ) = __$$DemarcheCoutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String statut, String? libelle, int? montantXof});
}

/// @nodoc
class __$$DemarcheCoutImplCopyWithImpl<$Res>
    extends _$DemarcheCoutCopyWithImpl<$Res, _$DemarcheCoutImpl>
    implements _$$DemarcheCoutImplCopyWith<$Res> {
  __$$DemarcheCoutImplCopyWithImpl(
    _$DemarcheCoutImpl _value,
    $Res Function(_$DemarcheCoutImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DemarcheCout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? statut = null,
    Object? libelle = freezed,
    Object? montantXof = freezed,
  }) {
    return _then(
      _$DemarcheCoutImpl(
        statut:
            null == statut
                ? _value.statut
                : statut // ignore: cast_nullable_to_non_nullable
                    as String,
        libelle:
            freezed == libelle
                ? _value.libelle
                : libelle // ignore: cast_nullable_to_non_nullable
                    as String?,
        montantXof:
            freezed == montantXof
                ? _value.montantXof
                : montantXof // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarcheCoutImpl extends _DemarcheCout {
  const _$DemarcheCoutImpl({
    this.statut = 'inconnu',
    this.libelle,
    this.montantXof,
  }) : super._();

  factory _$DemarcheCoutImpl.fromJson(Map<String, dynamic> json) =>
      _$$DemarcheCoutImplFromJson(json);

  /// `connu`, `inconnu`, `non_mentionne` ou `variable_par_pays`.
  @override
  @JsonKey()
  final String statut;
  @override
  final String? libelle;
  @override
  final int? montantXof;

  @override
  String toString() {
    return 'DemarcheCout(statut: $statut, libelle: $libelle, montantXof: $montantXof)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarcheCoutImpl &&
            (identical(other.statut, statut) || other.statut == statut) &&
            (identical(other.libelle, libelle) || other.libelle == libelle) &&
            (identical(other.montantXof, montantXof) ||
                other.montantXof == montantXof));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, statut, libelle, montantXof);

  /// Create a copy of DemarcheCout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarcheCoutImplCopyWith<_$DemarcheCoutImpl> get copyWith =>
      __$$DemarcheCoutImplCopyWithImpl<_$DemarcheCoutImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarcheCoutImplToJson(this);
  }
}

abstract class _DemarcheCout extends DemarcheCout {
  const factory _DemarcheCout({
    final String statut,
    final String? libelle,
    final int? montantXof,
  }) = _$DemarcheCoutImpl;
  const _DemarcheCout._() : super._();

  factory _DemarcheCout.fromJson(Map<String, dynamic> json) =
      _$DemarcheCoutImpl.fromJson;

  /// `connu`, `inconnu`, `non_mentionne` ou `variable_par_pays`.
  @override
  String get statut;
  @override
  String? get libelle;
  @override
  int? get montantXof;

  /// Create a copy of DemarcheCout
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarcheCoutImplCopyWith<_$DemarcheCoutImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DemarcheJuridiction _$DemarcheJuridictionFromJson(Map<String, dynamic> json) {
  return _DemarcheJuridiction.fromJson(json);
}

/// @nodoc
mixin _$DemarcheJuridiction {
  String get autorite => throw _privateConstructorUsedError;
  List<String> get regles => throw _privateConstructorUsedError;

  /// Serializes this DemarcheJuridiction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DemarcheJuridiction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DemarcheJuridictionCopyWith<DemarcheJuridiction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DemarcheJuridictionCopyWith<$Res> {
  factory $DemarcheJuridictionCopyWith(
    DemarcheJuridiction value,
    $Res Function(DemarcheJuridiction) then,
  ) = _$DemarcheJuridictionCopyWithImpl<$Res, DemarcheJuridiction>;
  @useResult
  $Res call({String autorite, List<String> regles});
}

/// @nodoc
class _$DemarcheJuridictionCopyWithImpl<$Res, $Val extends DemarcheJuridiction>
    implements $DemarcheJuridictionCopyWith<$Res> {
  _$DemarcheJuridictionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DemarcheJuridiction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? autorite = null, Object? regles = null}) {
    return _then(
      _value.copyWith(
            autorite:
                null == autorite
                    ? _value.autorite
                    : autorite // ignore: cast_nullable_to_non_nullable
                        as String,
            regles:
                null == regles
                    ? _value.regles
                    : regles // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DemarcheJuridictionImplCopyWith<$Res>
    implements $DemarcheJuridictionCopyWith<$Res> {
  factory _$$DemarcheJuridictionImplCopyWith(
    _$DemarcheJuridictionImpl value,
    $Res Function(_$DemarcheJuridictionImpl) then,
  ) = __$$DemarcheJuridictionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String autorite, List<String> regles});
}

/// @nodoc
class __$$DemarcheJuridictionImplCopyWithImpl<$Res>
    extends _$DemarcheJuridictionCopyWithImpl<$Res, _$DemarcheJuridictionImpl>
    implements _$$DemarcheJuridictionImplCopyWith<$Res> {
  __$$DemarcheJuridictionImplCopyWithImpl(
    _$DemarcheJuridictionImpl _value,
    $Res Function(_$DemarcheJuridictionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DemarcheJuridiction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? autorite = null, Object? regles = null}) {
    return _then(
      _$DemarcheJuridictionImpl(
        autorite:
            null == autorite
                ? _value.autorite
                : autorite // ignore: cast_nullable_to_non_nullable
                    as String,
        regles:
            null == regles
                ? _value._regles
                : regles // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DemarcheJuridictionImpl implements _DemarcheJuridiction {
  const _$DemarcheJuridictionImpl({
    required this.autorite,
    final List<String> regles = const <String>[],
  }) : _regles = regles;

  factory _$DemarcheJuridictionImpl.fromJson(Map<String, dynamic> json) =>
      _$$DemarcheJuridictionImplFromJson(json);

  @override
  final String autorite;
  final List<String> _regles;
  @override
  @JsonKey()
  List<String> get regles {
    if (_regles is EqualUnmodifiableListView) return _regles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_regles);
  }

  @override
  String toString() {
    return 'DemarcheJuridiction(autorite: $autorite, regles: $regles)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DemarcheJuridictionImpl &&
            (identical(other.autorite, autorite) ||
                other.autorite == autorite) &&
            const DeepCollectionEquality().equals(other._regles, _regles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    autorite,
    const DeepCollectionEquality().hash(_regles),
  );

  /// Create a copy of DemarcheJuridiction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DemarcheJuridictionImplCopyWith<_$DemarcheJuridictionImpl> get copyWith =>
      __$$DemarcheJuridictionImplCopyWithImpl<_$DemarcheJuridictionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DemarcheJuridictionImplToJson(this);
  }
}

abstract class _DemarcheJuridiction implements DemarcheJuridiction {
  const factory _DemarcheJuridiction({
    required final String autorite,
    final List<String> regles,
  }) = _$DemarcheJuridictionImpl;

  factory _DemarcheJuridiction.fromJson(Map<String, dynamic> json) =
      _$DemarcheJuridictionImpl.fromJson;

  @override
  String get autorite;
  @override
  List<String> get regles;

  /// Create a copy of DemarcheJuridiction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DemarcheJuridictionImplCopyWith<_$DemarcheJuridictionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
