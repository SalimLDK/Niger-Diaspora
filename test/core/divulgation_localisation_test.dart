import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou de la divulgation préalable de localisation (« Prominent
/// Disclosure » de Google Play).
///
/// Trois envois ont été refusés sur ce terrain, dont celui du 2026-09-09 :
/// « The in-app Prominent Disclosure does not disclose the usage of accessed
/// or collected Location data ». Le texte incriminé, sur l'écran 5/5 de
/// l'onboarding, disait « Réciproque : vous voyez ceux qui partagent » — un
/// bénéfice, jamais une collecte.
///
/// Le refus ne se voit ni à la compilation, ni à l'exécution : l'application
/// marche parfaitement sans divulgation. Seul un examinateur le voit, trois
/// jours plus tard. D'où ces deux vérifications de structure.
///
/// Limite assumée : ce test lit la source et les ARB. Monter les écrans en
/// test widget demanderait l10n, GoRouter, Firebase et une dizaine de
/// providers — disproportionné pour verrouiller une convention.
void main() {
  /// Fichiers autorisés à toucher l'autorisation de localisation sans passer
  /// par la divulgation, avec la raison. Cette liste ne peut que rétrécir.
  const exceptions = <String, String>{
    'lib/core/services/location_service.dart':
        "le service lui-même, sans BuildContext : c'est l'appelant qui divulgue",
    'lib/core/widgets/location_disclosure.dart': 'la divulgation elle-même',
    'lib/core/services/background_location_service.dart':
        'le service du Mode Voyage, sans BuildContext : son interrupteur '
            'divulgue (variante « arrierePlan ») avant de le démarrer',
    'lib/features/messages/presentation/screens/new_conversation_screen.dart':
        "ne lit la position que si l'autorisation est DÉJÀ accordée "
            '(`checkPermission` en garde, retour anticipé sinon) : cet écran '
            'ne fait jamais apparaître la boîte système',
  };

  /// Les appels qui font apparaître la boîte système, directement ou non.
  /// `getCurrentPosition` en fait partie : le service demande l'autorisation
  /// lui-même quand elle manque.
  final appelsSensibles = RegExp(
    r'Geolocator\.requestPermission\(|'
    r'Geolocator\.getCurrentPosition\(|'
    r'LocationService\.instance\.getCurrentPosition\(|'
    r'LocationService\.instance\.requestLocationPermission\(',
  );

  test('tout écran qui déclenche la demande système passe par la divulgation', () {
    final coupables = <String>[];

    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    )) {
      final chemin = file.path.replaceAll(r'\', '/');
      if (exceptions.containsKey(chemin)) continue;

      final source = file.readAsStringSync();
      if (!appelsSensibles.hasMatch(source)) continue;
      if (source.contains('location_disclosure.dart')) continue;

      coupables.add(chemin);
    }

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces fichiers demandent la position sans importer '
          '`core/widgets/location_disclosure.dart`. Appelez '
          '`demanderLocalisationAvecDivulgation(context)` avant de lire une '
          'position, sinon la boîte système apparaît sans que rien ait été '
          'expliqué — le motif exact des refus Google.',
    );
  });

  test('le texte de divulgation nomme la collecte, l\'usage et le partage', () {
    final arb =
        jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
            as Map<String, dynamic>;

    // Ce que Google exige explicitement : la donnée, l'usage, le partage.
    for (final cle in ['locationDisclosureBody', 'locationDisclosureShort']) {
      final texte = arb[cle] as String?;
      expect(texte, isNotNull, reason: 'clé $cle absente de app_fr.arb');
      expect(
        texte,
        contains('collecte des données de localisation'),
        reason: '$cle doit nommer la collecte, pas seulement le bénéfice',
      );
      expect(
        texte,
        contains('visible par les autres membres'),
        reason: '$cle doit dire que la position est partagée',
      );
    }

    // La variante « discussion » dit l'inverse, et c'est voulu : la position
    // ne rejoint pas la carte. Une divulgation qui annonce plus que ce que
    // l'app fait est aussi fautive qu'une qui en annonce moins.
    final discussion = arb['locationDisclosureChatBody'] as String?;
    expect(discussion, isNotNull);
    expect(discussion, contains('participants de la discussion'));
    expect(
      discussion,
      isNot(contains('visible par les autres membres')),
      reason:
          'Le partage en discussion ne va pas sur la carte des membres : le '
          'dire serait faux.',
    );

    // La variante « champ ville » ne publie RIEN : la position est lue une
    // fois, sur l'appareil, et seul le nom de la ville part dans le profil.
    // Son texte doit le dire — et surtout ne pas promettre la carte des
    // membres, qui ne la reçoit pas.
    final ville = arb['locationDisclosureCityBody'] as String?;
    expect(ville, isNotNull, reason: 'clé locationDisclosureCityBody absente');
    expect(ville, contains('lit votre position'));
    expect(
      ville,
      contains('ni enregistrées ni partagées'),
      reason: 'le seul usage qui ne publie rien doit le dire',
    );
    expect(
      ville,
      isNot(contains('visible par les autres membres')),
      reason:
          'Le champ ville ne place personne sur la carte : annoncer le '
          'contraire serait une divulgation fausse, aussi fautive '
          "qu'une absente.",
    );

    // Formule attendue mot pour mot pour une collecte hors premier plan.
    expect(
      arb['locationDisclosureBackgroundBody'],
      contains("même lorsque l'application est fermée ou n'est pas utilisée"),
      reason:
          'Le Mode Voyage publie une position toutes les 5 minutes hors '
          'premier plan : la divulgation doit porter cette formule.',
    );
  });
}
