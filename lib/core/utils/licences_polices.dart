import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Familles de police embarquées dans `assets/google_fonts/`.
///
/// Jusqu'au 2026-09-11, google_fonts téléchargeait chaque graisse au premier
/// affichage depuis fonts.gstatic.com : hors ligne, le texte retombait sur la
/// police système, et Crashlytics recevait des `Failed host lookup:
/// 'fonts.gstatic.com'` (4 événements, 3 utilisateurs). Les fichiers sont
/// désormais dans l'APK — le paquet consulte les assets avant le réseau.
///
/// [fichier] est le préfixe exigé par google_fonts : `<fichier>-<Variante>.ttf`
/// (`Inter-SemiBold.ttf`, `InstrumentSerif-Italic.ttf`…).
const List<({String nom, String fichier})> famillesPoliceEmbarquees = [
  (nom: 'Inter', fichier: 'Inter'),
  (nom: 'Playfair Display', fichier: 'PlayfairDisplay'),
  (nom: 'Roboto Mono', fichier: 'RobotoMono'),
  (nom: 'Instrument Serif', fichier: 'InstrumentSerif'),
  (nom: 'Instrument Sans', fichier: 'InstrumentSans'),
  (nom: 'IBM Plex Mono', fichier: 'IBMPlexMono'),
  (nom: 'Caprasimo', fichier: 'Caprasimo'),
  (nom: 'Figtree', fichier: 'Figtree'),
];

/// Rend un texte de licence affichable : fins de ligne ramenées à `\n`.
///
/// La copie de travail qui sert au build peut porter des CRLF — les huit
/// `LICENCE-*.txt` y ont été écrits ainsi à leur import, sous Windows, le
/// 2026-09-11 — et l'APK l'embarque telle quelle. `LicenseEntryWithLineBreaks`
/// découpe sur `\n` et laisse le `\r` : chacun s'affichait comme un carré sur
/// la page Licences (vu sur SM A515F).
@visibleForTesting
String texteLicenceAffichable(String brut) =>
    brut.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// Enregistre la licence de chaque famille embarquée.
///
/// Toutes sont sous SIL Open Font License, qui impose que son texte
/// accompagne toute redistribution des fichiers — ce que l'app fait depuis
/// qu'elle les embarque. L'obligation est remplie par les fichiers
/// `LICENCE-*.txt` eux-mêmes, livrés dans l'APK à côté des polices.
///
/// L'enregistrement ici les rend en plus lisibles sur la page ouverte par
/// Réglages → « Licences open source » (`showLicensePage`), sous le nom de
/// leur famille, à côté de celles des paquets (MIT, BSD, Apache…). Aucun
/// écran n'y menait avant le 2026-09-11.
///
/// Le chargement est paresseux : [LicenseRegistry] n'appelle le générateur
/// qu'à l'ouverture de la page, rien n'est lu au démarrage.
void enregistrerLicencesPolices() {
  LicenseRegistry.addLicense(() async* {
    for (final famille in famillesPoliceEmbarquees) {
      final texte = texteLicenceAffichable(
        await rootBundle.loadString(
          'assets/google_fonts/LICENCE-${famille.fichier}.txt',
        ),
      );
      yield LicenseEntryWithLineBreaks(<String>[famille.nom], texte);
    }
  });
}
