import '../../domain/entities/embassy_entity.dart';

abstract class EmbassiesRepository {
  Future<List<EmbassyEntity>> getEmbassies();
  Future<EmbassyEntity?> getEmbassyById(String id);
  Future<List<EmbassyEntity>> searchEmbassies(String query);
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  });
}
