import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_auth_bridge.dart';

/// Le repère de lecture d'une conversation, tel que **le serveur** le désigne.
///
/// Le séparateur « N messages non lus » en est la représentation :
///
/// - [curseurId] : le message d'autrui le plus récent que j'ai lu ;
/// - [premierNonLuId] : le plus ancien non-lu **après** le curseur — c'est lui
///   que le séparateur désigne, qu'il soit chargé ou non ;
/// - [nonLus] : combien de non-lus après le curseur, donc sous le séparateur ;
/// - [dernierNonLuId] : le plus récent d'entre eux. Quand le curseur l'atteint,
///   tout ce qui était non lu au relevé est lu — c'est ce qui fait partir le
///   séparateur (étape B). `null` tant que la migration `20260917002300`
///   n'est pas appliquée : la colonne n'existe pas encore.
///
/// Les trois viennent d'**une seule** lecture, sur les deux magasins
/// (`messages` en clair et `mls_messages`). Côté MLS, trois requêtes
/// successives pouvaient décrire trois états différents : un message arrivé
/// entre deux lectures décalait le compte.
@immutable
class RepereDeLecture {
  const RepereDeLecture({
    this.curseurId,
    this.curseurA,
    this.premierNonLuId,
    this.premierNonLuA,
    this.nonLus = 0,
    this.dernierNonLuId,
    this.dernierNonLuA,
  });

  final String? curseurId;
  final DateTime? curseurA;
  final String? premierNonLuId;
  final DateTime? premierNonLuA;
  final int nonLus;
  final String? dernierNonLuId;
  final DateTime? dernierNonLuA;

  /// Y a-t-il un séparateur à poser ?
  ///
  /// Les deux conditions ensemble : un compte sans message désigné ne dit pas
  /// **où**, et un message désigné avec un compte nul contredirait la
  /// fonction qui les a rendus dans le même instantané.
  bool get aUnSeparateur => premierNonLuId != null && nonLus > 0;

  /// Jusqu'où le fil affiché doit aller pour contenir tous les non-lus : la
  /// date du plus récent, à défaut celle du premier. `null` s'il n'y a rien à
  /// lire.
  ///
  /// Sert quand la liste des discussions n'a rien annoncé — ouverture par lien
  /// profond ou par notification, liste pas encore chargée. Sans échéance, le
  /// fil tiré du cache passait pour complet alors que les nouveaux messages
  /// chiffrés n'y sont jamais : l'écran se posait en bas pour de bon, et le
  /// curseur marquait lus des messages jamais affichés (Pixel, 2026-09-22 :
  /// 13 non-lus lus à la même milliseconde, 5 à l'écran).
  DateTime? get echeanceDuFil =>
      aUnSeparateur ? (dernierNonLuA ?? premierNonLuA) : null;

  /// Lit la réponse de `repere_de_lecture`.
  ///
  /// PostgREST rend une fonction `RETURNS TABLE` sous forme de **liste**, même
  /// pour une ligne. Une carte seule est acceptée aussi. Toute autre forme est
  /// une erreur, pas un repère vide : « rien à lire » et « réponse
  /// illisible » ne doivent pas se confondre — c'est ce qui faisait
  /// disparaître le séparateur sans un mot dans le journal.
  static RepereDeLecture depuisReponse(Object? reponse) {
    final Object? ligne = switch (reponse) {
      final List<dynamic> liste when liste.length == 1 => liste.first,
      final Map<dynamic, dynamic> carte => carte,
      _ => null,
    };
    if (ligne is! Map) {
      throw FormatException('repere_de_lecture : réponse inattendue', reponse);
    }
    DateTime? date(Object? brut) =>
        brut is String ? DateTime.tryParse(brut) : null;
    String? texte(Object? brut) =>
        brut is String && brut.isNotEmpty ? brut : null;
    final nombre = ligne['non_lus'];
    return RepereDeLecture(
      curseurId: texte(ligne['curseur_id']),
      curseurA: date(ligne['curseur_a']),
      premierNonLuId: texte(ligne['premier_non_lu_id']),
      premierNonLuA: date(ligne['premier_non_lu_a']),
      nonLus: nombre is num ? nombre.toInt() : 0,
      dernierNonLuId: texte(ligne['dernier_non_lu_id']),
      dernierNonLuA: date(ligne['dernier_non_lu_a']),
    );
  }
}

/// La fonction serveur n'existe pas encore : la migration
/// `20260916224700_lecture_par_curseur_en_clair` n'est pas appliquée.
///
/// Distincte des autres échecs parce que l'appelant n'y répond pas pareil : ici
/// il reprend l'ancien chemin, qui marchait ; sur un refus ou une panne réseau,
/// il ne marque rien plutôt que de marquer trop.
class LectureServeurAbsente implements Exception {
  const LectureServeurAbsente(this.fonction);
  final String fonction;

  @override
  String toString() => 'LectureServeurAbsente($fonction)';
}

/// `PGRST202` : PostgREST ne trouve pas la fonction dans son cache de schéma.
/// `42883` : Postgres ne la trouve pas (appel direct, cache rafraîchi).
bool estFonctionAbsente(PostgrestException e) =>
    e.code == 'PGRST202' || e.code == '42883';

/// L'accès aux deux RPC de lecture par curseur.
///
/// Les conversations en clair n'avaient que `mark_messages_as_read`, qui marque
/// **toute** la conversation : l'écran l'appelait au premier coup d'œil, et ce
/// qui restait sous le pli partait « Lu » chez l'expéditeur.
class LectureServeur {
  LectureServeur({
    SupabaseClient? client,
    Future<bool> Function()? ensureAuth,
  })  : _clientOptionnel = client,
        _ensureAuth =
            ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated;

  final SupabaseClient? _clientOptionnel;
  final Future<bool> Function() _ensureAuth;

  SupabaseClient get _client => _clientOptionnel ?? Supabase.instance.client;

  /// Sans session, l'appel part en `anon`, à qui ces fonctions sont
  /// refusées : l'échec serait un 42501 qui ne dit pas sa vraie cause.
  Future<void> _auth() async {
    if (!await _ensureAuth()) throw StateError('Session non établie');
  }

  Future<T> _appeler<T>(
    String fonction,
    Map<String, dynamic> params,
    T Function(Object?) lire,
  ) async {
    await _auth();
    try {
      return lire(await _client.rpc<dynamic>(fonction, params: params));
    } on PostgrestException catch (e) {
      if (estFonctionAbsente(e)) throw LectureServeurAbsente(fonction);
      rethrow;
    }
  }

  /// Le repère de lecture de [conversationId]. Lève en cas d'échec — y
  /// compris [LectureServeurAbsente] — : un repère vide serait pris pour
  /// « tout est lu ».
  Future<RepereDeLecture> relever(String conversationId) => _appeler(
        'repere_de_lecture',
        {'p_conversation_id': conversationId},
        RepereDeLecture.depuisReponse,
      );

  /// Marque lus les messages en clair d'autrui **jusqu'à** [messageId]
  /// inclus, et pas au-delà. Rend le nombre de messages en clair qui me
  /// restent à lire.
  ///
  /// [messageId] peut désigner un message MLS : dans une conversation
  /// basculée, les messages en clair qui le précèdent partent avec lui.
  Future<int> avancerJusqua(String conversationId, String messageId) =>
      _appeler(
        'marquer_lus_jusqua',
        {'p_conversation_id': conversationId, 'p_message_id': messageId},
        (reponse) => reponse is num
            ? reponse.toInt()
            : throw FormatException(
                'marquer_lus_jusqua : réponse inattendue',
                reponse,
              ),
      );
}
