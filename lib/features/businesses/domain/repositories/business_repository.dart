import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/business_entity.dart';
import '../entities/business_boost_entity.dart';

abstract class BusinessRepository {
  // Businesses - Read
  Future<Either<Failure, List<BusinessEntity>>> getBusinesses({
    bool featuredFirst = true,
    int limit = 20,
  });
  Future<Either<Failure, List<BusinessEntity>>> getBusinessesByCategory(
    BusinessCategory category,
  );
  Future<Either<Failure, List<BusinessEntity>>> searchBusinesses(String query);
  Future<Either<Failure, List<BusinessEntity>>> getNearbyBusinesses(
    double latitude,
    double longitude,
    double radiusKm,
  );
  Future<Either<Failure, List<BusinessEntity>>> getBusinessesByLocation({
    String? country,
    String? city,
  });
  Future<Either<Failure, BusinessEntity>> getBusinessById(String id);
  Future<Either<Failure, BusinessEntity?>> getMyBusiness(String ownerId);

  // Businesses - Write
  Future<Either<Failure, BusinessEntity>> createBusiness(BusinessEntity business);
  Future<Either<Failure, BusinessEntity>> updateBusiness(BusinessEntity business);
  Future<Either<Failure, void>> deleteBusiness(String id);
  Future<Either<Failure, void>> incrementViewCount(String businessId);

  // Boosts
  Future<Either<Failure, BusinessBoostEntity>> purchaseBoost({
    required String businessId,
    required BoostType type,
    required BoostDuration duration,
    required String paymentMethod,
  });
  Future<Either<Failure, List<BusinessBoostEntity>>> getBoostHistory(String businessId);
  Future<Either<Failure, BusinessBoostEntity?>> getActiveBoost(String businessId);
}
