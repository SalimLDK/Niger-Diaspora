import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/product_entity.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';

@freezed
class ProductModel with _$ProductModel {
  const ProductModel._();

  const factory ProductModel({
    required String id,
    required String sellerId,
    String? sellerName,
    String? sellerPhotoUrl,
    required String title,
    required String description,
    required double price,
    @Default('XOF') String currency,
    @Default([]) List<String> imageUrls,
    @Default('other') String category,
    @Default('newProduct') String condition,
    String? location,
    String? country, // Country name for filtering
    @Default(true) bool isAvailable,
    @Default(1) int quantity,
    @Default(0) int viewCount,
    @Default([]) List<String> tags,
    // Tax settings
    @Default(true) bool isTaxable,
    double? customTaxRate,
    @Default(false) bool taxIncludedInPrice,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json) =>
      _$ProductModelFromJson(json);

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert Timestamps to DateTime
    final processedData = <String, dynamic>{'id': doc.id};
    data.forEach((key, value) {
      if (value is Timestamp) {
        processedData[key] = value.toDate();
      } else {
        processedData[key] = value;
      }
    });

    return ProductModel.fromJson(processedData);
  }

  factory ProductModel.fromEntity(ProductEntity entity) {
    return ProductModel(
      id: entity.id,
      sellerId: entity.sellerId,
      sellerName: entity.sellerName,
      sellerPhotoUrl: entity.sellerPhotoUrl,
      title: entity.title,
      description: entity.description,
      price: entity.price,
      currency: entity.currency,
      imageUrls: entity.imageUrls,
      category: entity.category.name,
      condition: entity.condition.name,
      location: entity.location,
      country: entity.country?.name,
      isAvailable: entity.isAvailable,
      quantity: entity.quantity,
      viewCount: entity.viewCount,
      tags: entity.tags,
      isTaxable: entity.isTaxable,
      customTaxRate: entity.customTaxRate,
      taxIncludedInPrice: entity.taxIncludedInPrice,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerPhotoUrl: sellerPhotoUrl,
      title: title,
      description: description,
      price: price,
      currency: currency,
      imageUrls: imageUrls,
      category: ProductCategory.values.firstWhere(
        (e) => e.name == category,
        orElse: () => ProductCategory.other,
      ),
      condition: ProductCondition.values.firstWhere(
        (e) => e.name == condition,
        orElse: () => ProductCondition.newProduct,
      ),
      location: location,
      country: country != null
          ? Country.values.firstWhere(
              (e) => e.name == country,
              orElse: () => Country.other,
            )
          : null,
      isAvailable: isAvailable,
      quantity: quantity,
      viewCount: viewCount,
      tags: tags,
      isTaxable: isTaxable,
      customTaxRate: customTaxRate,
      taxIncludedInPrice: taxIncludedInPrice,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}

class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value).toLocal();
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}
