import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class OnboardingRepository {
  Future<Either<Failure, bool>> hasSeenOnboarding();
  Future<Either<Failure, void>> markOnboardingComplete();
  Future<Either<Failure, bool>> hasSeenCoachMarks();
  Future<Either<Failure, void>> markCoachMarksComplete();
}
