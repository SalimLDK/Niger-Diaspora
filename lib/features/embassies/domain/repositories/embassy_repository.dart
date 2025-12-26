import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/embassy_entity.dart';

abstract class EmbassyRepository {
  Future<Either<Failure, List<EmbassyEntity>>> getEmbassies();
}
