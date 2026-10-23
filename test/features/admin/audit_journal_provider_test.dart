import 'package:diaspo_niger/features/admin/presentation/providers/audit_journal_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('export CSV du journal', () {
    test('une cellule qui ressemble à une formule est neutralisée', () {
      for (final f in ['=1+1', '+cmd', '-2', '@SUM(A1)']) {
        expect(AuditJournalNotifier.cellule(f), '"\'$f"');
      }
    });

    test('guillemets doublés, objets en JSON, null vide', () {
      expect(AuditJournalNotifier.cellule('dit "oui"'), '"dit ""oui"""');
      expect(AuditJournalNotifier.cellule({'a': 1}), '"{""a"":1}"');
      expect(AuditJournalNotifier.cellule(null), '""');
    });

    test('en-tête puis une ligne par entrée', () {
      final csv = AuditJournalNotifier.enCsv([
        {'action': 'MEMBER_WARNED', 'admin_name': 'Salim'},
      ]);
      final lignes = csv.trim().split('\r\n');
      expect(lignes.length, 2);
      expect(lignes.first, startsWith('created_at,admin_name'));
      expect(lignes.last, contains('"MEMBER_WARNED"'));
    });
  });

  group('filtres', () {
    test('les jokers LIKE saisis sont littéraux', () {
      expect(AuditJournalNotifier.echapperLike(r'a%b_c\d'), r'a\%b\_c\\d');
    });

    test('une valeur de or() ne peut pas en changer la grammaire', () {
      final v = AuditJournalNotifier.citer('x",admin_id.eq.y');
      expect(v, r'"x\",admin_id.eq.y"');
    });

    test('le jour de fin est inclus', () {
      final f = AuditFiltre(au: DateTime(2026, 10, 31));
      expect(f.auExclu, DateTime(2026, 11, 1));
      expect(const AuditFiltre().vide, isTrue);
    });
  });
}
