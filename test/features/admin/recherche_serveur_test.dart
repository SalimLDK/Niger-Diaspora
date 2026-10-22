// Recherche côté serveur des écrans Commerces et Marketplace.
//
// Les requêtes passent par le client Supabase global et ne se testent pas en
// unitaire. Verrouillé ici : ce que la saisie de l'admin devient dans le
// filtre `or(...)` de PostgREST (où virgule et parenthèses sont de la syntaxe),
// et que la recherche survit aux copyWith de l'état que les écrans lisent.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/recherche_serveur.dart';

void main() {
  group('motifRecherche', () {
    test('une saisie vide, blanche ou faite de syntaxe ne filtre rien', () {
      expect(motifRecherche(''), isNull);
      expect(motifRecherche('   '), isNull);
      expect(motifRecherche(',()"*'), isNull);
    });

    test('un mot devient un ilike « contient »', () {
      expect(motifRecherche(' Niamey '), '%Niamey%');
    });

    test('la syntaxe du filtre or() ne passe pas par la saisie', () {
      final motif = motifRecherche('a,status.eq.x)')!;
      expect(motif, isNot(contains(',')));
      expect(motif, isNot(contains(')')));
      // Quatre colonnes, donc trois virgules : celles de la clause seulement.
      final clause = clauseRecherche(['name', 'city', 'category', 'email'], motif);
      expect(','.allMatches(clause).length, 3);
    });

    test('% et _ saisis sont des caractères, pas des jokers', () {
      expect(motifRecherche('100%_'), r'%100\%\_%');
    });

    test('* saisi ne devient pas un joker PostgREST', () {
      expect(motifRecherche('a*b'), '%a b%');
    });
  });

  test('la clause cherche le motif dans chaque colonne, dans l\'ordre', () {
    expect(
      clauseRecherche(['title', 'description', 'category'], '%riz%'),
      'title.ilike.%riz%,description.ilike.%riz%,category.ilike.%riz%',
    );
  });

  test('la recherche d\'un commerce survit à un copyWith', () {
    final etat = const AdminBusinessState().copyWith(recherche: 'riz');
    expect(etat.copyWith(isLoading: true).recherche, 'riz');
    expect(etat.copyWith(finChargementPlus: true).recherche, 'riz');
  });

  test('la recherche de la marketplace survit à un copyWith', () {
    final etat = const AdminMarketplaceState().copyWith(recherche: 'riz');
    expect(etat.copyWith(isLoading: true).recherche, 'riz');
    expect(etat.copyWith(finChargementPlus: true).recherche, 'riz');
  });

  test('une recherche différente change l\'état (Equatable)', () {
    expect(
      const AdminBusinessState(recherche: 'a'),
      isNot(const AdminBusinessState(recherche: 'b')),
    );
    expect(
      const AdminMarketplaceState(recherche: 'a'),
      isNot(const AdminMarketplaceState(recherche: 'b')),
    );
  });
}
