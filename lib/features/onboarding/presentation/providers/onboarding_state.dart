import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_state.freezed.dart';

/// Les quatre drapeaux valent `false` par défaut ici, mais **ce n'est pas
/// l'état initial du notifier** : `OnboardingNotifier.build` les part à `true`
/// tant qu'aucune lecture n'a abouti, parce que `false` veut dire « rejoue
/// l'onboarding » et qu'on ne rejoue rien sur une simple ignorance. Voir
/// `OnboardingNotifier._repliSiIndetermine` — c'est là que la règle est
/// expliquée, et c'est là qu'il faut la changer.
@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(false) bool hasSeenIntro,
    @Default(false) bool hasSeenCoachMarks,
    @Default(false) bool hasGivenConsent,
    @Default(false) bool profileConfigComplete,
    @Default(true) bool isLoading,
    @Default(0) int currentPage,
  }) = _OnboardingState;
}
