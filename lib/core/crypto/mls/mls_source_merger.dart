import '../../../features/messages/domain/entities/message_entity.dart';
import 'mls_message_mapper.dart';

/// Fusionne l'historique legacy et le fil MLS d'une même conversation
/// (plan MLS § 2.3).
///
/// **Pourquoi deux sources, et pourquoi ça reste tenable.** Les 115 messages
/// déjà en production sont lisibles par le serveur par construction : les
/// ré-encapsuler en MLS demanderait des clés que personne ne doit avoir. Ils
/// sont donc gelés, et `conversations.mls_since` marque la frontière. À
/// partir de là, une seule source est VIVANTE : le legacy n'est plus qu'une
/// lecture paginée, sans temps réel. C'est ce qui rend la coexistence
/// supportable — `.stream()` de Supabase ne sait de toute façon ni joindre ni
/// lire deux tables.
///
/// La fusion est une fonction pure : elle prend deux listes déjà ordonnées et
/// rend la liste affichable. Aucun accès réseau, donc testable sans base.
class MlsSourceMerger {
  MlsSourceMerger._();

  /// Fusionne par ordre chronologique et insère le séparateur à la frontière.
  ///
  /// [legacy] et [mls] sont supposées croissantes (du plus ancien au plus
  /// récent), comme les rend le repository. [mlsSince] est la date de
  /// bascule ; `null` = la conversation n'est pas passée à MLS, on ne montre
  /// aucun séparateur.
  ///
  /// Le séparateur n'apparaît que si les deux côtés ont quelque chose à
  /// montrer : annoncer « messages d'avant » au-dessus d'un fil vide, ou sous
  /// le dernier message d'une conversation qui n'a encore rien reçu en MLS,
  /// ne dirait rien à personne.
  static List<MessageEntity> fusionner({
    required List<MessageEntity> legacy,
    required List<MessageEntity> mls,
    DateTime? mlsSince,
  }) {
    if (mls.isEmpty) return List.of(legacy);
    if (legacy.isEmpty) return List.of(mls);

    final sortie = <MessageEntity>[...legacy];
    sortie.add(MlsMessageMapper.separateur(mlsSince ?? mls.first.createdAt));
    sortie.addAll(mls);
    return sortie;
  }

  /// Retire le séparateur d'une liste : l'écran l'affiche, mais tout ce qui
  /// compte des messages (badge de non-lus, réponse, recherche) doit
  /// l'ignorer, sinon il compterait un message qui n'existe pas.
  static List<MessageEntity> sansSeparateur(List<MessageEntity> messages) =>
      messages.where((m) => !MlsMessageMapper.estSeparateur(m)).toList();

  /// Vrai si cette conversation a basculé : au-delà de cette date, plus rien
  /// ne doit être écrit dans `messages`.
  static bool estBasculee(DateTime? mlsSince) => mlsSince != null;
}
