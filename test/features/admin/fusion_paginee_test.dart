// FusionPaginee : deux listes triées (Firestore, Supabase) lues comme une
// seule. Ce qui doit tenir : l'ordre global, aucune ligne perdue ni doublée
// d'une page à l'autre, et une source qui filtre sans rien garder ne ferme pas
// la lecture trop tôt.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/fusion_paginee.dart';

/// Une source qui sert [valeurs] par lots de [taille], la plus grande d'abord.
Future<LotPagine<int>> Function() _source(
  List<int> valeurs,
  int taille, {
  List<int>? appels,
}) {
  var pos = 0;
  return () async {
    appels?.add(pos);
    final lot = valeurs.skip(pos).take(taille).toList();
    pos += lot.length;
    return (items: lot, fini: pos >= valeurs.length);
  };
}

int _plusGrandD(int a, int b) => b.compareTo(a);

void main() {
  test("deux sources se fondent dans l'ordre, page après page, sans perte",
      () async {
    final f = FusionPaginee<int>(
      avant: _plusGrandD,
      sources: [_source([90, 70, 50, 30, 10], 2), _source([80, 60, 40, 20], 3)],
    );
    final p1 = await f.prochainePage(4);
    final p2 = await f.prochainePage(4);
    final p3 = await f.prochainePage(4);
    expect(p1, [90, 80, 70, 60]);
    expect(p2, [50, 40, 30, 20]);
    expect(p3, [10]);
    expect(f.encorePlus, isFalse);
  });

  test("une source vide laisse passer l'autre", () async {
    final f = FusionPaginee<int>(
      avant: _plusGrandD,
      sources: [_source([], 5), _source([3, 2, 1], 5)],
    );
    expect(await f.prochainePage(10), [3, 2, 1]);
    expect(f.encorePlus, isFalse);
  });

  test("une source n'est relue que quand son tampon est vide", () async {
    final appels = <int>[];
    final f = FusionPaginee<int>(
      avant: _plusGrandD,
      sources: [_source([100, 99, 98, 97], 4, appels: appels), _source([1], 4)],
    );
    await f.prochainePage(2);
    expect(appels, [0],
        reason: 'un seul lot suffit pour deux lignes sur quatre');
  });

  test("encorePlus reste vrai tant qu'il reste des lignes ou une source ouverte",
      () async {
    final f = FusionPaginee<int>(
      avant: _plusGrandD,
      sources: [_source([5, 4, 3], 2), _source([2, 1], 2)],
    );
    await f.prochainePage(2);
    expect(f.encorePlus, isTrue);
    await f.prochainePage(10);
    expect(f.encorePlus, isFalse);
  });

  test("un lot vide mais pas fini relance la source, jusqu'à ce qu'elle livre",
      () async {
    var n = 0;
    Future<LotPagine<int>> filtrante() async {
      n++;
      if (n < 4) return (items: <int>[], fini: false);
      return (items: <int>[7], fini: true);
    }

    final f = FusionPaginee<int>(avant: _plusGrandD, sources: [filtrante]);
    expect(await f.prochainePage(5), [7]);
    expect(n, 4);
  });

  test("une source qui ne livre jamais est abandonnée, pas attendue sans fin",
      () async {
    var n = 0;
    Future<LotPagine<int>> muette() async {
      n++;
      return (items: <int>[], fini: false);
    }

    final f = FusionPaginee<int>(
      avant: _plusGrandD,
      sources: [muette, _source([1], 5)],
    );
    expect(await f.prochainePage(5), [1]);
    expect(n, FusionPaginee.maxLotsVidesDeSuite);
    expect(f.encorePlus, isFalse);
  });
}
