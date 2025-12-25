import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_state.freezed.dart';

@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(false) bool hasSeenIntro,
    @Default(false) bool hasSeenCoachMarks,
    @Default(true) bool isLoading,
    @Default(0) int currentPage,
  }) = _OnboardingState;
}
