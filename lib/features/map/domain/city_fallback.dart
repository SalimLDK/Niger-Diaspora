import '../../embassies/domain/entities/embassy_entity.dart';
import '../../groups/domain/entities/group_entity.dart';

/// Sélection des villes et des lieux du repli « Sans localisation, explorez
/// par ville » (fiche 8c).
///
/// Extrait de l'écran pour être testable : la règle qui exclut les groupes
/// privés est une règle de confidentialité, elle mérite un test qui échoue
/// si quelqu'un la retire par mégarde.
class CityFallback {
  const CityFallback._();

  /// Groupes proposables en découverte. Un groupe privé n'a rien à faire
  /// ici : c'est une porte fermée, et son nom comme son nombre de membres
  /// seraient exposés à quelqu'un qui n'a pas le droit d'y entrer.
  static List<GroupEntity> discoverable(List<GroupEntity> groups) =>
      groups.where((g) => !g.isPrivate).toList();

  /// Villes ayant au moins une ambassade ou un groupe public, triées par
  /// ordre alphabétique. Une ville sans contenu proposable n'apparaît pas :
  /// son chip mènerait à une liste vide.
  static List<String> cities({
    required List<EmbassyEntity> embassies,
    required List<GroupEntity> groups,
  }) {
    return <String>{
      for (final e in embassies)
        if (e.city.trim().isNotEmpty) e.city.trim(),
      for (final g in discoverable(groups))
        if ((g.location ?? '').trim().isNotEmpty) g.location!.trim(),
    }.toList()..sort();
  }

  static List<EmbassyEntity> embassiesIn(
    List<EmbassyEntity> embassies,
    String city,
  ) => embassies.where((e) => e.city.trim() == city).toList();

  static List<GroupEntity> groupsIn(List<GroupEntity> groups, String city) =>
      discoverable(
        groups,
      ).where((g) => (g.location ?? '').trim() == city).toList();
}
