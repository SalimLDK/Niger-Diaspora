import 'package:supabase_flutter/supabase_flutter.dart';

/// Écrit SA ligne `public.users` : `UPDATE`, puis `INSERT` seulement si elle
/// n'existe pas encore.
///
/// **Pourquoi pas un upsert.** PostgREST traduit un upsert en
/// `INSERT … ON CONFLICT (id) DO UPDATE SET col = EXCLUDED.col` pour CHAQUE
/// colonne du corps. Or évaluer `EXCLUDED.col` exige le droit de LIRE `col`.
/// Une fois la fermeture 1.1b appliquée (`supabase/users-colonnes-privees-
/// cible.sql`), `email` et `phone_number` ne sont plus lisibles par le rôle
/// `authenticated` : tout upsert qui les écrit est refusé en 42501 — la
/// connexion et l'enregistrement du profil auraient cassé, version cliente
/// corrigée comprise. Mesuré le 2026-09-21 (banc
/// `tools/rls_tests/users_colonnes_privees_cible.sql`, cas D5/D6) : un
/// `UPDATE` ciblé et un `INSERT` simple, eux, passent — ni l'un ni l'autre ne
/// lit les colonnes qu'il écrit.
///
/// Rend l'identifiant écrit, ou `null` si aucune ligne n'a pu l'être : la RLS
/// ne laisse écrire que sa propre ligne, et refuse le reste en silence
/// (`UPDATE` à 0 ligne).
///
/// [champs] ne doit pas contenir `id` : c'est [id] qui désigne la ligne.
Future<String?> ecrireSaLigneUsers(
  SupabaseClient client,
  String id,
  Map<String, dynamic> champs,
) async {
  assert(!champs.containsKey('id'), '`id` passe par le paramètre [id]');

  Future<bool> mettreAJour() async {
    final lignes =
        await client.from('users').update(champs).eq('id', id).select('id');
    return (lignes as List).isNotEmpty;
  }

  if (await mettreAJour()) return id;

  try {
    final creee = await client
        .from('users')
        .insert({'id': id, ...champs})
        .select('id')
        .maybeSingle();
    return creee?['id'] as String?;
  } on PostgrestException catch (e) {
    // 23505 : la ligne a été créée entre les deux, par un autre appel du même
    // compte — la connexion et le premier enregistrement du profil peuvent
    // partir ensemble. Elle existe maintenant : on la met à jour.
    if (e.code != '23505') rethrow;
    return await mettreAJour() ? id : null;
  }
}
