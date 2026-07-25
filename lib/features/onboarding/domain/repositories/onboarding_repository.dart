import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class OnboardingRepository {
  Future<Either<Failure, bool>> hasSeenOnboarding();
  Future<Either<Failure, void>> markOnboardingComplete();
  Future<Either<Failure, bool>> hasSeenCoachMarks();
  Future<Either<Failure, void>> markCoachMarksComplete();
  Future<Either<Failure, bool>> hasGivenConsent();
  Future<Either<Failure, void>> markConsentGiven();
  Future<Either<Failure, bool>> hasCompletedProfileConfig();
  Future<Either<Failure, void>> markProfileConfigComplete();
}
