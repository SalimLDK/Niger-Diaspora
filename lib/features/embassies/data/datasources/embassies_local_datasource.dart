import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/date_parsing.dart';
import '../models/embassy_model.dart';

/// Ancienne clé : une liste JSON nue, sans date d'enregistrement.
const String cachedEmbassies = 'CACHED_EMBASSIES';

/// Clé courante : un objet `{savedAt, embassies}`.
const String cachedEmbassiesEnvelope = 'CACHED_EMBASSIES_V2';

/// Une copie locale de l'annuaire, servie quand Supabase est hors d'atteinte.
///
/// L'annuaire est la donnée la plus utile hors ligne de toute l'app : un
/// Nigérien qui cherche le numéro de son consulat est souvent précisément
/// celui qui n'a pas de réseau. La copie est donc écrite à chaque lecture
/// distante réussie, et relue sans condition de fraîcheur — une coordonnée de
/// la semaine dernière vaut mieux qu'un écran vide.
///
/// [cachedAt] permet à l'interface de dire *depuis quand* la copie date, plutôt
/// que de la présenter comme un état courant.
class EmbassiesLocalDataSource {
  Future<void> cacheEmbassies(List<EmbassyModel> embassies) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final payload = {
      'savedAt': toIsoUtc(DateTime.now()),
      'embassies': embassies.map((e) => e.toJson()).toList(),
    };

    try {
      await sharedPreferences.setString(
        cachedEmbassiesEnvelope,
        jsonEncode(payload),
      );
    } catch (_) {
      // Écrire le cache ne doit jamais faire échouer la lecture distante qui
      // vient de réussir : l'appelant a déjà ses données en main.
      return;
    }
  }

  Future<List<EmbassyModel>> getLastEmbassies() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    final envelope = sharedPreferences.getString(cachedEmbassiesEnvelope);
    if (envelope != null) {
      final list = _decodeEnvelope(envelope);
      if (list != null) return list;
    }

    // Repli sur l'ancien format, pour ne pas vider le cache des installations
    // qui tournent déjà.
    final legacy = sharedPreferences.getString(cachedEmbassies);
    if (legacy != null) {
      final list = _decodeList(legacy);
      if (list != null) return list;
    }

    throw CacheException('No cached embassies found');
  }

  /// Date d'écriture de la copie locale, ou `null` s'il n'y en a pas.
  Future<DateTime?> cachedAt() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final envelope = sharedPreferences.getString(cachedEmbassiesEnvelope);
    if (envelope == null) return null;

    try {
      final decoded = jsonDecode(envelope);
      if (decoded is Map<String, dynamic>) {
        return tryParseLocalDate(decoded['savedAt']);
      }
    } catch (_) {
      // Cache illisible : traité comme absent.
    }
    return null;
  }

  Future<void> clear() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.remove(cachedEmbassiesEnvelope);
    await sharedPreferences.remove(cachedEmbassies);
  }

  List<EmbassyModel>? _decodeEnvelope(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final list = decoded['embassies'];
      if (list is! List) return null;
      return _fromJsonList(list);
    } catch (_) {
      return null;
    }
  }

  List<EmbassyModel>? _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return _fromJsonList(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Une fiche illisible (champ ajouté depuis, cache d'une version antérieure)
  /// est écartée seule : elle ne doit pas emporter les 31 autres.
  List<EmbassyModel> _fromJsonList(List<dynamic> raw) {
    final out = <EmbassyModel>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(EmbassyModel.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        continue;
      }
    }
    return out;
  }
}
