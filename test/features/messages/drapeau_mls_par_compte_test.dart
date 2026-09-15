import 'package:diaspo_niger/features/admin/data/models/app_settings_model.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS, phase 5)
/// ----------------------------------------------
/// Le drapeau `mlsMessages` est global, et l'ouvrir fait basculer les
/// conversations **sans retour** : `conversations.mls_since` ne se remet
/// jamais à NULL. Vérifier MLS sur un seul téléphone demandait donc de
/// basculer la production entière. Vérifier ne doit pas être un point de
/// non-retour, d'où `mlsMessagesComptes` : une liste d'uid pour qui MLS est
/// actif, sans que rien d'autre ne bouge.
///
/// Ce que ces tests empêchent, concrètement : qu'une valeur absente, nulle ou
/// mal typée dans `admin_settings` ouvre le drapeau au lieu de le laisser
/// fermé. Un interrupteur de sécurité qui échoue en s'ouvrant est pire que
/// pas d'interrupteur, et ce dépôt a déjà payé ce motif avec les endpoints
/// dont la vérification sautait quand le secret manquait.

void main() {
  group('lecture de mlsMessagesComptes depuis admin_settings', () {
    test('clé absente : liste vide, donc personne', () {
      final m = FeatureFlagsModel.fromJson({'mlsMessages': false});
      expect(m.mlsMessagesComptes, isEmpty);
      expect(m.mlsMessages, isFalse);
    });

    test('valeur nulle : liste vide, pas une exception', () {
      final m = FeatureFlagsModel.fromJson({'mlsMessagesComptes': null});
      expect(m.mlsMessagesComptes, isEmpty);
    });

    test('valeur mal typée : liste vide', () {
      // Quelqu'un tape une chaîne dans la console au lieu d'un tableau.
      final m = FeatureFlagsModel.fromJson({'mlsMessagesComptes': 'uid-1'});
      expect(m.mlsMessagesComptes, isEmpty);
    });

    test('tableau mixte : seules les chaînes sont retenues', () {
      final m = FeatureFlagsModel.fromJson({
        'mlsMessagesComptes': ['uid-1', 42, null, 'uid-2'],
      });
      expect(m.mlsMessagesComptes, ['uid-1', 'uid-2']);
    });

    test('aller-retour JSON', () {
      final m = FeatureFlagsModel.fromJson({
        'mlsMessagesComptes': ['uid-1'],
      });
      expect(m.toJson()['mlsMessagesComptes'], ['uid-1']);
      expect(m.toEntity().mlsMessagesComptes, ['uid-1']);
      expect(
        FeatureFlagsModel.fromEntity(m.toEntity()).mlsMessagesComptes,
        ['uid-1'],
      );
    });
  });

  group('la décision, telle que le provider la prend', () {
    // Le provider lit l'uid courant via FirebaseAuth, indisponible ici : on
    // vérifie la règle elle-même, sur les mêmes données.
    bool actif(FeatureFlagsEntity d, String? uid) {
      if (d.mlsMessages) return true;
      if (d.mlsMessagesComptes.isEmpty) return false;
      return uid != null && uid.isNotEmpty && d.mlsMessagesComptes.contains(uid);
    }

    test('par défaut, fermé pour tout le monde', () {
      const d = FeatureFlagsEntity();
      expect(actif(d, 'uid-1'), isFalse);
      expect(actif(d, null), isFalse);
    });

    test('ouvert pour le compte nommé, fermé pour les autres', () {
      const d = FeatureFlagsEntity(mlsMessagesComptes: ['uid-test']);
      expect(actif(d, 'uid-test'), isTrue);
      expect(actif(d, 'uid-autre'), isFalse);
      expect(actif(d, null), isFalse);
      expect(actif(d, ''), isFalse);
    });

    test('le drapeau global l\'emporte, liste ou pas', () {
      const d = FeatureFlagsEntity(mlsMessages: true);
      expect(actif(d, 'uid-quelconque'), isTrue);
      expect(actif(d, null), isTrue);
    });
  });
}
