import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/embassy_model.dart';

/// L'annuaire des postes diplomatiques, lu depuis Supabase.
///
/// Remplace la lecture de la collection Firestore `embassies`, qui n'a jamais
/// contenu la moindre fiche. Les messages aux ambassades, les employés et les
/// demandes administratives restent sur Firestore : seul l'annuaire (la liste
/// et le détail) est porté ici.
///
/// La table est en lecture publique — un usager doit pouvoir trouver son
/// consulat avant d'ouvrir un compte — mais toute écriture passe par
/// `is_super_admin()` côté RLS, donc par une session authentifiée.
abstract class EmbassiesDataSource {
  Future<List<EmbassyModel>> getEmbassies();
  Future<EmbassyModel?> getEmbassyById(String id);
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  });
  Future<String> createEmbassy(EmbassyModel embassy);
}

/// Colonnes lues par l'annuaire.
///
/// Énumérées plutôt que `*` : une colonne ajoutée plus tard par une migration
/// ne changera pas silencieusement la charge utile de chaque ouverture d'écran.
const String _embassyColumns = '''
  id, name, type, country, city, address,
  phone, additional_phones, fax, email, website,
  latitude, longitude, image_url,
  services, upcoming_services, opening_hours, jurisdiction_countries,
  is_verified, is_suspended, verified_at, rejection_reason,
  is_temporarily_closed, closure_message, reopen_date,
  source, source_url, source_checked_at, data_notes, position_uncertain
''';

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

Map<String, String> _stringMap(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }
  return const {};
}

/// Traduit une ligne Postgres (snake_case) vers les clés du modèle (camelCase).
Map<String, dynamic> _mapEmbassy(Map<String, dynamic> row) {
  return {
    'id': row['id']?.toString() ?? '',
    'name': row['name'] ?? '',
    'country': row['country'] ?? '',
    'city': row['city'] ?? '',
    // `address` est NOT NULL côté modèle mais nullable en base : deux postes
    // (La Havane, Doha) n'en publient aucune.
    'address': row['address'] ?? '',
    'phone': row['phone'],
    'additionalPhones': _stringList(row['additional_phones']),
    'fax': row['fax'],
    'email': row['email'],
    'website': row['website'],
    'latitude': (row['latitude'] as num?)?.toDouble(),
    'longitude': (row['longitude'] as num?)?.toDouble(),
    'imageUrl': row['image_url'],
    'type': row['type'] ?? 'embassy',
    'services': _stringList(row['services']),
    'upcomingServices': _stringList(row['upcoming_services']),
    'openingHours': _stringMap(row['opening_hours']),
    'jurisdictionCountries': _stringList(row['jurisdiction_countries']),
    'isVerified': row['is_verified'] ?? false,
    'isSuspended': row['is_suspended'] ?? false,
    'verifiedAt': row['verified_at'],
    'rejectionReason': row['rejection_reason'],
    'isTemporarilyClosed': row['is_temporarily_closed'] ?? false,
    'closureMessage': row['closure_message'],
    'reopenDate': row['reopen_date'],
    'source': row['source'],
    'sourceUrl': row['source_url'],
    'sourceCheckedAt': row['source_checked_at'],
    'dataNotes': row['data_notes'],
    'isPositionUncertain': row['position_uncertain'] ?? false,
    // Activités et actualités ne sont pas portées sur Supabase : elles restent
    // vides ici plutôt que d'être inventées.
    'activities': const <Map<String, dynamic>>[],
    'news': const <Map<String, dynamic>>[],
  };
}

/// Traduit un modèle vers une ligne Postgres, pour les écritures d'admin.
Map<String, dynamic> _toRow(EmbassyModel e) {
  return {
    'name': e.name,
    'type': e.type,
    'country': e.country,
    'city': e.city,
    'address': e.address.isEmpty ? null : e.address,
    'phone': e.phone,
    'additional_phones': e.additionalPhones,
    'fax': e.fax,
    'email': e.email,
    'website': e.website,
    'latitude': e.latitude,
    'longitude': e.longitude,
    'image_url': e.imageUrl,
    'services': e.services,
    'upcoming_services': e.upcomingServices,
    'opening_hours': e.openingHours,
    'jurisdiction_countries': e.jurisdictionCountries,
    'is_verified': e.isVerified,
    'is_suspended': e.isSuspended,
    'is_temporarily_closed': e.isTemporarilyClosed,
    'closure_message': e.closureMessage,
    'source': e.source,
    'source_url': e.sourceUrl,
    'data_notes': e.dataNotes,
    'position_uncertain': e.isPositionUncertain,
  };
}

class EmbassiesSupabaseDataSource implements EmbassiesDataSource {
  EmbassiesSupabaseDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<EmbassyModel>> getEmbassies() async {
    try {
      final rows = await _client
          .from('embassies')
          .select(_embassyColumns)
          .order('country')
          .order('city');

      return rows
          .map((row) => EmbassyModel.fromJson(_mapEmbassy(row)))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException('Lecture de l\'annuaire refusée : ${e.message}');
    } catch (e) {
      throw ServerException('Lecture de l\'annuaire impossible : $e');
    }
  }

  @override
  Future<EmbassyModel?> getEmbassyById(String id) async {
    try {
      final row = await _client
          .from('embassies')
          .select(_embassyColumns)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return EmbassyModel.fromJson(_mapEmbassy(row));
    } on PostgrestException catch (e) {
      throw ServerException('Fiche introuvable : ${e.message}');
    } catch (e) {
      throw ServerException('Lecture de la fiche impossible : $e');
    }
  }

  @override
  Future<void> updateEmbassyStatus(
    String id, {
    bool? isVerified,
    bool? isSuspended,
    String? rejectionReason,
  }) async {
    // Sans session valide, le RLS refuse en anon et l'UPDATE ne touche aucune
    // ligne — sans lever d'erreur côté client.
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase indisponible.');
    }

    final patch = <String, dynamic>{
      if (isVerified != null) 'is_verified': isVerified,
      if (isVerified == true) 'verified_at': DateTime.now().toUtc().toIso8601String(),
      if (isSuspended != null) 'is_suspended': isSuspended,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
    };
    if (patch.isEmpty) return;

    try {
      // `select()` derrière l'UPDATE : le RLS renvoie une liste vide plutôt
      // qu'une erreur quand la ligne est refusée. Sans cette vérification,
      // l'écran affiche « vérifiée » alors que rien n'a bougé en base.
      final updated = await _client
          .from('embassies')
          .update(patch)
          .eq('id', id)
          .select('id');

      if (updated.isEmpty) {
        throw ServerException(
          'Mise à jour refusée : réservée au super-administrateur.',
        );
      }
    } on PostgrestException catch (e) {
      throw ServerException('Mise à jour impossible : ${e.message}');
    }
  }

  @override
  Future<String> createEmbassy(EmbassyModel embassy) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase indisponible.');
    }

    try {
      final inserted = await _client
          .from('embassies')
          .insert(_toRow(embassy))
          .select('id')
          .single();

      return inserted['id'].toString();
    } on PostgrestException catch (e) {
      throw ServerException('Création impossible : ${e.message}');
    }
  }
}
