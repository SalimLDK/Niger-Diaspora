// Régression : basculer le mode maintenance depuis le back-office écrasait
// audioRooms/podcasts/feed avec les défauts de l'entité, parce que
// toggleMaintenanceMode reconstruisait FeatureFlagsEntity champ par champ
// (même famille que le bug des préférences profil). Et en amont,
// FeatureFlagsModel ne sérialisait pas du tout ces trois flags : les
// interrupteurs du back-office étaient perdus à l'écriture, et la lecture
// retombait sur les défauts quoi que dise Firestore.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/data/datasources/app_settings_datasource.dart';
import 'package:diaspo_niger/features/admin/data/models/app_settings_model.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';

/// Flags volontairement à l'opposé des défauts de FeatureFlagsEntity
/// (audioRooms=false, podcasts=false, feed=true) : toute retombée au défaut
/// devient visible.
const _serverFlags = FeatureFlagsEntity(
  moneyTransfer: true,
  marketplace: true,
  businessDirectory: false,
  events: false,
  groups: false,
  embassies: false,
  audioRooms: true,
  podcasts: true,
  feed: false,
  maintenanceMode: false,
  maintenanceMessage: 'Ancien message',
);

class _FakeAppSettingsDataSource implements AppSettingsDataSource {
  _FakeAppSettingsDataSource(this._settings);

  AppSettingsModel _settings;
  final List<({String section, Map<String, dynamic> data, String updatedBy})>
  sectionWrites = [];

  @override
  Future<AppSettingsModel> getSettings() async => _settings;

  @override
  Future<void> updateSection(
    String section,
    Map<String, dynamic> data,
    String updatedBy,
  ) async {
    sectionWrites.add((section: section, data: data, updatedBy: updatedBy));
    if (section == 'featureFlags') {
      _settings = AppSettingsModel.fromEntity(
        _settings.toEntity().copyWith(
          featureFlags: FeatureFlagsModel.fromJson(data).toEntity(),
        ),
      );
    }
  }

  @override
  Future<void> updateSettings(AppSettingsModel settings, String updatedBy) {
    throw UnimplementedError();
  }

  @override
  Stream<AppSettingsModel> watchSettings() => Stream.value(_settings);
}

void main() {
  group('FeatureFlagsEntity.copyWith', () {
    test('ne modifie que le mode maintenance, tout le reste est préservé', () {
      final updated = _serverFlags.copyWith(
        maintenanceMode: true,
        maintenanceMessage: 'Retour à 14h',
      );

      expect(updated.maintenanceMode, isTrue);
      expect(updated.maintenanceMessage, 'Retour à 14h');
      expect(updated.audioRooms, isTrue);
      expect(updated.podcasts, isTrue);
      expect(updated.feed, isFalse);
      expect(updated.businessDirectory, isFalse);
      expect(updated.events, isFalse);
      expect(updated.groups, isFalse);
      expect(updated.embassies, isFalse);
      expect(updated.moneyTransfer, isTrue);
      expect(updated.marketplace, isTrue);
    });

    test('null explicite efface maintenanceMessage, omis le conserve', () {
      expect(
        _serverFlags.copyWith(maintenanceMessage: null).maintenanceMessage,
        isNull,
      );
      expect(
        _serverFlags.copyWith(maintenanceMode: true).maintenanceMessage,
        'Ancien message',
      );
    });
  });

  group('FeatureFlagsModel', () {
    test('aller-retour entité → json → entité sans perte', () {
      final roundTripped = FeatureFlagsModel.fromJson(
        FeatureFlagsModel.fromEntity(_serverFlags).toJson(),
      ).toEntity();

      expect(roundTripped, _serverFlags);
    });

    test('document sans les nouvelles clés → défauts de l\'entité', () {
      final entity = FeatureFlagsModel.fromJson(const {}).toEntity();

      expect(entity.audioRooms, isFalse);
      expect(entity.podcasts, isFalse);
      expect(entity.feed, isTrue);
    });
  });

  group('AppSettingsNotifier.toggleMaintenanceMode', () {
    test('préserve les valeurs serveur de tous les flags', () async {
      final fake = _FakeAppSettingsDataSource(
        AppSettingsModel(featureFlags: FeatureFlagsModel.fromEntity(_serverFlags)),
      );
      final container = ProviderContainer(
        overrides: [appSettingsDataSourceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(appSettingsNotifierProvider.future);
      await container
          .read(appSettingsNotifierProvider.notifier)
          .toggleMaintenanceMode(true, 'Retour à 14h', 'admin-test');

      expect(fake.sectionWrites, hasLength(1));
      final write = fake.sectionWrites.single;
      expect(write.section, 'featureFlags');
      expect(write.updatedBy, 'admin-test');

      final written = FeatureFlagsModel.fromJson(write.data).toEntity();
      expect(
        written,
        _serverFlags.copyWith(
          maintenanceMode: true,
          maintenanceMessage: 'Retour à 14h',
        ),
      );
      // Les trois flags historiquement écrasés, nommés explicitement.
      expect(written.audioRooms, isTrue);
      expect(written.podcasts, isTrue);
      expect(written.feed, isFalse);
    });
  });
}
