import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le temps réel mourait après un passage en arrière-plan — vu le 2026-09-21
/// à deux téléphones, build 1.2.2+26 :
///
/// - Pixel 10 Pro XL, app restée des heures derrière une autre : discussion
///   ouverte au premier plan, plus rien n'arrivait, la liste restait figée.
///   Rouvrir la discussion ne changeait rien ; seule une relance réparait.
///   Au retour, `supabase_flutter` re-rejoint les canaux avec le jeton
///   PÉRIMÉ ; le serveur refuse la réplication en différé et le canal reste
///   « joined », muet. Le jeton neuf du pont n'y changeait rien.
/// - SM A515F, simple HOME : un message reçu pendant l'absence n'apparaissait
///   pas dans la discussion affichée au retour. Le canal `mls_new` n'avait pas
///   de rattrapage au rejoint.
///
/// Un vrai serveur Realtime serait nécessaire pour rejouer ces pannes ; ce
/// banc tient les deux branchements, qu'une refonte ferait tomber sans bruit.
String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

/// Le corps d'une méthode, de sa signature à la méthode suivante.
String _corps(String source, String signature) {
  final debut = source.indexOf(signature);
  expect(debut, isNot(-1), reason: '« $signature » introuvable');
  final fin = source.indexOf(RegExp(r'\n  @override\n'), debut + 1);
  return source.substring(debut, fin == -1 ? source.length : fin);
}

void main() {
  const datasource =
      'lib/features/messages/data/datasources/message_supabase_datasource.dart';

  test('le canal des messages chiffrés relit au rejoint', () {
    final corps = _corps(
      _source(datasource),
      'Stream<void> mlsNouveauxMessages(',
    );
    expect(corps, contains('rattrapageAuRejoint('),
        reason: 'sans rattrapage, un message arrivé pendant l\'arrière-plan '
            'reste absent de la discussion affichée');
  });

  test('le retour avec un jeton périmé réabonne le temps réel', () {
    final pont = _source('lib/core/services/supabase_auth_bridge.dart');
    final debut = pont.indexOf('void reprendreApresRetourReseau()');
    expect(debut, isNot(-1));
    final corps = pont.substring(debut, pont.indexOf('\n  }\n', debut));
    expect(corps, contains('reabonnerLeTempsReel('),
        reason: 'le jeton neuf seul ne remonte pas un abonnement refusé');
    // Après l'échange, pas avant : réabonner avec le jeton périmé ne
    // servirait à rien.
    expect(
      corps.indexOf('syncWithFirebase(user)'),
      lessThan(corps.indexOf('reabonnerLeTempsReel(')),
    );
  });

  test('le réabonnement rouvre le socket puis rejoint les canaux', () {
    final corps = _source('lib/core/utils/reabonnement_temps_reel.dart');
    final deconnexion = corps.indexOf('realtime.disconnect()');
    final connexion = corps.indexOf('realtime.connect()');
    final rejoint = corps.indexOf('forceRejoin()');
    expect([deconnexion, connexion, rejoint], everyElement(isNot(-1)));
    expect(deconnexion, lessThan(connexion));
    expect(connexion, lessThan(rejoint));
  });
}
