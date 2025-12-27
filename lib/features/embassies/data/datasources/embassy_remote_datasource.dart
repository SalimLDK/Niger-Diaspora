import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/embassy_model.dart';
import '../models/embassy_message_model.dart';
import '../models/embassy_employee_model.dart';
import '../models/administrative_request_model.dart';

abstract class EmbassyRemoteDataSource {
  // Embassy CRUD
  Future<List<EmbassyModel>> getEmbassies();
  Future<EmbassyModel?> getEmbassyById(String id);
  Future<String> createEmbassy(EmbassyModel embassy);
  Future<void> updateEmbassy(String id, Map<String, dynamic> data);
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  });
  Future<void> updateEmbassyAvailability(
    String id, {
    bool? isTemporarilyClosed,
    String? closureMessage,
    DateTime? reopenDate,
  });

  // Embassy Messages
  Future<void> sendMessageToEmbassy({
    required String embassyId,
    required String userId,
    required String subject,
    required String content,
    required EmbassyMessageType messageType,
    String? userName,
    String? userPhotoUrl,
    String? userEmail,
  });
  Stream<List<EmbassyMessageModel>> getUserEmbassyMessages(String userId);
  Stream<List<EmbassyMessageModel>> getEmbassyInbox(String embassyId);
  Future<void> updateMessageStatus(
    String messageId,
    EmbassyMessageStatus status, {
    String? replyContent,
    String? repliedBy,
  });

  // Embassy Employees
  Future<List<EmbassyEmployeeModel>> searchEmployees({
    String? query,
    String? embassyId,
    String? department,
  });
  Future<void> addEmployee(EmbassyEmployeeModel employee);
  Future<void> updateEmployee(String id, Map<String, dynamic> data);
  Future<void> removeEmployee(String id);

  // Administrative Requests
  Future<String> submitRequest(AdministrativeRequestModel request);
  Future<void> updateRequestStatus(
    String requestId,
    AdministrativeRequestStatus status, {
    String? notes,
    String? rejectionReason,
    String? processedBy,
  });
  Stream<List<AdministrativeRequestModel>> getUserRequests(String userId);
  Stream<List<AdministrativeRequestModel>> getEmbassyRequests(String embassyId);
}

class EmbassyRemoteDataSourceImpl implements EmbassyRemoteDataSource {
  final FirebaseFirestore _firestore;

  EmbassyRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==================== EMBASSY CRUD ====================

  @override
  Future<List<EmbassyModel>> getEmbassies() async {
    try {
      final querySnapshot = await _firestore.collection('embassies').get();

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
  Future<EmbassyModel?> getEmbassyById(String id) async {
    try {
      final doc = await _firestore.collection('embassies').doc(id).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return EmbassyModel.fromJson(data);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la récupération de l\'ambassade',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> createEmbassy(EmbassyModel embassy) async {
    try {
      final data = embassy.toJson();
      data.remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore.collection('embassies').add(data);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la création de l\'ambassade',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateEmbassy(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('embassies').doc(id).update(data);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour de l\'ambassade',
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
      if (isVerified != null) {
        updateData['isVerified'] = isVerified;
      }
      if (isSuspended != null) {
        updateData['isSuspended'] = isSuspended;
      }
      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }
      if (isVerified == true) {
        updateData['verifiedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('embassies').doc(id).update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour du statut',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateEmbassyAvailability(
    String id, {
    bool? isTemporarilyClosed,
    String? closureMessage,
    DateTime? reopenDate,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (isTemporarilyClosed != null) {
        updateData['isTemporarilyClosed'] = isTemporarilyClosed;
      }
      if (closureMessage != null) {
        updateData['closureMessage'] = closureMessage;
      }
      if (reopenDate != null) {
        updateData['reopenDate'] = Timestamp.fromDate(reopenDate);
      }

      await _firestore.collection('embassies').doc(id).update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour de la disponibilité',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // ==================== EMBASSY MESSAGES ====================

  @override
  Future<void> sendMessageToEmbassy({
    required String embassyId,
    required String userId,
    required String subject,
    required String content,
    required EmbassyMessageType messageType,
    String? userName,
    String? userPhotoUrl,
    String? userEmail,
  }) async {
    try {
      // Get embassy info for display
      final embassy = await getEmbassyById(embassyId);

      final message = {
        'embassyId': embassyId,
        'userId': userId,
        'subject': subject,
        'content': content,
        'messageType': messageType.name,
        'status': EmbassyMessageStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'userEmail': userEmail,
        'embassyName': embassy?.name,
        'embassyCountry': embassy?.country,
        'attachments': [],
      };

      await _firestore.collection('embassy_messages').add(message);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'envoi du message');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<EmbassyMessageModel>> getUserEmbassyMessages(String userId) {
    return _firestore
        .collection('embassy_messages')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => EmbassyMessageModel.fromFirestore(doc))
                  .toList(),
        );
  }

  @override
  Stream<List<EmbassyMessageModel>> getEmbassyInbox(String embassyId) {
    return _firestore
        .collection('embassy_messages')
        .where('embassyId', isEqualTo: embassyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => EmbassyMessageModel.fromFirestore(doc))
                  .toList(),
        );
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    EmbassyMessageStatus status, {
    String? replyContent,
    String? repliedBy,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': status.name};

      if (status == EmbassyMessageStatus.read) {
        updateData['readAt'] = FieldValue.serverTimestamp();
      }
      if (status == EmbassyMessageStatus.replied) {
        updateData['repliedAt'] = FieldValue.serverTimestamp();
        if (replyContent != null) {
          updateData['replyContent'] = replyContent;
        }
        if (repliedBy != null) {
          updateData['repliedBy'] = repliedBy;
        }
      }

      await _firestore
          .collection('embassy_messages')
          .doc(messageId)
          .update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour du message',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // ==================== EMBASSY EMPLOYEES ====================

  @override
  Future<List<EmbassyEmployeeModel>> searchEmployees({
    String? query,
    String? embassyId,
    String? department,
  }) async {
    try {
      Query<Map<String, dynamic>> queryRef = _firestore
          .collection('embassy_employees')
          .where('isPublic', isEqualTo: true)
          .where('isActive', isEqualTo: true);

      if (embassyId != null) {
        queryRef = queryRef.where('embassyId', isEqualTo: embassyId);
      }

      if (department != null && department.isNotEmpty) {
        queryRef = queryRef.where('department', isEqualTo: department);
      }

      final snapshot = await queryRef.get();

      var employees =
          snapshot.docs
              .map((doc) => EmbassyEmployeeModel.fromFirestore(doc))
              .toList();

      // Filter by name if query provided (client-side for now)
      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        employees =
            employees
                .where(
                  (e) =>
                      e.name.toLowerCase().contains(lowerQuery) ||
                      (e.title?.toLowerCase().contains(lowerQuery) ?? false) ||
                      (e.role.toLowerCase().contains(lowerQuery)),
                )
                .toList();
      }

      return employees;
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la recherche des employés',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> addEmployee(EmbassyEmployeeModel employee) async {
    try {
      await _firestore
          .collection('embassy_employees')
          .add(employee.toFirestore());
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de l\'ajout de l\'employé',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('embassy_employees').doc(id).update(data);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour de l\'employé',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> removeEmployee(String id) async {
    try {
      await _firestore.collection('embassy_employees').doc(id).update({
        'isActive': false,
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression de l\'employé',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // ==================== ADMINISTRATIVE REQUESTS ====================

  @override
  Future<String> submitRequest(AdministrativeRequestModel request) async {
    try {
      final data = request.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['submittedAt'] = FieldValue.serverTimestamp();
      data['status'] = AdministrativeRequestStatus.submitted.name;

      // Generate tracking number
      final trackingNumber = 'REQ-${DateTime.now().millisecondsSinceEpoch}';
      data['trackingNumber'] = trackingNumber;

      final docRef = await _firestore
          .collection('administrative_requests')
          .add(data);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la soumission de la demande',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateRequestStatus(
    String requestId,
    AdministrativeRequestStatus status, {
    String? notes,
    String? rejectionReason,
    String? processedBy,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': status.name};

      if (notes != null) {
        updateData['embassyNotes'] = notes;
      }
      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }
      if (processedBy != null) {
        updateData['processedBy'] = processedBy;
      }

      if (status == AdministrativeRequestStatus.processing) {
        updateData['processedAt'] = FieldValue.serverTimestamp();
      }
      if (status == AdministrativeRequestStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('administrative_requests')
          .doc(requestId)
          .update(updateData);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour de la demande',
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<AdministrativeRequestModel>> getUserRequests(String userId) {
    return _firestore
        .collection('administrative_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AdministrativeRequestModel.fromFirestore(doc))
                  .toList(),
        );
  }

  @override
  Stream<List<AdministrativeRequestModel>> getEmbassyRequests(
    String embassyId,
  ) {
    return _firestore
        .collection('administrative_requests')
        .where('embassyId', isEqualTo: embassyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AdministrativeRequestModel.fromFirestore(doc))
                  .toList(),
        );
  }
}
