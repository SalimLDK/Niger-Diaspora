// Pagination de l'écran Transferts : l'état que l'écran lit.
//
// Les requêtes passent par le client Supabase global et ne se testent pas en
// unitaire. Verrouillé ici : le statut que chaque onglet envoie au serveur,
// quelle liste sert quel onglet, et que les compteurs réels (`count`) ne
// bougent pas quand on ajoute une page.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';

void main() {
  test('chaque onglet filtre sur le statut que la table connaît', () {
    expect(
      FiltreTransferts.values.map((f) => f.statut),
      [null, 'pending', 'failed', 'completed'],
    );
  });

  test('liste() rend la liste de chaque onglet', () {
    const etat = AdminTransactionsState();
    expect(etat.liste(FiltreTransferts.toutes), same(etat.transactions));
    expect(etat.liste(FiltreTransferts.enAttente), same(etat.pendingTransactions));
    expect(etat.liste(FiltreTransferts.echouees), same(etat.failedTransactions));
    expect(etat.liste(FiltreTransferts.completees), same(etat.completedTransactions));
  });

  test('les compteurs réels et les pages restantes survivent à un copyWith', () {
    final etat = const AdminTransactionsState().copyWith(
      nbEnAttente: 120,
      nbEchouees: 7,
      encorePlus: {FiltreTransferts.toutes},
    );
    final apres = etat.copyWith(isLoading: true);
    expect(apres.nbEnAttente, 120);
    expect(apres.nbEchouees, 7);
    expect(apres.encorePlus, {FiltreTransferts.toutes});
  });

  test('chargementPlus se pose, survit, puis se referme explicitement', () {
    final en = const AdminTransactionsState()
        .copyWith(chargementPlus: FiltreTransferts.echouees);
    expect(en.copyWith(isLoading: false).chargementPlus, FiltreTransferts.echouees);
    expect(en.copyWith(finChargementPlus: true).chargementPlus, isNull);
  });
}
