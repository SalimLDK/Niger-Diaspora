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

      // Write to Realtime Database (where messages are read from)
      // IMPORTANT: senderId must be the current authenticated user for Firebase rules
      final messageRef = _database.ref().child('messages').child(convId).push();
      final now = DateTime.now().toUtc().toIso8601String();
      final messageData = {
        'conversationId': convId,
        'senderId': currentUserId, // Must be auth.uid for Firebase rules
        'senderName': currentUserName,
        'type': 'call',
        'callType': callType,
        'callStatus': callStatus,
        'callDuration': callDuration,
        'callId': callId,
        'callerId': callerId, // Keep original caller info for display
        'calleeId': calleeId, // Keep original callee info for display
        'content': messageContent,
        'createdAt': now,
        'status': 'sent',
      };

      await messageRef.set(messageData);
      debugPrint('appel: Message written to RTDB at ${messageRef.path}');

      // Mettre à jour la conversation dans Supabase avec le dernier message
      final existing = await Supabase.instance.client
          .from('conversations')
          .select('data')
          .eq('id', convId)
          .maybeSingle();
      final data = Map<String, dynamic>.from(existing?['data'] as Map? ?? {});
      data['last_message'] = messageContent;
      data['last_message_at'] = DateTime.now().toUtc().toIso8601String();
      data['last_message_sender_id'] = currentUserId;
      data['last_message_type'] = 'call';
      data['last_call_status'] = callStatus;
      await Supabase.instance.client
          .from('conversations')
          .update({'data': data, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', convId);

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
      debugPrint('appel: Creating new conversation...');
      final newId = const Uuid().v4();
      await Supabase.instance.client.from('conversations').insert({
        'id': newId,
        'type': 'individual',
        'participant_ids': [user1Id, user2Id],
        'created_by': user1Id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'data': {
          'created_by': user1Id,
          'unread_counts': {user1Id: 0, user2Id: 0},
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        },
      });
      debugPrint('appel: New conversation created: $newId');
      return newId;
    } catch (e) {
      debugPrint('appel: ERROR _getOrCreateConversation - $e');
      return null;
    }
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
        return '$typeStr manqué';
      case 'declined':
        return '$typeStr refusé';
      case 'cancelled':
        return '$typeStr sortant';
      default:
        return typeStr;
    }
  }
}
