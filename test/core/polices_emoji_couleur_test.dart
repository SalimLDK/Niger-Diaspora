import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// « ❤️ » s'affichait en cœur NOIR partout où le texte est en Inter.
///
/// Inter dessine sa propre version monochrome de U+2764, et Flutter prend le
/// glyphe de la police du style dès qu'elle en a un — le sélecteur U+FE0F n'y
/// change rien. `tools/polices_emoji_couleur.py` retire ces entrées de la table
/// `cmap` ; ce test empêche qu'une police re-téléchargée les ramène en silence.
void main() {
  final inter = Directory('assets/google_fonts')
      .listSync()
      .whereType<File>()
      .where((f) => f.uri.pathSegments.last.startsWith('Inter-'))
      .toList();

  test('les quatre graisses d\'Inter sont là', () {
    expect(inter, hasLength(4));
  });

  for (final fichier in inter) {
    final nom = fichier.uri.pathSegments.last;
    final couverts = _pointsCouverts(fichier.readAsBytesSync());

    test('$nom : le lecteur de cmap lit vraiment la police', () {
      // Sans ce témoin, un lecteur cassé qui ne trouve rien ferait passer
      // le test suivant pour de mauvaises raisons.
      expect(couverts(0x41), isTrue, reason: 'la lettre A');
      expect(couverts(0x20AC), isTrue, reason: 'le signe euro');
    });

    test('$nom : ne masque plus les emojis couleur', () {
      expect(couverts(0x2764), isFalse, reason: '❤ — relancer '
          'python tools/polices_emoji_couleur.py');
      expect(couverts(0x2665), isFalse, reason: '♥');
      expect(couverts(0x2600), isFalse, reason: '☀');
    });

    test('$nom : garde les symboles que l\'interface emploie en texte', () {
      // Salons audio : « ⚠ Avertir », « ↗ Partager » doivent prendre la
      // couleur du style, pas devenir des emojis.
      expect(couverts(0x26A0), isTrue, reason: '⚠');
      expect(couverts(0x2197), isTrue, reason: '↗');
    });
  }
}

/// Renvoie un prédicat « la police a un glyphe pour ce point de code », lu
/// dans les sous-tables `cmap` de format 4 (BMP) et 12 (Unicode complet).
bool Function(int) _pointsCouverts(Uint8List octets) {
  final d = ByteData.sublistView(octets);
  final nbTables = d.getUint16(4);
  int? cmap;
  for (var i = 0; i < nbTables; i++) {
    final r = 12 + 16 * i;
    final tag = String.fromCharCodes(octets.sublist(r, r + 4));
    if (tag == 'cmap') cmap = d.getUint32(r + 8);
  }
  if (cmap == null) throw StateError('pas de table cmap');

  final sousTables = <int>[];
  final nbEnc = d.getUint16(cmap + 2);
  for (var i = 0; i < nbEnc; i++) {
    sousTables.add(cmap + d.getUint32(cmap + 4 + 8 * i + 4));
  }

  bool format4(int t, int cp) {
    if (cp > 0xFFFF) return false;
    final segX2 = d.getUint16(t + 6);
    final fin = t + 14;
    final debut = fin + segX2 + 2;
    final delta = debut + segX2;
    final plage = delta + segX2;
    for (var s = 0; s < segX2; s += 2) {
      if (d.getUint16(fin + s) < cp) continue;
      if (d.getUint16(debut + s) > cp) return false;
      final decalage = d.getUint16(plage + s);
      if (decalage == 0) {
        return (cp + d.getUint16(delta + s)) & 0xFFFF != 0;
      }
      final g = d.getUint16(
        plage + s + decalage + 2 * (cp - d.getUint16(debut + s)),
      );
      return g != 0;
    }
    return false;
  }

  bool format12(int t, int cp) {
    final groupes = d.getUint32(t + 12);
    for (var i = 0; i < groupes; i++) {
      final g = t + 16 + 12 * i;
      if (cp >= d.getUint32(g) && cp <= d.getUint32(g + 4)) return true;
    }
    return false;
  }

  return (cp) => sousTables.any((t) {
        switch (d.getUint16(t)) {
          case 4:
            return format4(t, cp);
          case 12:
            return format12(t, cp);
          default:
            return false;
        }
      });
}
