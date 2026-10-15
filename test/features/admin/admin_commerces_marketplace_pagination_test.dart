// Pagination des écrans Commerces et Marketplace : l'état que les écrans lisent.
//
// Les requêtes passent par le client Supabase global et ne se testent pas en
// unitaire. Verrouillé ici : quelle liste sert quel onglet, et qu'une page
// « en cours » se referme sans toucher aux pages restantes.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';

void main() {
  group('AdminBusinessState', () {
    test('liste() rend la liste de chaque filtre', () {
      const etat = AdminBusinessState();
      expect(etat.liste(FiltreCommerces.tous), same(etat.businesses));
      expect(etat.liste(FiltreCommerces.enAttente), same(etat.pendingVerification));
      expect(etat.liste(FiltreCommerces.boostes), same(etat.boosted));
    });

    test('les pages restantes survivent à un copyWith', () {
      final etat = const AdminBusinessState()
          .copyWith(encorePlus: {FiltreCommerces.enAttente});
      expect(etat.copyWith(isLoading: true).encorePlus, {FiltreCommerces.enAttente});
    });

    test('chargementPlus se pose, survit, puis se referme explicitement', () {
      final en = const AdminBusinessState()
          .copyWith(chargementPlus: FiltreCommerces.boostes);
      expect(en.copyWith(isLoading: false).chargementPlus, FiltreCommerces.boostes);
      expect(en.copyWith(finChargementPlus: true).chargementPlus, isNull);
    });
  });

  group('AdminMarketplaceState', () {
    test('les pages restantes de chaque liste survivent à un copyWith', () {
      final etat = const AdminMarketplaceState().copyWith(
        encorePlus: {ListeMarketplace.produits, ListeMarketplace.litiges},
      );
      final apres = etat.copyWith(isLoading: true, error: 'x');
      expect(
        apres.encorePlus,
        {ListeMarketplace.produits, ListeMarketplace.litiges},
      );
    });

    test('chargementPlus se pose, survit, puis se referme explicitement', () {
      final en = const AdminMarketplaceState()
          .copyWith(chargementPlus: ListeMarketplace.commandes);
      expect(en.copyWith(isLoading: false).chargementPlus,
          ListeMarketplace.commandes);
      expect(en.copyWith(finChargementPlus: true).chargementPlus, isNull);
    });
  });
}
