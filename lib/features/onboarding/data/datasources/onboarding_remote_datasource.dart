import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/exceptions.dart';

abstract class OnboardingRemoteDataSource {
  Future<bool> hasSeenOnboarding();
  Future<void> setOnboardingComplete();
  Future<bool> hasSeenCoachMarks();
  Future<void> setCoachMarksComplete();
  Future<bool> hasGivenConsent();
  Future<void> setConsentGiven();
  Future<bool> hasCompletedProfileConfig();
  Future<void> setProfileConfigComplete();
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

  @override
  Future<bool> hasSeenCoachMarks() async {
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
      return data?['hasSeenCoachMarks'] ?? false;
    } catch (e) {
      throw ServerException('Erreur lors de la verification coach marks');
    }
  }

  @override
  Future<void> setCoachMarksComplete() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw ServerException('Utilisateur non connecte');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'hasSeenCoachMarks': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException('Erreur lors de la mise a jour coach marks');
    }
  }

  @override
  Future<bool> hasGivenConsent() async {
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
      return data?['hasGivenConsent'] ?? false;
    } catch (e) {
      throw ServerException('Erreur lors de la verification du consentement');
    }
  }

  @override
  Future<void> setConsentGiven() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw ServerException('Utilisateur non connecte');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'hasGivenConsent': true,
        'consentDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException('Erreur lors de la mise a jour du consentement');
    }
  }

  @override
  Future<bool> hasCompletedProfileConfig() async {
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
      return data?['profileConfigComplete'] ?? false;
    } catch (e) {
      throw ServerException(
          'Erreur lors de la verification de la configuration du profil');
    }
  }

  @override
  Future<void> setProfileConfigComplete() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw ServerException('Utilisateur non connecte');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'profileConfigComplete': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw ServerException(
          'Erreur lors de la mise a jour de la configuration du profil');
    }
  }
}
