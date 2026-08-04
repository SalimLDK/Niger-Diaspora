import 'package:json_annotation/json_annotation.dart';

/// Normalisation des dates **à la désérialisation**.
///
/// `DateTime.parse` sur une chaîne ISO 8601 terminée par `Z` (ou portant un
/// décalage `+hh:mm`) renvoie un `DateTime` dont `isUtc == true`. `DateFormat`
/// imprime ensuite les composantes telles quelles : une publication créée à
/// 02:01 à Toronto (UTC-4) s'affichait « 06:01 ». Le même mélange fausse
/// `now.difference(date)`, donc tous les « il y a X min » et les
/// regroupements « Hier » / jour de la semaine.
///
/// La règle du dépôt : **tout `DateTime` qui sort d'un modèle est local**.
/// `toLocal()` est un no-op quand la chaîne ne portait pas de fuseau (le
/// résultat est déjà local) et quand la date est déjà locale, donc il est sûr
/// de l'appliquer partout.
///
/// Symétriquement, tout ré-encodage vers le serveur doit passer par
/// [toIsoUtc] : `toIso8601String()` sur un `DateTime` local produit une chaîne
/// **sans suffixe**, que Postgres/Firestore relisent comme de l'UTC.

/// Convertit une valeur JSON en `DateTime` local, ou `null` si elle n'est pas
/// interprétable.
///
/// Accepte les chaînes ISO 8601, les millisecondes epoch (`int`) et les
/// `DateTime` déjà construits (cas des `Timestamp` Firestore déjà convertis en
/// amont).
DateTime? tryParseLocalDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  }
  if (value is String) {
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

/// Variante non nullable : renvoie [fallback] (par défaut `DateTime.now()`)
/// quand la valeur est absente ou illisible.
DateTime parseLocalDate(Object? value, {DateTime? fallback}) {
  return tryParseLocalDate(value) ?? fallback ?? DateTime.now();
}

/// Ré-encodage sûr vers le serveur : toujours en UTC explicite (`…Z`).
///
/// Sans `toUtc()`, un `DateTime` local sérialise sans suffixe de fuseau et se
/// fait relire comme de l'UTC côté serveur — le décalage est alors écrit en
/// base au lieu d'être seulement affiché.
String toIsoUtc(DateTime date) => date.toUtc().toIso8601String();

/// Variante nullable, pour les champs optionnels des `toJson`.
String? toIsoUtcOrNull(DateTime? date) => date == null ? null : toIsoUtc(date);

/// Convertisseur `json_serializable` appliquant les deux règles ci-dessus aux
/// modèles générés (`*.g.dart`), qu'on ne peut pas corriger à la main.
///
/// Le type JSON est `Object?` et non `String` à dessein : les `fromFirestore`
/// du dépôt convertissent les `Timestamp` en `DateTime` **avant** d'appeler
/// `fromJson`, si bien que le champ arrive tantôt en chaîne ISO, tantôt en
/// `DateTime`. Le `DateTime.parse(json[...] as String)` généré par défaut
/// lançait sur ce second cas.
class LocalDateTimeConverter implements JsonConverter<DateTime, Object?> {
  const LocalDateTimeConverter();

  @override
  DateTime fromJson(Object? json) => parseLocalDate(json);

  @override
  Object? toJson(DateTime object) => toIsoUtc(object);
}

/// Même contrat que [LocalDateTimeConverter] pour les champs optionnels.
class LocalDateTimeNullableConverter
    implements JsonConverter<DateTime?, Object?> {
  const LocalDateTimeNullableConverter();

  @override
  DateTime? fromJson(Object? json) => tryParseLocalDate(json);

  @override
  Object? toJson(DateTime? object) => toIsoUtcOrNull(object);
}
