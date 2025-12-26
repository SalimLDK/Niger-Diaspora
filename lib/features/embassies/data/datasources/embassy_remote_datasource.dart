import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/embassy_model.dart';

abstract class EmbassyRemoteDataSource {
  Future<List<EmbassyModel>> getEmbassies();
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  });
}

class EmbassyRemoteDataSourceImpl implements EmbassyRemoteDataSource {
  final FirebaseFirestore _firestore;

  EmbassyRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<EmbassyModel>> getEmbassies() async {
    try {
      final querySnapshot =
          await _firestore
              .collection(
                'embassies',
              ) // Assuming collection name is 'embassies'
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return EmbassyModel.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la récupération des ambassades',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (isVerified != null) updateData['isVerified'] = isVerified;
      if (isSuspended != null) updateData['isSuspended'] = isSuspended;
      if (rejectionReason != null)
        updateData['rejectionReason'] = rejectionReason;
      if (isVerified == true)
        updateData['verifiedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('embassies').doc(id).update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour du statut',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
