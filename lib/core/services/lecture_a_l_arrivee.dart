import 'package:flutter/foundation.dart';

import 'notification_read_sync.dart';

/// Une notification qui ARRIVE pendant que son écran est déjà ouvert est lue.
///
/// `NotificationReadSync.mark…Opened` ne joue qu'à l'OUVERTURE d'un écran : une
/// notification écrite après reste non lue jusqu'à sa prochaine ouverture, alors
/// que la personne est en train de la regarder — le commentaire qui tombe sur la
/// publication ouverte, l'inscription à l'événement dont on consulte la fiche,
/// la commande reçue pendant qu'on est sur « Mes commandes », l'acceptation de
/// la demande d'ami qu'on attendait sur le profil de l'autre. La cloche la
/// comptait pourtant, sans rien à aller voir.
///
/// La messagerie n'est pas concernée : lire une discussion est le travail du
/// curseur, côté serveur, qui sait ce qui a été VU (`marquer_lus_jusqua`).
///
/// **Ce qui décide de lire, trois conditions à la fois :**
/// 1. l'application est au **premier plan** — une notification qui arrive écran
///    éteint ou application en arrière-plan n'a été vue de personne ; la marquer
///    lue la ferait disparaître sans que quiconque l'ait lue ;
/// 2. l'écran affiché **en haut de la pile** est la destination de cette
///    notification ([NotificationReadSync.designeLEcranAffiche]), pas un écran
///    qui n'est qu'ouvert dessous ;
/// 3. la ligne n'est pas déjà lue.
///
/// **C'est un garde silencieux, donc il se raconte.** Un garde qui refuse rend
/// `false` : c'est un chemin normal, il ne lève rien et n'écrit rien. Le
/// 2026-09-16, un garde de visibilité bâti sur `currentConfiguration.uri`
/// rendait toujours faux sur appareil — le curseur de lecture n'avançait jamais,
/// sans une seule ligne de journal, et trois builds y sont passés. Chaque
/// arrivée laisse donc UNE ligne : le type, la forme de l'écran affiché (sans
/// identifiant) et le verdict avec sa raison. Si les cases « Arrivée » du suivi
/// ne marquent rien, `adb logcat -s flutter | grep LectureALArrivee` dit
/// pourquoi.
///
/// **Un écouteur de canal ne lève jamais.** Une exception dans le rappel d'un
/// canal Realtime n'a personne pour l'attraper : elle remonte comme erreur
/// asynchrone non gérée. Toute la décision est donc sous un `try`, et une
/// panne imprévue est un verdict comme un autre.
///
/// Les dépendances sont injectées : la décision se teste sans réseau, sans
/// routeur et sans cycle de vie. Le branchement au canal temps réel est dans
/// `lecture_a_l_arrivee_provider.dart`.
class LectureALArrivee {
  LectureALArrivee({
    required this.emplacement,
    required this.auPremierPlan,
    this.marquer = NotificationReadSync.markIdRead,
    this.trace,
  });

  /// Le chemin de la page affichée en haut de la pile, `null` si inconnu.
  final String? Function() emplacement;

  /// L'application est-elle au premier plan, visible et active ?
  final bool Function() auPremierPlan;

  /// Écrit la lecture de la ligne dont l'identifiant est donné. Rend `true` si
  /// l'écriture a abouti : sans cela le verdict dirait « lue » d'une ligne que
  /// la base n'a jamais reçue, au moment précis où la trace sert à comprendre.
  final Future<bool> Function(String id) marquer;

  /// Où va la ligne de verdict. `debugPrint` quand elle n'est pas fournie —
  /// `debugPrint` n'est pas une constante, donc pas une valeur par défaut.
  final void Function(String ligne)? trace;

  void _ecrit(String ligne) {
    final sortie = trace;
    if (sortie != null) {
      sortie(ligne);
    } else {
      debugPrint(ligne);
    }
  }

  /// [ligne] est la ligne `notifications` qui vient d'être insérée, telle que le
  /// canal la livre. Rend `true` si elle a été marquée lue.
  Future<bool> surInsertion(Map<String, dynamic> ligne) async {
    try {
      return await _juger(ligne);
    } catch (e) {
      _ecrit('LectureALArrivee: erreur inattendue — ignorée ($e)');
      return false;
    }
  }

  Future<bool> _juger(Map<String, dynamic> ligne) async {
    final id = ligne['id']?.toString();
    final type = ligne['type']?.toString();
    if (id == null || id.isEmpty || type == null || type.isEmpty) {
      _ecrit('LectureALArrivee: ligne incomplète — ignorée');
      return false;
    }
    if (ligne['is_read'] == true) {
      return _dit(type, null, 'ignorée : déjà lue');
    }

    if (!auPremierPlan()) {
      return _dit(type, null, 'ignorée : application pas au premier plan');
    }
    final ici = emplacement();
    if (ici == null) {
      return _dit(type, null, 'ignorée : écran affiché inconnu');
    }

    final brut = ligne['data'];
    final data = brut is Map ? Map<String, dynamic>.from(brut) : <String, dynamic>{};
    if (!NotificationReadSync.designeLEcranAffiche(ici, type: type, data: data)) {
      return _dit(type, ici, 'ignorée : ce n\'est pas la destination de l\'écran');
    }

    final ecrit = await marquer(id);
    return ecrit
        ? _dit(type, ici, 'marquée lue', vrai: true)
        : _dit(type, ici, 'ÉCHEC de l\'écriture (voir NotificationReadSync)');
  }

  bool _dit(String type, String? ici, String verdict, {bool vrai = false}) {
    final ou = ici == null ? '' : ' sur ${_forme(ici)}';
    _ecrit('LectureALArrivee: $type$ou — $verdict');
    return vrai;
  }

  /// La forme d'un chemin, sans identifiant : `/feed/abc` → `/feed/…`. Un
  /// journal d'appareil n'a pas à porter l'identifiant d'une publication, d'un
  /// événement ou d'une personne.
  static String _forme(String chemin) {
    final segments = chemin.split('?').first.split('/').where((s) => s.isNotEmpty);
    if (segments.isEmpty) return '/';
    return segments.length == 1 ? '/${segments.first}' : '/${segments.first}/…';
  }
}
