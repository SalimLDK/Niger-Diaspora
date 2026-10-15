// Pagination de l'écran Utilisateurs : l'état que l'écran lit.
//
// Les appels `profils_admin_page` passent par le client Supabase global et ne
// se testent pas en unitaire ; ce qui est verrouillé ici, c'est le contrat de
// l'état — quelle liste sert quel onglet, et qu'une page « en cours » se
// referme sans toucher au reste.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';

void main() {
  group('FiltreUtilisateurs', () {
    test('les valeurs envoyées à la RPC sont celles que la fonction accepte', () {
      expect(
        FiltreUtilisateurs.values.map((f) => f.valeurRpc),
        ['tous', 'admins', 'bannis'],
      );
    });
  });

  group('AdminUsersState', () {
    test('liste() rend la liste de chaque onglet', () {
      const etat = AdminUsersState();
      expect(etat.liste(FiltreUtilisateurs.tous), same(etat.users));
      expect(etat.liste(FiltreUtilisateurs.admins), same(etat.admins));
      expect(etat.liste(FiltreUtilisateurs.bannis), same(etat.bannedUsers));
    });

    test('la recherche et les pages restantes survivent à un copyWith', () {
      final etat = const AdminUsersState().copyWith(
        recherche: 'aminata',
        encorePlus: {FiltreUtilisateurs.tous},
      );
      final apres = etat.copyWith(isLoading: true);
      expect(apres.recherche, 'aminata');
      expect(apres.encorePlus, {FiltreUtilisateurs.tous});
    });

    test('chargementPlus se pose, survit, puis se referme explicitement', () {
      final en = const AdminUsersState()
          .copyWith(chargementPlus: FiltreUtilisateurs.bannis);
      expect(en.chargementPlus, FiltreUtilisateurs.bannis);
      expect(en.copyWith(isLoading: false).chargementPlus,
          FiltreUtilisateurs.bannis);
      expect(en.copyWith(finChargementPlus: true).chargementPlus, isNull);
    });

    test("l'erreur s'efface dès qu'on ne la repasse pas", () {
      final etat = const AdminUsersState().copyWith(error: 'refus');
      expect(etat.copyWith(isLoading: true).error, isNull);
    });
  });
}
