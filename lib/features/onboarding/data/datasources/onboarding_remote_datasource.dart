import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/exceptions.dart';

abstract class OnboardingRemoteDataSource {
  Future<bool> hasSeenOnboarding();
  Future<void> setOnboardingComplete();
}

class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  OnboardingRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  @override
  Future<bool> hasSeenOnboarding() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        return false;
      }

      final data = doc.data();
      return data?['hasSeenOnboarding'] ?? false;
    } catch (e) {
      throw ServerException('Erreur lors de la verification onboarding');
    }
  }

  @override
  Future<void> setOnboardingComplete() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw ServerException('Utilisateur non connecte');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'hasSeenOnboarding': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException('Erreur lors de la mise a jour onboarding');
    }
  }
}
