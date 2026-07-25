import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/messages/presentation/widgets/message_input.dart';

/// Métriques réelles (dp logiques) de téléphones courants en paysage.
const _landscapePhones = <String, ({double height, double inset})>{
  'Galaxy A51 (l\'appareil de test)': (height: 360, inset: 24),
  'Pixel 5': (height: 393, inset: 24),
  'petit écran': (height: 320, inset: 24),
  'iPhone SE': (height: 375, inset: 20),
};

// Budget vertical sous l'en-tête : composer + bandeau + picker doivent tenir.
const _appBar = 56.0;
const _composer = 64.0;
const _pinnedBanner = 44.0;

void main() {
  group('computeMessagePickerHeight - paysage ne déborde pas', () {
    _landscapePhones.forEach((name, m) {
      test(name, () {
        final picker = computeMessagePickerHeight(
          screenHeight: m.height,
          systemInset: m.inset,
          isLandscape: true,
        );

        final used = _appBar + _composer + _pinnedBanner + picker;
        final available = m.height - m.inset;

        expect(
          used,
          lessThanOrEqualTo(available),
          reason:
              '$name : composer+bandeau+picker ($used) dépasse l\'espace '
              'disponible ($available) → overflow',
        );
        expect(picker, greaterThan(0));
      });
    });
  });

  test('l\'ANCIENNE formule débordait bien (garde-fou du test)', () {
    double old(double h) => (h * 0.62).clamp(160.0, 260.0);
    final m = _landscapePhones['Galaxy A51 (l\'appareil de test)']!;
    final used = _appBar + _composer + _pinnedBanner + old(m.height);
    final available = m.height - m.inset;
    expect(used, greaterThan(available));
  });

  test('sur l\'appareil de test (Galaxy A51) le picker reste confortable', () {
    final m = _landscapePhones['Galaxy A51 (l\'appareil de test)']!;
    final picker = computeMessagePickerHeight(
      screenHeight: m.height,
      systemInset: m.inset,
      isLandscape: true,
    );
    expect(picker, greaterThanOrEqualTo(150.0));
  });

  test('portrait garde une grande hauteur', () {
    final picker = computeMessagePickerHeight(
      screenHeight: 800,
      systemInset: 48,
      isLandscape: false,
    );
    expect(picker, greaterThan(260));
    expect(picker, lessThanOrEqualTo(300));
  });
}
