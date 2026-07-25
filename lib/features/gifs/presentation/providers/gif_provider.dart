import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/gif_remote_datasource.dart';
import '../../data/datasources/giphy_datasource.dart';
import '../../data/datasources/tenor_datasource.dart';
import '../../data/repositories/gif_repository.dart';
import '../../domain/entities/gif_entity.dart';

/// Ordre des fournisseurs : Tenor d'abord (quotas plus g├®n├®reux), Giphy en repli.
final gifRepositoryProvider = Provider<GifRepository>((ref) {
  return GifRepository([TenorDataSource(), GiphyDataSource()]);
});

/// True si au moins une cl├® API de GIFs est renseign├®e.
final isGifConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(gifRepositoryProvider).isConfigured;
});

/// Requ├¬te de recherche courante du picker (vide = tendances).
final gifSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Onglet courant du picker : GIFs ou stickers Tenor/Giphy.
final gifContentTypeProvider =
    StateProvider.autoDispose<GifContentType>((ref) => GifContentType.gif);

/// R├®sultats du picker pour (requ├¬te, type). Vide = tendances.
final gifResultsProvider = FutureProvider.autoDispose
    .family<List<GifEntity>, (String, GifContentType)>((ref, args) async {
  final (query, type) = args;

  // ├ëvite de br├╗ler le quota ├á chaque frappe : on laisse la frappe se poser.
  // Si l'utilisateur tape encore, ce provider est dispos├® et on abandonne
  // avant de partir en r├®seau.
  if (query.trim().isNotEmpty) {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (disposed) return const [];
  }

  return ref.watch(gifRepositoryProvider).search(query, type: type);
});
