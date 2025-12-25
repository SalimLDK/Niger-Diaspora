import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingLocalDataSource {
  Future<bool> hasSeenOnboarding();
  Future<void> setOnboardingComplete();
  Future<bool> hasSeenCoachMarks();
  Future<void> setCoachMarksComplete();
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _hasSeenCoachMarksKey = 'has_seen_coach_marks';

  final SharedPreferences _prefs;

  OnboardingLocalDataSourceImpl({required SharedPreferences prefs})
      : _prefs = prefs;

  @override
  Future<bool> hasSeenOnboarding() async {
    return _prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  @override
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(_hasSeenOnboardingKey, true);
  }

  @override
  Future<bool> hasSeenCoachMarks() async {
    return _prefs.getBool(_hasSeenCoachMarksKey) ?? false;
  }

  @override
  Future<void> setCoachMarksComplete() async {
    await _prefs.setBool(_hasSeenCoachMarksKey, true);
  }
}
