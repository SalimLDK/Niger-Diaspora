import 'dart:io';

class AdConfig {
  AdConfig._();

  static const int adFrequencyMin = 10;
  static const int adFrequencyMax = 15;

  static const String androidAppId = 'ca-app-pub-4674966180025040~9171762097';
  static const String iosAppId = 'ca-app-pub-4674966180025040~3434699770';

  // Native ad unit ID Android (production)
  static const String _androidNativeAdUnitId =
      'ca-app-pub-4674966180025040/5905407299';
  static const String _iosNativeAdUnitId =
      'ca-app-pub-4674966180025040/2121618108';

  static String get nativeAdUnitId =>
      Platform.isAndroid ? _androidNativeAdUnitId : _iosNativeAdUnitId;
}
