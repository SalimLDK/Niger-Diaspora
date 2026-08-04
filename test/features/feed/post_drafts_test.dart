import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';

/// Brouillons de publication (§5a/§5b) : la liste locale et la migration
/// depuis l'ancien brouillon unique.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesService> boot(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final service = PreferencesService.instance;
    await service.initialize();
    return service;
  }

  test('enregistre puis relit un brouillon', () async {
    final prefs = await boot({'prefs_version': 2});

    await prefs.savePostDraft('abc', 'Compte rendu de la réunion');

    expect(prefs.postDrafts, hasLength(1));
    expect(prefs.postDrafts.first['id'], 'abc');
    expect(prefs.postDrafts.first['text'], 'Compte rendu de la réunion');
  });

  test('deux brouillons coexistent, le plus récent en tête', () async {
    final prefs = await boot({'prefs_version': 2});

    await prefs.savePostDraft('un', 'Premier');
    await prefs.savePostDraft('deux', 'Second');

    expect(prefs.postDrafts.map((e) => e['id']), ['deux', 'un']);
  });

  test('un texte vide supprime le brouillon', () async {
    final prefs = await boot({'prefs_version': 2});

    await prefs.savePostDraft('abc', 'Un texte');
    await prefs.savePostDraft('abc', '   ');

    expect(prefs.postDrafts, isEmpty);
  });

  test('supprime un brouillon par son id sans toucher aux autres', () async {
    final prefs = await boot({'prefs_version': 2});

    await prefs.savePostDraft('un', 'Premier');
    await prefs.savePostDraft('deux', 'Second');
    await prefs.deletePostDraft('un');

    expect(prefs.postDrafts.map((e) => e['id']), ['deux']);
  });

  test('migre l\'ancien brouillon unique vers la liste', () async {
    final prefs = await boot({
      'prefs_version': 1,
      'flutter.post_draft': 'Texte écrit avant la migration',
    });

    expect(prefs.postDrafts, hasLength(1));
    expect(prefs.postDrafts.first['text'], 'Texte écrit avant la migration');
  });

  test('un contenu illisible ne fait pas planter la lecture', () async {
    final prefs = await boot({
      'prefs_version': 2,
      'flutter.post_drafts': 'ceci n\'est pas du JSON',
    });

    expect(prefs.postDrafts, isEmpty);
  });

  test('la liste est plafonnée et garde les plus récents', () async {
    final entries = List.generate(
      25,
      (i) => {'id': 'id$i', 'text': 'Texte $i', 'updatedAt': i},
    );
    final prefs = await boot({
      'prefs_version': 2,
      'flutter.post_drafts': jsonEncode(entries),
    });

    await prefs.savePostDraft('neuf', 'Le plus récent');

    expect(prefs.postDrafts.length, lessThanOrEqualTo(20));
    expect(prefs.postDrafts.first['id'], 'neuf');
  });
}
