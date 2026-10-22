// Pagination et recherche serveur de l'écran Signalements.
//
// Les requêtes passent par le client Supabase global et ne se testent pas en
// unitaire. Verrouillé ici : ce que la saisie de l'admin devient dans le
// filtre `or(...)` de PostgREST (où virgule et parenthèses sont de la
// syntaxe), et le contrat de l'état que l'écran lit.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';

void main() {
  group('motifRechercheSignalements', () {
    test('une saisie vide ou blanche ne filtre rien', () {
      expect(motifRechercheSignalements(''), isNull);
      expect(motifRechercheSignalements('   '), isNull);
      expect(motifRechercheSignalements(',()"'), isNull);
    });

    test('un mot devient un ilike « contient »', () {
      expect(motifRechercheSignalements(' spam '), '%spam%');
    });

    test('la syntaxe du filtre or() ne passe pas par la saisie', () {
      final motif = motifRechercheSignalements('a,status.eq.resolved)')!;
      expect(motif, isNot(contains(',')));
      expect(motif, isNot(contains(')')));
      final clause = clauseRechercheSignalements(motif);
      // Cinq champs, donc quatre virgules : celles de la clause seulement.
      expect(','.allMatches(clause).length, 4);
    });

    test('% et _ saisis sont des caractères, pas des jokers', () {
      expect(motifRechercheSignalements('100%_'), r'%100\%\_%');
    });
  });

  test('la clause cherche dans les cinq champs que l\'écran filtrait', () {
    expect(
      clauseRechercheSignalements('%x%'),
      'target_name.ilike.%x%,reporter_name.ilike.%x%,reason.ilike.%x%,'
      'target_id.ilike.%x%,description.ilike.%x%',
    );
  });

  group('AdminReportsState', () {
    test('liste() rend la liste de chaque onglet', () {
      const etat = AdminReportsState();
      expect(etat.liste(FiltreSignalements.enAttente), same(etat.pendingReports));
      expect(etat.liste(FiltreSignalements.traites), same(etat.treatedReports));
      expect(etat.liste(FiltreSignalements.tous), same(etat.reports));
    });

    test('recherche, type et compteurs survivent à un copyWith', () {
      final etat = const AdminReportsState().copyWith(
        recherche: 'spam',
        typeFiltre: 'user',
        compteurs: const CompteursSignalements(total: 300, enAttente: 12),
      );
      final apres = etat.copyWith(isLoading: true);
      expect(apres.recherche, 'spam');
      expect(apres.typeFiltre, 'user');
      expect(apres.compteurs.total, 300);
    });

    test('le type se retire explicitement, pas en passant null', () {
      final etat = const AdminReportsState().copyWith(typeFiltre: 'user');
      expect(etat.copyWith(recherche: 'x').typeFiltre, 'user');
      expect(etat.copyWith(effacerTypeFiltre: true).typeFiltre, isNull);
    });

    test('chargementPlus se pose, survit, puis se referme explicitement', () {
      final en = const AdminReportsState()
          .copyWith(chargementPlus: FiltreSignalements.traites);
      expect(en.copyWith(isLoading: false).chargementPlus,
          FiltreSignalements.traites);
      expect(en.copyWith(finChargementPlus: true).chargementPlus, isNull);
    });
  });
}
