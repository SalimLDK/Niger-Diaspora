import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/gif_remote_datasource.dart';
import '../../data/datasources/giphy_datasource.dart';
import '../../data/datasources/tenor_datasource.dart';
import '../../data/repositories/gif_repository.dart';
import '../../domain/entities/gif_entity.dart';

/// Ordre des fournisseurs : Tenor d'abord (quotas plus généreux), Giphy en repli.
final gifRepositoryProvider = Provider<GifRepository>((ref) {
  return GifRepository([TenorDataSource(), GiphyDataSource()]);
});

/// True si au moins une clé API de GIFs est renseignée.
final isGifConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(gifRepositoryProvider).isConfigured;
});

/// Requête de recherche courante du picker (vide = tendances).
final gifSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Onglet courant du picker : GIFs ou stickers Tenor/Giphy.
final gifContentTypeProvider =
    StateProvider.autoDispose<GifContentType>((ref) => GifContentType.gif);

/// Résultats du picker pour (requête, type). Vide = tendances.
final gifResultsProvider = FutureProvider.autoDispose
    .family<List<GifEntity>, (String, GifContentType)>((ref, args) async {
  final (query, type) = args;

  // Évite de brûler le quota à chaque frappe : on laisse la frappe se poser.
  // Si l'utilisateur tape encore, ce provider est disposé et on abandonne
  // avant de partir en réseau.
  if (query.trim().isNotEmpty) {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (disposed) return const [];
  }

  return ref.watch(gifRepositoryProvider).search(query, type: type);
});
