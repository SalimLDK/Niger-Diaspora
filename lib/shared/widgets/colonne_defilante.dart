import 'package:flutter/material.dart';

/// Colonne qui défile, pour le corps d'un `Form`.
///
/// Remplace `ListView(children: …)` sous un `Form`. Un `ListView` ne monte
/// que ce qui tient dans la fenêtre plus `cacheExtent` (250 px) : un
/// `TextFormField` défilé plus loin est démonté, se désinscrit du `Form`, et
/// `FormState.validate()` ne le regarde plus — son `TextEditingController`
/// garde pourtant le texte, vide, qui part à la base. C'est ainsi qu'une
/// entreprise sans description a été envoyée onze fois le 2026-10-11 par deux
/// usagers, alors que le validateur existait depuis trois mois (contrainte
/// `businesses_description_non_vide`, fiche Crashlytics
/// « PostgrestBuilder._parseResponse »). Seul un champ qui a le focus
/// survit au défilement (`EditableText` se garde en vie tant qu'il l'a) :
/// le nom, tapé en premier, restait ; la description, jamais touchée,
/// disparaissait.
///
/// Ici tous les enfants restent montés : `validate()` les voit tous, et le
/// champ en erreur porte son message même hors écran — l'usager le trouve en
/// remontant. Les enfants reçoivent la même largeur serrée que sous
/// `ListView` (`CrossAxisAlignment.stretch`) : un bouton garde toute la
/// largeur, un `Center` reste centré.
///
/// Même signature que le `ListView` remplacé, pour que le remplacement tienne
/// en une ligne. Pas pour une longue liste de données : rien n'est paresseux.
/// Vérifié par `test/shared/colonne_defilante_test.dart`, qui garde aussi un
/// témoin du défaut sous `ListView`.
class ColonneDefilante extends StatelessWidget {
  const ColonneDefilante({
    super.key,
    this.padding,
    this.controller,
    this.physics,
    required this.children,
  });

  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      controller: controller,
      physics: physics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
