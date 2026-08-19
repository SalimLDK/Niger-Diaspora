// Annuaire et Ambassades sont toujours actifs dans l'app depuis le 2026-08-19
// (feature_flag_service.dart ignore ces flags). Le back-office doit le dire :
// leurs interrupteurs sont affichés verrouillés sur actif (Switch désactivé),
// quel que soit l'état du document Firestore — un interrupteur manœuvrable
// qui n'agit plus sur rien serait un mensonge d'interface.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/data/datasources/app_settings_datasource.dart';
import 'package:diaspo_niger/features/admin/data/models/app_settings_model.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_feature_flags_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Les deux flags verrouillés sont volontairement à `false` côté « serveur » :
/// l'écran doit quand même les montrer actifs et non manœuvrables.
const _serverFlags = FeatureFlagsEntity(
  moneyTransfer: false,
  marketplace: false,
  businessDirectory: false,
  events: true,
  groups: true,
  embassies: false,
  audioRooms: false,
  podcasts: false,
  feed: true,
  maintenanceMode: false,
);

class _FakeAppSettingsDataSource implements AppSettingsDataSource {
  final _settings = AppSettingsModel(
    featureFlags: FeatureFlagsModel.fromEntity(_serverFlags),
  );

  @override
  Future<AppSettingsModel> getSettings() async => _settings;

  @override
  Future<void> updateSection(
    String section,
    Map<String, dynamic> data,
    String updatedBy,
  ) async {}

  @override
  Future<void> updateSettings(AppSettingsModel settings, String updatedBy) {
    throw UnimplementedError();
  }

  @override
  Stream<AppSettingsModel> watchSettings() => Stream.value(_settings);
}

void main() {
  testWidgets(
    'Annuaire et Ambassades : verrouillés sur actif, les autres manœuvrables',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsDataSourceProvider.overrideWithValue(
              _FakeAppSettingsDataSource(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('fr'),
            home: AdminFeatureFlagsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(switches, isNotEmpty);

      final locked = switches.where((s) => s.onChanged == null).toList();
      // Exactement les deux services « toujours actifs » — cette liste ne
      // doit que suivre les décisions produit, pas grandir par accident.
      expect(locked, hasLength(2));
      // Verrouillés sur ACTIF, même si le document serveur dit false.
      expect(locked.every((s) => s.value), isTrue);

      // Le sous-titre explicatif accompagne chacun des deux.
      expect(
        find.text('Toujours actif — ce flag n\'est plus consulté par l\'app'),
        findsNWidgets(2),
      );

      // Tous les autres interrupteurs restent manœuvrables.
      expect(
        switches.where((s) => s.onChanged != null).length,
        switches.length - 2,
      );
    },
  );
}
