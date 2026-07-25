import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingLocalDataSource {
  Future<bool> hasSeenOnboarding(String userId);
  Future<void> setOnboardingComplete(String userId);
  Future<bool> hasSeenCoachMarks(String userId);
  Future<void> setCoachMarksComplete(String userId);
  Future<bool> hasGivenConsent(String userId);
  Future<void> setConsentGiven(String userId);
  Future<bool> hasCompletedProfileConfig(String userId);
  Future<void> setProfileConfigComplete(String userId);
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _hasSeenCoachMarksKey = 'has_seen_coach_marks';
  static const String _hasGivenConsentKey = 'has_given_consent';
  static const String _hasCompletedProfileConfigKey =
      'has_completed_profile_config';

  final SharedPreferences _prefs;

  OnboardingLocalDataSourceImpl({required SharedPreferences prefs})
    : _prefs = prefs;

  @override
  Future<bool> hasSeenOnboarding(String userId) async {
    return _prefs.getBool('${_hasSeenOnboardingKey}_$userId') ?? false;
  }

  @override
  Future<void> setOnboardingComplete(String userId) async {
    await _prefs.setBool('${_hasSeenOnboardingKey}_$userId', true);
  }

  @override
  Future<bool> hasSeenCoachMarks(String userId) async {
    return _prefs.getBool('${_hasSeenCoachMarksKey}_$userId') ?? false;
  }

  @override
  Future<void> setCoachMarksComplete(String userId) async {
    await _prefs.setBool('${_hasSeenCoachMarksKey}_$userId', true);
  }

  @override
  Future<bool> hasGivenConsent(String userId) async {
    return _prefs.getBool('${_hasGivenConsentKey}_$userId') ?? false;
  }

  @override
  Future<void> setConsentGiven(String userId) async {
    await _prefs.setBool('${_hasGivenConsentKey}_$userId', true);
  }

  @override
  Future<bool> hasCompletedProfileConfig(String userId) async {
    return _prefs.getBool('${_hasCompletedProfileConfigKey}_$userId') ?? false;
  }

  @override
  Future<void> setProfileConfigComplete(String userId) async {
    await _prefs.setBool('${_hasCompletedProfileConfigKey}_$userId', true);
  }
}
