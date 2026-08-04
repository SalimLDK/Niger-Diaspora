import 'package:intl/intl.dart';

/// Les modèles normalisent déjà leurs dates en local à la désérialisation
/// (voir `core/utils/date_parsing.dart`). Le `toLocal()` répété ici est un
/// filet : `DateFormat` imprime les composantes brutes, donc une date restée
/// en UTC s'afficherait décalée du fuseau sans la moindre erreur visible.
///
/// À l'inverse, `difference`, `isAfter`, `isBefore` et `compareTo` travaillent
/// sur l'epoch : mélanger une date locale et une date UTC y est sans effet, et
/// les normaliser n'apporterait rien. Seuls les chemins qui lisent des
/// **composantes** (`year`/`month`/`day`/`hour`, `DateFormat`) sont concernés.
class DateFormatter {
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date.toLocal());
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal());
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    // Pas de `toLocal()` : `difference` est calculée sur l'epoch.
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'A l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a $weeks sem';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months mois';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a $years an${years > 1 ? 's' : ''}';
    }
  }

  static String formatMessageDate(DateTime date) {
    // `local` est indispensable ici : le regroupement compare des composantes
    // de calendrier. Sur une date restée en UTC, un message envoyé à 22:30 à
    // Toronto tombait déjà au lendemain et perdait son « Aujourd'hui ».
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(local.year, local.month, local.day);

    if (messageDate == today) {
      return formatTime(local);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Hier';
    } else if (now.difference(local).inDays < 7) {
      return DateFormat('EEEE', 'fr_FR').format(local);
    } else {
      return formatDate(local);
    }
  }

  /// Ancienneté compacte des cartes « Enregistrés » (fiche 5c) : « 12 min »,
  /// « 3 j », « 2 sem. » — sans le « Il y a » de [timeAgo], la maquette
  /// posant déjà un « · » devant.
  ///
  /// `toLocal()` pour la même raison que [formatPostMeta].
  static String timeAgoShort(DateTime date) {
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} sem.';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mois';
    final years = (diff.inDays / 365).floor();
    return '$years an${years > 1 ? 's' : ''}';
  }

  /// Méta d'une publication à soi, format « Hier · 18:40 » (fiche 5b).
  /// Jour du jour / de la veille nommé, jour de la semaine en toutes lettres
  /// dans les 7 jours, date courte au-delà.
  ///
  /// `toLocal()` est indispensable : `PostModel.parseDate` fait un
  /// `DateTime.parse` sur un ISO en `Z`, donc [date] arrive en **UTC** et
  /// `DateFormat` l'imprimerait tel quel (4 h d'écart observées en EDT).
  static String formatPostMeta(DateTime date) {
    final local = date.toLocal();
    return '${_postDayLabel(local)} · ${formatTime(local)}';
  }

  static String _postDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);

    if (day == today) return "Aujourd'hui";
    if (day == today.subtract(const Duration(days: 1))) return 'Hier';
    if (today.difference(day).inDays < 7) {
      final weekday = DateFormat('EEEE', 'fr_FR').format(date);
      return weekday.isEmpty
          ? weekday
          : weekday[0].toUpperCase() + weekday.substring(1);
    }
    return DateFormat('d MMMM', 'fr_FR').format(date);
  }
}
