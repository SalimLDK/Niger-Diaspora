import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'supabase_auth_bridge.dart';

/// Service pour créer automatiquement des messages d'appel dans les conversations
class CallMessageService {
  final FirebaseDatabase _database;

  CallMessageService({
    FirebaseDatabase? database,
  }) : _database = database ?? FirebaseDatabase.instance;

  /// Crée un message d'appel dans la conversation entre deux utilisateurs
  ///
  /// [currentUserId] et [currentUserName] représentent l'utilisateur qui crée le message
  /// (celui qui est actuellement connecté). C'est important car les règles Firebase
  /// exigent que senderId === auth.uid.
  ///
  /// [conversationId] - Optionnel. Si fourni, utiliser directement (pour groupes).
  /// [groupParticipantIds] - Pour les groupes, liste de tous les participants.
  Future<void> createCallMessage({
    required String callId,
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
    required String callType, // 'audio' ou 'video'
    required String callStatus, // 'ended', 'missed', 'declined', 'cancelled'
    int? callDuration, // en secondes
    required String currentUserId, // L'utilisateur connecté qui crée le message
    required String currentUserName,
    String? conversationId, // Optionnel - si fourni, utiliser directement (pour groupes)
    List<String>? groupParticipantIds, // Pour les groupes - tous les participants
  }) async {
    try {
      debugPrint('appel: CallMessageService - Creating call message...');
      debugPrint('appel: callerId: $callerId, calleeId: $calleeId, currentUser: $currentUserId');
      debugPrint('appel: callType: $callType, callStatus: $callStatus, duration: $callDuration');
      debugPrint('appel: conversationId provided: $conversationId');

      // Si conversationId fourni, l'utiliser directement (groupe)
      // Sinon, chercher/créer pour appel 1:1
      final convId = conversationId ??
          await _getOrCreateConversation(
            callerId,
            callerName,
            calleeId,
            calleeName,
          );

      if (convId == null) {
        debugPrint('appel: ERROR - conversationId is NULL!');
        return;
      }
      debugPrint('appel: conversationId = $convId');

      // S'assurer que les participants existent dans RTDB pour les permissions
      final participantIds = groupParticipantIds ?? [callerId, calleeId];
      await _ensureParticipantsInRTDB(convId, participantIds);
      debugPrint('appel: Participants ensured in RTDB');

      // Créer le message d'appel
      final messageContent = _getCallMessageContent(
        callType,
        callStatus,
        callDuration,
      );

      // Write to the Supabase `messages` table — c'est la seule source lue
      // par la conversation (MessageSupabaseDataSource.getMessages stream sur
      // Supabase, plus rien ne lit `messages/{convId}` en RTDB depuis la
      // migration). Écrire en RTDB ici produisait un message d'appel que
      // l'écran de conversation ne voyait jamais : la bulle n'apparaissait
      // jamais, sans erreur nulle part.
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        debugPrint('appel: ERROR createCallMessage - Supabase session introuvable');
        return;
      }

      final msgId = const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final msgData = <String, dynamic>{
        'senderName': currentUserName,
        'content': messageContent,
        'status': 'sent',
        'callType': callType,
        'callStatus': callStatus,
        if (callDuration != null) 'callDuration': callDuration,
        'callId': callId,
        'callerId': callerId, // Keep original caller info for display
        'calleeId': calleeId, // Keep original callee info for display
        'readBy': [currentUserId],
        'deliveredTo': [currentUserId],
      };

      await Supabase.instance.client.from('messages').insert({
        'id': msgId,
        'conversation_id': convId,
        'sender_id': currentUserId, // Must be auth.uid for RLS
        'type': 'call',
        'created_at': now,
        'data': msgData,
      });
      debugPrint('appel: Message written to Supabase messages/$msgId (conv=$convId)');

      // Mettre à jour la conversation dans Supabase avec le dernier message
      // (clés `data` en camelCase + colonne top-level `last_message_at` —
      // voir _updateConversationLastMessage)
      await _updateConversationLastMessage(
        convId,
        text: messageContent,
        senderId: currentUserId,
        at: now,
      );

      debugPrint('appel: Supabase conversation updated');
      debugPrint(
        'appel: SUCCESS - Call message created - type: $callType, status: $callStatus',
      );
    } catch (e, stackTrace) {
      debugPrint('appel: ERROR - $e');
      debugPrint('appel: StackTrace - $stackTrace');
      // Ne pas propager l'erreur pour ne pas bloquer la fin de l'appel
    }
  }

  /// Trouve ou crée une conversation 1:1 entre deux utilisateurs
  Future<String?> _getOrCreateConversation(
    String user1Id,
    String user1Name,
    String user2Id,
    String user2Name,
  ) async {
    try {
      debugPrint('appel: Looking for conversation between $user1Id and $user2Id');

      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        debugPrint('appel: ERROR _getOrCreateConversation - Supabase session introuvable');
        return null;
      }

      // Chercher une conversation existante dans Supabase
      final rows = await Supabase.instance.client
          .from('conversations')
          .select('id, participant_ids')
          .eq('type', 'individual')
          .contains('participant_ids', [user1Id]);

      debugPrint('appel: Found ${rows.length} potential conversations');

      for (final row in rows) {
        final participants = List<String>.from(row['participant_ids'] as List? ?? []);
        if (participants.contains(user2Id) && participants.length == 2) {
          debugPrint('appel: Found existing conversation: ${row['id']}');
          return row['id'] as String;
        }
      }

      // Créer une nouvelle conversation
      // Même schéma que MessageSupabaseDataSource.createIndividualConversation :
      // `data` en camelCase, `created_by`/`last_message_at` sont des colonnes
      // top-level (les dupliquer en snake_case dans `data` ne fait qu'écrire
      // des clés mortes, jamais lues par ConversationModel.fromJson).
      debugPrint('appel: Creating new conversation...');
      final newId = const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client.from('conversations').insert({
        'id': newId,
        'type': 'individual',
        'participant_ids': [user1Id, user2Id],
        'created_by': user1Id,
        'created_at': now,
        'updated_at': now,
        'data': {
          'unreadCount': {user1Id: 0, user2Id: 0},
          'requestStatus': 'none',
        },
      });
      debugPrint('appel: New conversation created: $newId');
      return newId;
    } catch (e) {
      debugPrint('appel: ERROR _getOrCreateConversation - $e');
      return null;
    }
  }

  /// Met à jour l'aperçu de dernier message de la conversation et incrémente
  /// les compteurs non lus des autres participants.
  ///
  /// Reflète exactement `MessageSupabaseDataSource._updateConversationLastMessage`
  /// / `BackgroundReplyService._updateConversationLastMessage` : mêmes clés
  /// `data` en camelCase (`lastMessage`, `lastMessageSenderId`,
  /// `lastMessageType`, `unreadCount`...) et même colonne top-level
  /// `last_message_at`. Un ancien jeu de clés snake_case ici (`last_message`,
  /// `last_message_sender_id`, `last_message_type`) écrivait dans des champs
  /// que l'UI ne lisait jamais — l'aperçu et le badge non-lu ne se mettaient
  /// jamais à jour pour les conversations initiées par un appel.
  Future<void> _updateConversationLastMessage(
    String conversationId, {
    required String text,
    required String senderId,
    required String at,
  }) async {
    final rows = await Supabase.instance.client
        .from('conversations')
        .select('data, participant_ids')
        .eq('id', conversationId)
        .limit(1);
    if (rows.isEmpty) return;

    final current = Map<String, dynamic>.from(
      (rows.first['data'] as Map<String, dynamic>?) ?? {},
    );
    final participantIds = List<String>.from(
      rows.first['participant_ids'] as List? ?? [],
    );

    final unreadCount = Map<String, dynamic>.from(
      current['unreadCount'] as Map? ?? {},
    );
    for (final pid in participantIds) {
      if (pid != senderId) {
        final cur = (unreadCount[pid] as int?) ?? 0;
        unreadCount[pid] = cur + 1;
      }
    }

    final updated = {
      ...current,
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageType': 'call',
      'lastMessageStatus': 'sent',
      'unreadCount': unreadCount,
      'lastMessageReadBy': [senderId],
      'lastMessageDeliveredTo': [senderId],
    };

    await Supabase.instance.client
        .from('conversations')
        .update({'last_message_at': at, 'data': updated})
        .eq('id', conversationId);
  }

  /// S'assure que les participants existent dans RTDB pour les permissions d'écriture
  Future<void> _ensureParticipantsInRTDB(
    String conversationId,
    List<String> participantIds,
  ) async {
    try {
      final participantsRef = _database
          .ref()
          .child('conversations')
          .child(conversationId)
          .child('participants');

      // Écrire tous les participants
      final Map<String, bool> participantsMap = {
        for (final id in participantIds) id: true,
      };
      await participantsRef.update(participantsMap);
      debugPrint('appel: Participants written to RTDB: $participantIds');
    } catch (e) {
      debugPrint('appel: ERROR _ensureParticipantsInRTDB - $e');
      // Continue anyway - maybe participants already exist
    }
  }

  /// Génère le contenu du message d'appel selon le type et le statut
  String _getCallMessageContent(
    String callType,
    String callStatus,
    int? duration,
  ) {
    final typeStr = callType == 'video' ? 'Appel vidéo' : 'Appel audio';

    switch (callStatus) {
      case 'ended':
        if (duration != null && duration > 0) {
          final minutes = duration ~/ 60;
          final seconds = duration % 60;
          return '$typeStr - ${minutes}m ${seconds}s';
        }
        return typeStr;
      case 'missed':
        // Un seul aperçu est stocké pour toute la conversation — vu par
        // l'appelant ET l'appelé. « manqué » sous-entend « vous avez
        // manqué cet appel », faux pour l'appelant qui l'a passé sans
        // réponse. Formulation neutre, correcte des deux côtés.
        return '$typeStr - Pas de réponse';
      case 'declined':
        return '$typeStr refusé';
      case 'cancelled':
        return '$typeStr sortant';
      default:
        return typeStr;
    }
  }
}
