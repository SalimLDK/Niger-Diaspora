import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/groups/presentation/providers/villes_du_groupe_pays_provider.dart';

/// « Montréal · 12, Toronto · 5 » sur la fiche d'un groupe de pays.
///
/// La section s'efface d'elle-même quand la liste est vide — ce qui est voulu
/// sur un groupe de ville, et catastrophique sur une erreur de décodage : une
/// clé mal nommée lèverait, la section deviendrait une `AsyncError`, et
/// `valueOrNull` la ferait disparaître exactement comme si le pays n'avait
/// aucune ville. Rien à l'écran, rien dans les journaux, rien à chercher.
///
/// D'où un décodage qui ignore la ligne abîmée et garde les autres.
void main() {
  Map<String, dynamic> ligne({
    Object? groupId = 'aa11bb22-cc33-dd44-ee55-ff6677889900',
    Object? nom = 'Montréal',
    Object? membres = 12,
  }) => {'group_id': groupId, 'nom': nom, 'member_count': membres};

  test('lit ce que rend la fonction SQL', () {
    final villes = lireVillesDuGroupePays([
      ligne(),
      ligne(nom: 'Toronto', membres: 5),
    ]);
    expect(villes.map((v) => '${v.nom} · ${v.memberCount}'),
        ['Montréal · 12', 'Toronto · 5']);
  });

  test('un groupe de ville ne rend rien, et ce n\'est pas une erreur', () {
    expect(lireVillesDuGroupePays(const []), isEmpty);
  });

  test('une ligne abîmée est sautée, les autres passent', () {
    // Le cas qui compte : sans cette tolérance, UNE ligne fautive effacerait
    // la liste entière — et le pays paraîtrait n'avoir aucune ville.
    final villes = lireVillesDuGroupePays([
      ligne(nom: null),
      ligne(groupId: 42),
      ligne(nom: 'Toronto', membres: 5),
    ]);
    expect(villes.map((v) => v.nom), ['Toronto']);
  });

  test('un compteur absent vaut zéro, pas une exception', () {
    final villes = lireVillesDuGroupePays([
      {'group_id': 'aa11bb22-cc33-dd44-ee55-ff6677889900', 'nom': 'Niamey'},
    ]);
    expect(villes.single.memberCount, 0);
  });

  test('une réponse qui n\'est pas une liste ne fait pas tomber la fiche', () {
    expect(lireVillesDuGroupePays(null), isEmpty);
    expect(lireVillesDuGroupePays('erreur'), isEmpty);
  });
}
