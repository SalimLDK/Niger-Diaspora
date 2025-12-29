import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_boost_entity.dart';
import '../../domain/repositories/business_repository.dart';
import '../datasources/business_remote_datasource.dart';
import '../models/business_model.dart';
import '../models/business_boost_model.dart';
import '../../../../core/services/stripe_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  final BusinessRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  BusinessRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<BusinessEntity>>> getBusinesses({
    bool featuredFirst = true,
    int limit = 20,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final businesses = await remoteDataSource.getBusinesses(
        featuredFirst: featuredFirst,
        limit: limit,
      );
      return Right(businesses.map((b) => b.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<BusinessEntity>>> getBusinessesByCategory(
    BusinessCategory category,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final businesses = await remoteDataSource.getBusinessesByCategory(
        category.name,
      );
      return Right(businesses.map((b) => b.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<BusinessEntity>>> searchBusinesses(
    String query,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final businesses = await remoteDataSource.searchBusinesses(query);
      return Right(businesses.map((b) => b.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<BusinessEntity>>> getNearbyBusinesses(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final businesses = await remoteDataSource.getNearbyBusinesses(
        latitude,
        longitude,
        radiusKm,
      );
      return Right(businesses.map((b) => b.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<BusinessEntity>>> getBusinessesByLocation({
    String? country,
    String? city,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final businesses = await remoteDataSource.getBusinessesByLocation(
        country: country,
        city: city,
      );
      return Right(businesses.map((b) => b.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BusinessEntity>> getBusinessById(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final business = await remoteDataSource.getBusinessById(id);
      return Right(business.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BusinessEntity?>> getMyBusiness(String ownerId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final business = await remoteDataSource.getMyBusiness(ownerId);
      return Right(business?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BusinessEntity>> createBusiness(
    BusinessEntity business,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final businessModel = BusinessModel.fromEntity(business);
      final created = await remoteDataSource.createBusiness(businessModel);
      return Right(created.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BusinessEntity>> updateBusiness(
    BusinessEntity business,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final businessModel = BusinessModel.fromEntity(business);
      final updated = await remoteDataSource.updateBusiness(businessModel);
      return Right(updated.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBusiness(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      await remoteDataSource.deleteBusiness(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> incrementViewCount(String businessId) async {
    if (!await networkInfo.isConnected) {
      return const Right(null); // Silently fail if offline
    }
    try {
      await remoteDataSource.incrementViewCount(businessId);
      return const Right(null);
    } on ServerException {
      return const Right(null); // Silently fail
    }
  }

  @override
  Future<Either<Failure, BusinessBoostEntity>> purchaseBoost({
    required String businessId,
    required BoostType type,
    required BoostDuration duration,
    required String paymentMethod,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return const Left(ServerFailure('Utilisateur doit être connecté'));
      }

      // Calculer le prix
      final amount = type.getPrice(duration);

      // Calculer les dates
      final now = DateTime.now();
      final endDate = now.add(Duration(days: duration.days));

      String paymentReference;

      if (paymentMethod == 'stripe') {
        final transactionId = const Uuid().v4();

        // Initialiser Stripe si nécessaire (sécurité)
        if (!StripeService.instance.validateConfiguration()) {
          await StripeService.instance.initialize();
        }

        final paymentIntentId = await StripeService.instance.processPayment(
          amount: amount,
          currency: 'XOF',
          userId: user.uid,
          transactionId: transactionId,
          metadata: {
            'businessId': businessId,
            'boostType': type.name,
            'duration': duration.name,
          },
        );

        if (paymentIntentId == null) {
          return const Left(ServerFailure('Paiement annulé'));
        }
        paymentReference = paymentIntentId;
      } else {
        // Simulation ou autre méthode
        paymentReference = const Uuid().v4();
      }

      // Créer le boost
      final boostModel = BusinessBoostModel(
        id: '', // Sera généré par Firestore
        businessId: businessId,
        userId: user.uid,
        type: type.name,
        duration: duration.name,
        amount: amount,
        currency: 'XOF',
        startDate: now,
        endDate: endDate,
        status: 'active',
        paymentReference: paymentReference,
        createdAt: now,
      );

      final created = await remoteDataSource.createBoost(boostModel);
      return Right(created.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<BusinessBoostEntity>>> getBoostHistory(
    String businessId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final boosts = await remoteDataSource.getBoostHistory(businessId);
      return Right(boosts.map((b) => b.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BusinessBoostEntity?>> getActiveBoost(
    String businessId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final boost = await remoteDataSource.getActiveBoost(businessId);
      return Right(boost?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
