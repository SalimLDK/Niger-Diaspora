import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La session Firebase, **observée**.
///
/// `authStateChanges()` émet l'état courant dès l'abonnement, puis à chaque
/// connexion et déconnexion.
final _sessionFirebaseProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// L'uid Firebase du compte connecté, `null` sans session.
///
/// **À surveiller (`ref.watch`) par tout provider qui dépend du compte**, au
/// lieu de lire `FirebaseAuth.instance.currentUser` dans son corps. Un
/// `Provider` ne s'évalue qu'une fois : lire l'uid à la construction, c'est
/// figer la valeur du moment pour toute la vie du processus.
///
/// Ce que ça a coûté le 2026-09-16, en production (build 1.2.1+19 du Play
/// Store). Au démarrage à froid d'une session restaurée, `mlsGatewayProvider`
/// a été construit avant que Firebase ne rende l'utilisateur : il a gardé
/// `null`. Sans passerelle, le repository ignorait MLS pour tout le processus
/// — le fil n'affichait plus aucun message chiffré, et chaque envoi partait
/// en clair vers `messages`, refusé (400) par
/// `messages_refuse_conversation_mls_trg`. Aucune ligne dans
/// `mls_diagnostics` : rien du chemin MLS n'était plus appelé. Le même
/// téléphone marchait juste après sa première connexion, dans le même build.
///
/// Ne notifie que si l'uid **change** (un `Provider` compare l'ancienne et la
/// nouvelle valeur) : un rafraîchissement de jeton ne reconstruit rien.
final uidFirebaseProvider = Provider<String?>((ref) {
  ref.watch(_sessionFirebaseProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return (uid == null || uid.isEmpty) ? null : uid;
});
