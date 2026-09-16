import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../domain/entities/message_entity.dart';

/// Ce qui est **à l'écran**, et le moment où la vue d'une discussion est posée.
///
/// `VisibilityDetector` ne rapporte que les **changements** de visibilité, et
/// les regroupe toutes les 500 ms. Deux questions lui échappent donc :
///
/// - **qu'est-ce qui est affiché maintenant ?** Une bulle qui reste à l'écran
///   ne se signale plus jamais. Ce relevé garde la dernière réponse de chacune ;
/// - **la vue est-elle posée ?** À l'ouverture, la liste s'affiche en bas puis
///   saute au premier non-lu. Ce qui passe à l'écran avant le saut n'a pas été
///   vu. [poser] attend l'image qui applique le saut, puis vide les rapports
///   en attente avant de rendre la main.
///
/// Éprouvé contre un vrai `ListView` par `releve_a_l_ecran_test.dart` — y
/// compris le cas où les rapports d'avant le saut sont déjà partis.
class ReleveALEcran {
  ReleveALEcran({required this.seuil});

  /// Fraction d'une bulle à partir de laquelle elle compte comme affichée.
  final double seuil;

  final Map<String, MessageEntity> _visibles = {};
  bool _posee = false;
  bool _enCours = false;

  /// Les bulles affichées à au moins [seuil], au dernier rapport.
  Iterable<MessageEntity> get visibles => _visibles.values;

  /// La vue est posée : ce qui est à l'écran l'est pour de bon.
  bool get vuePosee => _posee;

  /// Enregistre un rapport de visibilité.
  void noter(MessageEntity message, double fraction) {
    if (fraction < seuil) {
      _visibles.remove(message.id);
    } else {
      _visibles[message.id] = message;
    }
  }

  /// Déclare la vue posée, et appelle [lire] **une seule fois**, à la fin de
  /// l'image suivante, une fois les rapports en attente vidés.
  ///
  /// À appeler juste après le placement — un `jumpTo` compris : le saut ne
  /// s'applique qu'à l'image suivante, et c'est elle qu'on attend. Les appels
  /// suivants ne font rien.
  ///
  /// [monte] : l'écran est-il toujours là quand l'image arrive ?
  void poser(VoidCallback lire, {required bool Function() monte}) {
    if (_posee || _enCours) return;
    _enCours = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!monte()) return;
      // Avant de lever le verrou : les rapports vidés ici ne font que noter,
      // et la lecture part une seule fois, juste en dessous — une écriture
      // pour tout ce qui est à l'écran.
      VisibilityDetectorController.instance.notifyNow();
      _posee = true;
      lire();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
