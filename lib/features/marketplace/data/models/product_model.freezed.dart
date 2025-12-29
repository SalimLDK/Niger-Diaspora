// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProductModel _$ProductModelFromJson(Map<String, dynamic> json) {
  return _ProductModel.fromJson(json);
}

/// @nodoc
mixin _$ProductModel {
  String get id => throw _privateConstructorUsedError;
  String get sellerId => throw _privateConstructorUsedError;
  String? get sellerName => throw _privateConstructorUsedError;
  String? get sellerPhotoUrl => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  String get condition => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  String? get country =>
      throw _privateConstructorUsedError; // Country name for filtering
  bool get isAvailable => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  int get viewCount => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError; // Tax settings
  bool get isTaxable => throw _privateConstructorUsedError;
  double? get customTaxRate => throw _privateConstructorUsedError;
  bool get taxIncludedInPrice => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ProductModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductModelCopyWith<ProductModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductModelCopyWith<$Res> {
  factory $ProductModelCopyWith(
    ProductModel value,
    $Res Function(ProductModel) then,
  ) = _$ProductModelCopyWithImpl<$Res, ProductModel>;
  @useResult
  $Res call({
    String id,
    String sellerId,
    String? sellerName,
    String? sellerPhotoUrl,
    String title,
    String description,
    double price,
    String currency,
    List<String> imageUrls,
    String category,
    String condition,
    String? location,
    String? country,
    bool isAvailable,
    int quantity,
    int viewCount,
    List<String> tags,
    bool isTaxable,
    double? customTaxRate,
    bool taxIncludedInPrice,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class _$ProductModelCopyWithImpl<$Res, $Val extends ProductModel>
    implements $ProductModelCopyWith<$Res> {
  _$ProductModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sellerId = null,
    Object? sellerName = freezed,
    Object? sellerPhotoUrl = freezed,
    Object? title = null,
    Object? description = null,
    Object? price = null,
    Object? currency = null,
    Object? imageUrls = null,
    Object? category = null,
    Object? condition = null,
    Object? location = freezed,
    Object? country = freezed,
    Object? isAvailable = null,
    Object? quantity = null,
    Object? viewCount = null,
    Object? tags = null,
    Object? isTaxable = null,
    Object? customTaxRate = freezed,
    Object? taxIncludedInPrice = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            sellerId:
                null == sellerId
                    ? _value.sellerId
                    : sellerId // ignore: cast_nullable_to_non_nullable
                        as String,
            sellerName:
                freezed == sellerName
                    ? _value.sellerName
                    : sellerName // ignore: cast_nullable_to_non_nullable
                        as String?,
            sellerPhotoUrl:
                freezed == sellerPhotoUrl
                    ? _value.sellerPhotoUrl
                    : sellerPhotoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
            price:
                null == price
                    ? _value.price
                    : price // ignore: cast_nullable_to_non_nullable
                        as double,
            currency:
                null == currency
                    ? _value.currency
                    : currency // ignore: cast_nullable_to_non_nullable
                        as String,
            imageUrls:
                null == imageUrls
                    ? _value.imageUrls
                    : imageUrls // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            category:
                null == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as String,
            condition:
                null == condition
                    ? _value.condition
                    : condition // ignore: cast_nullable_to_non_nullable
                        as String,
            location:
                freezed == location
                    ? _value.location
                    : location // ignore: cast_nullable_to_non_nullable
                        as String?,
            country:
                freezed == country
                    ? _value.country
                    : country // ignore: cast_nullable_to_non_nullable
                        as String?,
            isAvailable:
                null == isAvailable
                    ? _value.isAvailable
                    : isAvailable // ignore: cast_nullable_to_non_nullable
                        as bool,
            quantity:
                null == quantity
                    ? _value.quantity
                    : quantity // ignore: cast_nullable_to_non_nullable
                        as int,
            viewCount:
                null == viewCount
                    ? _value.viewCount
                    : viewCount // ignore: cast_nullable_to_non_nullable
                        as int,
            tags:
                null == tags
                    ? _value.tags
                    : tags // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            isTaxable:
                null == isTaxable
                    ? _value.isTaxable
                    : isTaxable // ignore: cast_nullable_to_non_nullable
                        as bool,
            customTaxRate:
                freezed == customTaxRate
                    ? _value.customTaxRate
                    : customTaxRate // ignore: cast_nullable_to_non_nullable
                        as double?,
            taxIncludedInPrice:
                null == taxIncludedInPrice
                    ? _value.taxIncludedInPrice
                    : taxIncludedInPrice // ignore: cast_nullable_to_non_nullable
                        as bool,
            createdAt:
                freezed == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductModelImplCopyWith<$Res>
    implements $ProductModelCopyWith<$Res> {
  factory _$$ProductModelImplCopyWith(
    _$ProductModelImpl value,
    $Res Function(_$ProductModelImpl) then,
  ) = __$$ProductModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String sellerId,
    String? sellerName,
    String? sellerPhotoUrl,
    String title,
    String description,
    double price,
    String currency,
    List<String> imageUrls,
    String category,
    String condition,
    String? location,
    String? country,
    bool isAvailable,
    int quantity,
    int viewCount,
    List<String> tags,
    bool isTaxable,
    double? customTaxRate,
    bool taxIncludedInPrice,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ProductModelImplCopyWithImpl<$Res>
    extends _$ProductModelCopyWithImpl<$Res, _$ProductModelImpl>
    implements _$$ProductModelImplCopyWith<$Res> {
  __$$ProductModelImplCopyWithImpl(
    _$ProductModelImpl _value,
    $Res Function(_$ProductModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sellerId = null,
    Object? sellerName = freezed,
    Object? sellerPhotoUrl = freezed,
    Object? title = null,
    Object? description = null,
    Object? price = null,
    Object? currency = null,
    Object? imageUrls = null,
    Object? category = null,
    Object? condition = null,
    Object? location = freezed,
    Object? country = freezed,
    Object? isAvailable = null,
    Object? quantity = null,
    Object? viewCount = null,
    Object? tags = null,
    Object? isTaxable = null,
    Object? customTaxRate = freezed,
    Object? taxIncludedInPrice = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ProductModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        sellerId:
            null == sellerId
                ? _value.sellerId
                : sellerId // ignore: cast_nullable_to_non_nullable
                    as String,
        sellerName:
            freezed == sellerName
                ? _value.sellerName
                : sellerName // ignore: cast_nullable_to_non_nullable
                    as String?,
        sellerPhotoUrl:
            freezed == sellerPhotoUrl
                ? _value.sellerPhotoUrl
                : sellerPhotoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
        price:
            null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                    as double,
        currency:
            null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                    as String,
        imageUrls:
            null == imageUrls
                ? _value._imageUrls
                : imageUrls // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        category:
            null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as String,
        condition:
            null == condition
                ? _value.condition
                : condition // ignore: cast_nullable_to_non_nullable
                    as String,
        location:
            freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                    as String?,
        country:
            freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                    as String?,
        isAvailable:
            null == isAvailable
                ? _value.isAvailable
                : isAvailable // ignore: cast_nullable_to_non_nullable
                    as bool,
        quantity:
            null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                    as int,
        viewCount:
            null == viewCount
                ? _value.viewCount
                : viewCount // ignore: cast_nullable_to_non_nullable
                    as int,
        tags:
            null == tags
                ? _value._tags
                : tags // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        isTaxable:
            null == isTaxable
                ? _value.isTaxable
                : isTaxable // ignore: cast_nullable_to_non_nullable
                    as bool,
        customTaxRate:
            freezed == customTaxRate
                ? _value.customTaxRate
                : customTaxRate // ignore: cast_nullable_to_non_nullable
                    as double?,
        taxIncludedInPrice:
            null == taxIncludedInPrice
                ? _value.taxIncludedInPrice
                : taxIncludedInPrice // ignore: cast_nullable_to_non_nullable
                    as bool,
        createdAt:
            freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductModelImpl extends _ProductModel {
  const _$ProductModelImpl({
    required this.id,
    required this.sellerId,
    this.sellerName,
    this.sellerPhotoUrl,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'XOF',
    final List<String> imageUrls = const [],
    this.category = 'other',
    this.condition = 'newProduct',
    this.location,
    this.country,
    this.isAvailable = true,
    this.quantity = 1,
    this.viewCount = 0,
    final List<String> tags = const [],
    this.isTaxable = true,
    this.customTaxRate,
    this.taxIncludedInPrice = false,
    @TimestampConverter() this.createdAt,
    @TimestampConverter() this.updatedAt,
  }) : _imageUrls = imageUrls,
       _tags = tags,
       super._();

  factory _$ProductModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductModelImplFromJson(json);

  @override
  final String id;
  @override
  final String sellerId;
  @override
  final String? sellerName;
  @override
  final String? sellerPhotoUrl;
  @override
  final String title;
  @override
  final String description;
  @override
  final double price;
  @override
  @JsonKey()
  final String currency;
  final List<String> _imageUrls;
  @override
  @JsonKey()
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey()
  final String condition;
  @override
  final String? location;
  @override
  final String? country;
  // Country name for filtering
  @override
  @JsonKey()
  final bool isAvailable;
  @override
  @JsonKey()
  final int quantity;
  @override
  @JsonKey()
  final int viewCount;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  // Tax settings
  @override
  @JsonKey()
  final bool isTaxable;
  @override
  final double? customTaxRate;
  @override
  @JsonKey()
  final bool taxIncludedInPrice;
  @override
  @TimestampConverter()
  final DateTime? createdAt;
  @override
  @TimestampConverter()
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ProductModel(id: $id, sellerId: $sellerId, sellerName: $sellerName, sellerPhotoUrl: $sellerPhotoUrl, title: $title, description: $description, price: $price, currency: $currency, imageUrls: $imageUrls, category: $category, condition: $condition, location: $location, country: $country, isAvailable: $isAvailable, quantity: $quantity, viewCount: $viewCount, tags: $tags, isTaxable: $isTaxable, customTaxRate: $customTaxRate, taxIncludedInPrice: $taxIncludedInPrice, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sellerId, sellerId) ||
                other.sellerId == sellerId) &&
            (identical(other.sellerName, sellerName) ||
                other.sellerName == sellerName) &&
            (identical(other.sellerPhotoUrl, sellerPhotoUrl) ||
                other.sellerPhotoUrl == sellerPhotoUrl) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            const DeepCollectionEquality().equals(
              other._imageUrls,
              _imageUrls,
            ) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.condition, condition) ||
                other.condition == condition) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.isTaxable, isTaxable) ||
                other.isTaxable == isTaxable) &&
            (identical(other.customTaxRate, customTaxRate) ||
                other.customTaxRate == customTaxRate) &&
            (identical(other.taxIncludedInPrice, taxIncludedInPrice) ||
                other.taxIncludedInPrice == taxIncludedInPrice) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    sellerId,
    sellerName,
    sellerPhotoUrl,
    title,
    description,
    price,
    currency,
    const DeepCollectionEquality().hash(_imageUrls),
    category,
    condition,
    location,
    country,
    isAvailable,
    quantity,
    viewCount,
    const DeepCollectionEquality().hash(_tags),
    isTaxable,
    customTaxRate,
    taxIncludedInPrice,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductModelImplCopyWith<_$ProductModelImpl> get copyWith =>
      __$$ProductModelImplCopyWithImpl<_$ProductModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductModelImplToJson(this);
  }
}

abstract class _ProductModel extends ProductModel {
  const factory _ProductModel({
    required final String id,
    required final String sellerId,
    final String? sellerName,
    final String? sellerPhotoUrl,
    required final String title,
    required final String description,
    required final double price,
    final String currency,
    final List<String> imageUrls,
    final String category,
    final String condition,
    final String? location,
    final String? country,
    final bool isAvailable,
    final int quantity,
    final int viewCount,
    final List<String> tags,
    final bool isTaxable,
    final double? customTaxRate,
    final bool taxIncludedInPrice,
    @TimestampConverter() final DateTime? createdAt,
    @TimestampConverter() final DateTime? updatedAt,
  }) = _$ProductModelImpl;
  const _ProductModel._() : super._();

  factory _ProductModel.fromJson(Map<String, dynamic> json) =
      _$ProductModelImpl.fromJson;

  @override
  String get id;
  @override
  String get sellerId;
  @override
  String? get sellerName;
  @override
  String? get sellerPhotoUrl;
  @override
  String get title;
  @override
  String get description;
  @override
  double get price;
  @override
  String get currency;
  @override
  List<String> get imageUrls;
  @override
  String get category;
  @override
  String get condition;
  @override
  String? get location;
  @override
  String? get country; // Country name for filtering
  @override
  bool get isAvailable;
  @override
  int get quantity;
  @override
  int get viewCount;
  @override
  List<String> get tags; // Tax settings
  @override
  bool get isTaxable;
  @override
  double? get customTaxRate;
  @override
  bool get taxIncludedInPrice;
  @override
  @TimestampConverter()
  DateTime? get createdAt;
  @override
  @TimestampConverter()
  DateTime? get updatedAt;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductModelImplCopyWith<_$ProductModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
