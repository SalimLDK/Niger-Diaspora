import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/gif_proxy_datasource.dart';
import '../../data/datasources/gif_remote_datasource.dart';
import '../../data/repositories/gif_repository.dart';
import '../../domain/entities/gif_entity.dart';

/// Le choix du fournisseur (Tenor, Giphy) appartient à `gif-proxy` : voir
/// [GifProxyDataSource].
final gifRepositoryProvider = Provider<GifRepository>((ref) {
  return GifRepository(GifProxyDataSource());
});

/// Requête de recherche courante du picker (vide = tendances).
final gifSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Onglet courant du picker : GIFs ou stickers animés.
final gifContentTypeProvider = StateProvider.autoDispose<GifContentType>(
  (ref) => GifContentType.gif,
);

/// Laisse la frappe se poser avant de partir en réseau.
const _antiRebond = Duration(milliseconds: 350);

/// Survie d'un résultat après la fermeture du picker. Les tendances changent
/// lentement et sont rouvertes sans cesse ; une recherche est plus volatile et
/// bien plus nombreuse — la garder longtemps encombrerait la mémoire pour rien.
const _survieTendances = Duration(minutes: 15);
const _survieRecherche = Duration(minutes: 3);

/// Résultats du picker pour (requête, type). Vide = tendances.
final gifResultsProvider = FutureProvider.autoDispose
    .family<List<GifEntity>, (String, GifContentType)>((ref, args) async {
      final (query, type) = args;
      final estRecherche = query.trim().isNotEmpty;

      // `ref` n'est plus utilisable après disposition : tout ce qui suit un
      // `await` doit d'abord vérifier ce drapeau.
      var dispose = false;
      ref.onDispose(() => dispose = true);

      // Évite de brûler le quota à chaque frappe. Si l'utilisateur tape
      // encore, ce provider est disposé et on abandonne avant le réseau.
      if (estRecherche) {
        await Future<void>.delayed(_antiRebond);
        if (dispose) return const [];
      }

      final gifs = await ref
          .watch(gifRepositoryProvider)
          .search(query, type: type);

      // Le picker est démonté à chaque fermeture du panneau : sans ce cache,
      // le rouvrir relance un appel réseau pour réafficher la même grille.
      // Seul un succès est gardé — une erreur doit rester retentable aussitôt.
      if (!dispose) {
        final lien = ref.keepAlive();
        final minuteur = Timer(
          estRecherche ? _survieRecherche : _survieTendances,
          lien.close,
        );
        ref.onDispose(minuteur.cancel);
      }

      return gifs;
    });
