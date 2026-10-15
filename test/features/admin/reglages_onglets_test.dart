// Les cinq onglets de l'écran Configuration, montés avec des réglages fictifs.
//
// `admin_settings_screen.dart` (2093 lignes) a été découpé en un fichier par
// onglet sans qu'aucun test ne les monte : un champ perdu en route, ou un
// bouton relié au mauvais groupe, ne se serait vu qu'à la main. Chaque onglet
// est donc monté tout seul, avec des valeurs qui ne sont PAS les défauts, puis :
//
//   1. chaque champ affiche la valeur enregistrée (et non le défaut) ;
//   2. « Enregistrer » renvoie au serveur exactement ce qui était affiché —
//      aucune valeur perdue, aucun champ lu dans le mauvais contrôleur — au
//      nom de l'admin connecté, et la confirmation sort.
//
// Le serveur est un faux : on ne teste pas Firestore, on teste ce que l'onglet
// lui envoie.
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

/// Ce que les onglets ont envoyé au serveur : (section, entité, admin).
typedef _Envoi = ({String section, Object valeur, String par});

class _FauxReglages extends AppSettingsNotifier {
  _FauxReglages(this.reglages, this.envois);

  final AppSettingsEntity reglages;
  final List<_Envoi> envois;

  @override
  Future<AppSettingsEntity> build() async => reglages;

  @override
  Future<void> updateFees(FeeSettingsEntity fees, String updatedBy) async =>
      envois.add((section: 'fees', valeur: fees, par: updatedBy));

  @override
  Future<void> updateBoostPricing(BoostPricingEntity pricing, String updatedBy) async =>
      envois.add((section: 'boost', valeur: pricing, par: updatedBy));

  @override
  Future<void> updateTaxRates(TaxRatesEntity rates, String updatedBy) async =>
      envois.add((section: 'taxes', valeur: rates, par: updatedBy));

  @override
  Future<void> updateMediaLimits(MediaLimitsEntity limits, String updatedBy) async =>
      envois.add((section: 'medias', valeur: limits, par: updatedBy));

  @override
  Future<void> updateIntervals(SystemIntervalsEntity intervals, String updatedBy) async =>
      envois.add((section: 'intervalles', valeur: intervals, par: updatedBy));

  @override
  Future<void> updateUrls(SystemUrlsEntity urls, String updatedBy) async =>
      envois.add((section: 'urls', valeur: urls, par: updatedBy));
}

/// Aucune valeur n'est celle par défaut (et celles des médias restent au-dessus
/// des planchers de `ImageUploadConfig`, que l'onglet refuse de franchir) : un onglet qui afficherait le défaut
/// au lieu du réglage enregistré serait pris.
const _reglages = AppSettingsEntity(
  fees: FeeSettingsEntity(
    transferFeePercent: 0.04,
    transferFeeMin: 750,
    transferFeeMax: 12000,
    marketplaceFeePercent: 0.08,
    marketplaceFeeMin: 100,
    marketplaceFeeMax: 60000,
  ),
  boostPricing: BoostPricingEntity(
    standardBase: 6000,
    featuredBase: 12000,
    premiumBase: 30000,
    multiplier7Days: 1.5,
    multiplier30Days: 4.0,
    multiplier90Days: 8.0,
  ),
  taxRates: TaxRatesEntity(
    alimentation: 0.05,
    artisanat: 0.12,
    standard: 0.20,
    electronique: 0.21,
    vetements: 0.22,
    services: 0.06,
    immobilier: 0.07,
  ),
  mediaLimits: MediaLimitsEntity(
    imageMaxWidth: 2560,
    imageQuality: 92,
    maxImagesPerUpload: 8,
    messageMaxChars: 3000,
    maxImageSizeMb: 12,
    maxVideoSizeMb: 80,
  ),
  intervals: SystemIntervalsEntity(
    locationUpdateMinutes: 7,
    heartbeatMinutes: 15,
    cacheMinutes: 90,
  ),
  urls: SystemUrlsEntity(
    shareBaseUrl: 'https://exemple.test/p/',
    supportEmail: 'aide@exemple.test',
    privacyEmail: 'vie-privee@exemple.test',
    bugsEmail: 'bugs@exemple.test',
    feedbackEmail: 'avis@exemple.test',
    moderationEmail: 'moderation@exemple.test',
  ),
);

Future<List<_Envoi>> _monter(
  WidgetTester tester,
  Widget onglet, {
  AppSettingsEntity reglages = _reglages,
}) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final envois = <_Envoi>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsNotifierProvider.overrideWith(() => _FauxReglages(reglages, envois)),
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
  return envois;
}

/// Le texte de chaque champ de saisie de l'onglet, dans l'ordre d'affichage.
List<String> _champs(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .map((e) => e.controller.text)
    .toList();

/// Appuie sur le [rang]-ième bouton « Enregistrer » (icône disquette).
Future<void> _enregistrer(WidgetTester tester, {int rang = 0}) async {
  final bouton = find.byIcon(Icons.save_rounded).at(rang);
  await tester.ensureVisible(bouton);
  await tester.tap(bouton);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('Frais : affiche les frais enregistrés et les renvoie intacts', (tester) async {
    final envois = await _monter(tester, const AdminFraisTab(settings: _reglages));

    // Les pourcentages s'affichent en % (0,04 → « 4.0 »), les montants entiers
    // sans « .0 » : le champ n'accepte que des chiffres.
    expect(_champs(tester), [
      '4.0', '750', '12000', // transfert : %, min, max
      '8.0', '100', '60000', // marketplace : %, min, max
    ]);

    await _enregistrer(tester);
    expect(envois, hasLength(1));
    expect(envois.single.section, 'fees');
    expect(envois.single.valeur, _reglages.fees);
    expect(envois.single.par, 'admin-7');
    expect(find.text(AppLocalizations.of(tester.element(find.byType(Scaffold)))!.adminFeesUpdated),
        findsOneWidget);
  });

  testWidgets('Boosts : affiche les tarifs enregistrés et les renvoie intacts', (tester) async {
    final envois = await _monter(tester, const AdminBoostsTab(settings: _reglages));

    expect(
      _champs(tester),
      containsAll(['6000', '12000', '30000', '1.5', '4.0', '8.0']),
    );

    await _enregistrer(tester);
    expect(envois, hasLength(1));
    expect(envois.single.section, 'boost');
    expect(envois.single.valeur, _reglages.boostPricing);
    expect(envois.single.par, 'admin-7');
  });

  testWidgets('Taxes : une ligne par catégorie, renvoyées intactes', (tester) async {
    final envois = await _monter(tester, const AdminTaxesTab(settings: _reglages));

    // 0,05 × 100 n'est pas « 5.0 » en virgule flottante : on compare à
    // l'expression de l'onglet, pas à une valeur écrite à la main.
    final attendus = [
      for (final t in [0.05, 0.12, 0.20, 0.21, 0.22, 0.06, 0.07]) (t * 100).toString(),
    ];
    expect(_champs(tester), hasLength(7));
    expect(_champs(tester), unorderedEquals(attendus));

    await _enregistrer(tester);
    expect(envois, hasLength(1));
    expect(envois.single.section, 'taxes');
    final envoye = envois.single.valeur as TaxRatesEntity;
    for (final (nom, lu, voulu) in [
      ('alimentation', envoye.alimentation, 0.05),
      ('artisanat', envoye.artisanat, 0.12),
      ('standard', envoye.standard, 0.20),
      ('electronique', envoye.electronique, 0.21),
      ('vetements', envoye.vetements, 0.22),
      ('services', envoye.services, 0.06),
      ('immobilier', envoye.immobilier, 0.07),
    ]) {
      // Aller-retour ×100 puis ÷100 : égal à l'ulp près, pas bit pour bit.
      expect(lu, closeTo(voulu, 1e-9), reason: nom);
    }
    expect(envois.single.par, 'admin-7');
  });

  testWidgets('Médias : affiche les limites enregistrées et les renvoie', (tester) async {
    final envois = await _monter(tester, const AdminMediasTab(settings: _reglages));

    expect(
      _champs(tester),
      containsAll(['2560', '92', '8', '3000', '12', '80']),
    );

    await _enregistrer(tester);
    expect(envois, hasLength(1));
    expect(envois.single.section, 'medias');
    final envoye = envois.single.valeur as MediaLimitsEntity;
    expect(envoye.imageMaxWidth, 2560);
    expect(envoye.imageQuality, 92);
    expect(envoye.maxImagesPerUpload, 8);
    expect(envoye.messageMaxChars, 3000);
    expect(envoye.maxImageSizeMb, 12);
    expect(envoye.maxVideoSizeMb, 80);
    expect(envois.single.par, 'admin-7');
  });

  group('Système : deux boutons, chacun son groupe de champs', () {
    testWidgets('affiche les adresses et les intervalles enregistrés', (tester) async {
      await _monter(tester, const AdminSystemeTab(settings: _reglages));

      expect(_champs(tester), [
        'https://exemple.test/p/',
        'aide@exemple.test',
        'vie-privee@exemple.test',
        'bugs@exemple.test',
        'avis@exemple.test',
        'moderation@exemple.test',
        '7', '15', '90',
      ]);
      expect(find.byIcon(Icons.save_rounded), findsNWidgets(2));
    });

    testWidgets('le premier bouton n\'envoie que les adresses', (tester) async {
      final envois = await _monter(tester, const AdminSystemeTab(settings: _reglages));

      await _enregistrer(tester, rang: 0);
      expect(envois, hasLength(1));
      expect(envois.single.section, 'urls');
      final urls = envois.single.valeur as SystemUrlsEntity;
      expect(urls.shareBaseUrl, 'https://exemple.test/p/');
      expect(urls.supportEmail, 'aide@exemple.test');
      expect(urls.moderationEmail, 'moderation@exemple.test');
      // Ce que l'onglet ne montre pas est repris tel quel, pas remis au défaut.
      expect(urls.stripeMerchantId, _reglages.urls.stripeMerchantId);
      expect(urls.termsUrl, _reglages.urls.termsUrl);
      expect(envois.single.par, 'admin-7');
    });

    testWidgets('le second bouton n\'envoie que les intervalles', (tester) async {
      final envois = await _monter(tester, const AdminSystemeTab(settings: _reglages));

      await _enregistrer(tester, rang: 1);
      expect(envois, hasLength(1));
      expect(envois.single.section, 'intervalles');
      final iv = envois.single.valeur as SystemIntervalsEntity;
      expect(iv.locationUpdateMinutes, 7);
      expect(iv.heartbeatMinutes, 15);
      expect(iv.cacheMinutes, 90);
      expect(iv.remoteConfigFetchMinutes, _reglages.intervals.remoteConfigFetchMinutes);
      expect(iv.typingIndicatorSeconds, _reglages.intervals.typingIndicatorSeconds);
      expect(envois.single.par, 'admin-7');
    });
  });

  testWidgets("Frais : les réglages par défaut s'enregistrent sans rien retaper", (tester) async {
    // 500 et 10000 sont des `double` dans l'entité : affichés « 500.0 », ils
    // étaient refusés par un validateur d'entiers — l'admin devait retaper les
    // quatre montants pour pouvoir enregistrer quoi que ce soit.
    const defauts = AppSettingsEntity();
    final envois = await _monter(
      tester,
      const AdminFraisTab(settings: defauts),
      reglages: defauts,
    );

    await _enregistrer(tester);

    expect(envois, hasLength(1), reason: 'le formulaire ne doit pas se refuser');
    expect(envois.single.valeur, const FeeSettingsEntity());
  });

  testWidgets('une saisie invalide n\'est pas envoyée (Frais)', (tester) async {
    final envois = await _monter(tester, const AdminFraisTab(settings: _reglages));

    await tester.enterText(find.byType(EditableText).first, '');
    await _enregistrer(tester);

    expect(envois, isEmpty, reason: 'un champ vide ne doit pas partir au serveur');
  });
}
