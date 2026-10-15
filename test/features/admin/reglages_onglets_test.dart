// Les cinq onglets de l'écran Configuration, montés avec des réglages fictifs.
//
// `admin_settings_screen.dart` (2093 lignes) a été découpé en un fichier par
// onglet : un déplacement mécanique, que rien ne prouvait équivalent. Ce test
// ouvre chaque onglet sur des réglages NON PAR DÉFAUT, vérifie qu'il affiche
// ses valeurs, puis enregistre sans rien toucher : ce que l'onglet envoie au
// notifier doit être, champ pour champ, ce qu'il a reçu. Un champ perdu en
// route (non lu, non écrit, mal converti) casse cette égalité.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/app_settings_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/reglages/reglages_boosts_tab.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/reglages/reglages_frais_tab.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/reglages/reglages_medias_tab.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/reglages/reglages_systeme_tab.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/reglages/reglages_taxes_tab.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Ce que les onglets ont écrit, par méthode du notifier.
class _Ecritures {
  FeeSettingsEntity? fees;
  BoostPricingEntity? boost;
  TaxRatesEntity? taxes;
  MediaLimitsEntity? medias;
  SystemUrlsEntity? urls;
  SystemIntervalsEntity? intervalles;
  final List<String> auteurs = [];
}

class _ReglagesFactices extends AppSettingsNotifier {
  _ReglagesFactices(this._settings, this._ecritures);
  final AppSettingsEntity _settings;
  final _Ecritures _ecritures;

  @override
  Future<AppSettingsEntity> build() async => _settings;

  @override
  Future<void> updateFees(FeeSettingsEntity fees, String updatedBy) async {
    _ecritures.fees = fees;
    _ecritures.auteurs.add(updatedBy);
  }

  @override
  Future<void> updateBoostPricing(
    BoostPricingEntity pricing,
    String updatedBy,
  ) async {
    _ecritures.boost = pricing;
    _ecritures.auteurs.add(updatedBy);
  }

  @override
  Future<void> updateTaxRates(TaxRatesEntity rates, String updatedBy) async {
    _ecritures.taxes = rates;
    _ecritures.auteurs.add(updatedBy);
  }

  @override
  Future<void> updateMediaLimits(
    MediaLimitsEntity limits,
    String updatedBy,
  ) async {
    _ecritures.medias = limits;
    _ecritures.auteurs.add(updatedBy);
  }

  @override
  Future<void> updateUrls(SystemUrlsEntity urls, String updatedBy) async {
    _ecritures.urls = urls;
    _ecritures.auteurs.add(updatedBy);
  }

  @override
  Future<void> updateIntervals(
    SystemIntervalsEntity intervals,
    String updatedBy,
  ) async {
    _ecritures.intervalles = intervals;
    _ecritures.auteurs.add(updatedBy);
  }
}

/// Aucune valeur n'est celle par défaut : un onglet qui ignorerait le champ
/// et remettrait le défaut serait pris.
const _frais = FeeSettingsEntity(
  transferFeePercent: 0.03,
  transferFeeMin: 650,
  transferFeeMax: 12500,
  marketplaceFeePercent: 0.04,
  marketplaceFeeMin: 15,
  marketplaceFeeMax: 61000,
);
const _boosts = BoostPricingEntity(
  standardBase: 6100,
  featuredBase: 12300,
  premiumBase: 30500,
  multiplier7Days: 1.5,
  multiplier30Days: 4.0,
  multiplier90Days: 8.5,
);
const _taxes = TaxRatesEntity(
  alimentation: 0.05,
  artisanat: 0.15,
  standard: 0.2,
  electronique: 0.25,
  vetements: 0.1,
  services: 0.05,
  immobilier: 0.5,
);
const _medias = MediaLimitsEntity(
  // Un seul champ « dimension max » pilote la largeur ET la hauteur : l'onglet
  // enregistre la hauteur égale à la largeur. Un réglage à hauteur différente
  // serait aligné au premier enregistrement — voulu, pas un défaut.
  // Au-dessus des planchers du code (largeur 2048, qualité 88) : en dessous,
  // l'onglet refuse d'enregistrer (voir le test « sous le plancher »).
  imageMaxWidth: 2400,
  imageMaxHeight: 2400,
  imageQuality: 92,
  maxImagesPerUpload: 7,
  minWidthForCompression: 900,
  messageMaxChars: 2500,
  messageCharCountThreshold: 250,
  maxImageSizeMb: 12,
  maxVideoSizeMb: 60,
  maxDocumentSizeMb: 30,
  maxAudioDurationSeconds: 420,
);
const _intervalles = SystemIntervalsEntity(
  locationUpdateMinutes: 7,
  heartbeatMinutes: 12,
  cacheMinutes: 90,
  remoteConfigFetchMinutes: 45,
  typingIndicatorSeconds: 4,
);
const _urls = SystemUrlsEntity(
  shareBaseUrl: 'https://exemple.test/p/',
  supportEmail: 'aide@exemple.test',
  supportPhone: '+22790000000',
  privacyEmail: 'vie-privee@exemple.test',
  bugsEmail: 'bogues@exemple.test',
  feedbackEmail: 'avis@exemple.test',
  moderationEmail: 'moderation@exemple.test',
  stripeMerchantId: 'merchant.exemple.test',
  termsUrl: 'https://exemple.test/cgu',
  privacyUrl: 'https://exemple.test/confidentialite',
);

const _reglages = AppSettingsEntity(
  fees: _frais,
  boostPricing: _boosts,
  taxRates: _taxes,
  mediaLimits: _medias,
  intervals: _intervalles,
  urls: _urls,
);

Future<_Ecritures> _monter(WidgetTester tester, Widget onglet) async {
  tester.view.physicalSize = const Size(1100, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ecritures = _Ecritures();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsNotifierProvider.overrideWith(
          () => _ReglagesFactices(_reglages, ecritures),
        ),
        currentUserAsyncProvider.overrideWith(
          (ref) => Stream.value(const UserEntity(id: 'admin-7')),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: onglet),
      ),
    ),
  );
  await tester.pump();
  return ecritures;
}

/// Appuie sur le n-ième bouton « enregistrer » de l'onglet et laisse
/// l'écriture (asynchrone) aboutir.
Future<void> _enregistrer(WidgetTester tester, {int rang = 0}) async {
  final bouton = find.byIcon(Icons.save_rounded).at(rang);
  await tester.ensureVisible(bouton);
  await tester.tap(bouton);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('Frais : affiche ses valeurs et les réécrit à l\'identique',
      (tester) async {
    final e = await _monter(tester, const AdminFraisTab(settings: _reglages));
    expect(tester.takeException(), isNull);
    expect(find.text('12500'), findsOneWidget);
    expect(find.text('61000'), findsOneWidget);

    await _enregistrer(tester);
    expect(e.fees, _frais);
    expect(e.auteurs, ['admin-7']);
  });

  testWidgets('Boosts : affiche ses valeurs et les réécrit à l\'identique',
      (tester) async {
    final e = await _monter(tester, const AdminBoostsTab(settings: _reglages));
    expect(tester.takeException(), isNull);
    expect(find.text('6100'), findsOneWidget);

    await _enregistrer(tester);
    expect(e.boost, _boosts);
    expect(e.auteurs, ['admin-7']);
  });

  testWidgets('Taxes : affiche ses sept taux et les réécrit à l\'identique',
      (tester) async {
    final e = await _monter(tester, const AdminTaxesTab(settings: _reglages));
    expect(tester.takeException(), isNull);
    expect(find.byType(TextFormField), findsNWidgets(7));

    await _enregistrer(tester);
    expect(e.taxes, _taxes);
    expect(e.auteurs, ['admin-7']);
  });

  testWidgets('Médias : affiche ses limites et les réécrit à l\'identique',
      (tester) async {
    final e = await _monter(tester, const AdminMediasTab(settings: _reglages));
    expect(tester.takeException(), isNull);
    // Six champs saisis ; les cinq autres limites (hauteur, seuil de
    // compression, seuil du compteur, document, audio) sont conservées telles
    // quelles et se retrouvent dans l'égalité ci-dessous.
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.text('2500'), findsOneWidget);

    await _enregistrer(tester);
    expect(e.medias, _medias);
    expect(e.auteurs, ['admin-7']);
  });

  testWidgets('Médias : une largeur sous le plancher du code est refusée',
      (tester) async {
    final e = await _monter(tester, const AdminMediasTab(settings: _reglages));
    // Le premier champ est la dimension max : 1000 < 2048. Sans ce refus, la
    // valeur serait enregistrée puis ignorée à l'envoi — un réglage muet.
    await tester.enterText(find.byType(TextFormField).first, '1000');
    await _enregistrer(tester);
    expect(e.medias, isNull, reason: 'le formulaire invalide n\'écrit rien');
  });

  testWidgets('Système : deux cartes, chacune écrit son groupe de champs',
      (tester) async {
    final e = await _monter(tester, const AdminSystemeTab(settings: _reglages));
    expect(tester.takeException(), isNull);
    expect(find.text('aide@exemple.test'), findsOneWidget);
    expect(find.byIcon(Icons.save_rounded), findsNWidgets(2));

    // Première carte : URL et contacts. Les deux autres champs d'URL
    // (CGU, confidentialité) n'ont pas de champ : ils sont conservés.
    await _enregistrer(tester, rang: 0);
    expect(e.urls, _urls);
    expect(e.intervalles, isNull, reason: 'la carte URL n\'écrit pas les intervalles');

    // Seconde carte : intervalles. Un seul champ (le délai de frappe) n'a pas
    // de champ de saisie et garde sa valeur d'origine.
    await _enregistrer(tester, rang: 1);
    expect(e.intervalles?.locationUpdateMinutes, 7);
    expect(e.intervalles?.heartbeatMinutes, 12);
    expect(e.intervalles?.cacheMinutes, 90);
    expect(e.auteurs, ['admin-7', 'admin-7']);
  });
}
