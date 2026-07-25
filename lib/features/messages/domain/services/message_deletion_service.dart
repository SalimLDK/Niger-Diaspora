import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/encryption_service.dart';

/// Resultat d'une operation de suppression
sealed class DeletionResult {
  const DeletionResult();
}

final class DeletionSuccess extends DeletionResult {
  const DeletionSuccess();
}

final class DeletionFailure extends DeletionResult {
  final String message;
  final DeletionErrorType type;

  const DeletionFailure(this.message, this.type);
}

/// Types d'erreurs de suppression
enum DeletionErrorType {
  permissionDenied,
  timeLimitExceeded,
  messageNotFound,
  networkError,
  unknown,
}

/// Service complet pour la gestion des suppressions de messages
class MessageDeletionService {
  final rtdb.FirebaseDatabase _database;
  final FirebaseStorage _storage;
  final SupabaseClient _supabase;
  final EncryptionService? _encryption;

  /// Delai maximum pour supprimer pour tous (1 heure)
  static const Duration deleteForEveryoneWindow = Duration(hours: 1);

  MessageDeletionService({
    rtdb.FirebaseDatabase? database,
    FirebaseStorage? storage,
    SupabaseClient? supabase,
    EncryptionService? encryption,
  }) : _database = database ?? rtdb.FirebaseDatabase.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _supabase = supabase ?? Supabase.instance.client,
       _encryption = encryption;

  /// Supprimer un message pour l'utilisateur courant uniquement (soft delete)
  Future<Either<Failure, void>> deleteForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageRef = _database.ref('messages/$conversationId/$messageId');

      // CORRECTION: Utiliser une transaction atomique pour eviter les race conditions
      await messageRef.child('deletedFor').runTransaction((currentData) {
        final deletedFor = _parseStringList(currentData);
        if (!deletedFor.contains(userId)) {
          deletedFor.add(userId);
        }
        return rtdb.Transaction.success(deletedFor);
      });

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la suppression: $e'));
    }
  }

  /// Supprimer un message pour tous les participants
  Future<DeletionResult> deleteForEveryone({
    required String conversationId,
    required String messageId,
    required String senderId,
    required String currentUserId,
    required DateTime messageCreatedAt,
  }) async {
    // 1. Verifier les permissions
    if (senderId != currentUserId) {
      return const DeletionFailure(
        'Seul l\'expediteur peut supprimer ce message pour tous',
        DeletionErrorType.permissionDenied,
      );
    }

    // 2. Verifier la limite de temps
    final elapsed = DateTime.now().difference(messageCreatedAt);
    if (elapsed > deleteForEveryoneWindow) {
      return const DeletionFailure(
        'Le delai de suppression est depasse. Vous ne pouvez supprimer pour tous que dans l\'heure suivant l\'envoi.',
        DeletionErrorType.timeLimitExceeded,
      );
    }

    try {
      // 3. Recuperer les donnees du message
      final messageRef = _database.ref('messages/$conversationId/$messageId');
      final snapshot = await messageRef.get();

      if (!snapshot.exists) {
        return const DeletionFailure(
          'Message introuvable',
          DeletionErrorType.messageNotFound,
        );
      }

      final data = snapshot.value as Map<dynamic, dynamic>;

      // 4. Supprimer les fichiers media associes
      await _deleteMediaFiles(data);

      // 5. Mettre a jour le message
      await messageRef.update({
        'deletedForEveryone': true,
        'deletedAt': DateTime.now().toUtc().toIso8601String(),
        'content': '', // Vider le contenu
        'fileUrl': null,
        'thumbnailUrl': null,
        'audioWaveform': null,
        'linkPreviewData': null,
      });

      // 6. Mettre a jour la preview de conversation si necessaire
      await _updateConversationPreviewIfNeeded(conversationId, data);

      return const DeletionSuccess();
    } catch (e) {
      return DeletionFailure(
        'Erreur reseau: $e',
        DeletionErrorType.networkError,
      );
    }
  }

  /// Supprimer plusieurs messages en batch (pour moi uniquement)
  Future<Either<Failure, int>> deleteMultipleForMe({
    required String conversationId,
    required List<String> messageIds,
    required String userId,
  }) async {
    try {
      int deletedCount = 0;
      final updates = <String, dynamic>{};

      for (final messageId in messageIds) {
        // Recuperer les donnees actuelles
        final snapshot =
            await _database
                .ref('messages/$conversationId/$messageId/deletedFor')
                .get();
        final deletedFor = _parseStringList(snapshot.value);

        if (!deletedFor.contains(userId)) {
          deletedFor.add(userId);
          updates['messages/$conversationId/$messageId/deletedFor'] =
              deletedFor;
          deletedCount++;
        }
      }

      if (updates.isNotEmpty) {
        await _database.ref().update(updates);
      }

      return Right(deletedCount);
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la suppression: $e'));
    }
  }

  /// Supprimer une conversation complete
  Future<Either<Failure, void>> deleteConversation({
    required String conversationId,
    required String userId,
    required bool isAdmin,
  }) async {
    try {
      if (isAdmin) {
        // Admin: suppression complete (hard delete)
        await _hardDeleteConversation(conversationId);
      } else {
        // Utilisateur normal: soft delete
        await _softDeleteConversation(conversationId, userId);
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Erreur lors de la suppression: $e'));
    }
  }

  /// Verifier si un utilisateur peut supprimer un message pour tous
  bool canDeleteForEveryone({
    required String senderId,
    required String currentUserId,
    required DateTime messageCreatedAt,
  }) {
    if (senderId != currentUserId) return false;

    final elapsed = DateTime.now().difference(messageCreatedAt);
    return elapsed <= deleteForEveryoneWindow;
  }

  /// Temps restant pour supprimer pour tous (en minutes)
  int? timeRemainingForDeleteForEveryone(DateTime messageCreatedAt) {
    final elapsed = DateTime.now().difference(messageCreatedAt);
    if (elapsed > deleteForEveryoneWindow) return null;

    return (deleteForEveryoneWindow.inMinutes - elapsed.inMinutes);
  }

  // ============ METHODES PRIVEES ============

  /// Supprimer les fichiers media associes au message
  Future<void> _deleteMediaFiles(Map<dynamic, dynamic> messageData) async {
    final fileUrl = messageData['fileUrl'] as String?;
    final thumbnailUrl = messageData['thumbnailUrl'] as String?;
    final filesToDelete =
        [
          fileUrl,
          thumbnailUrl,
        ].whereType<String>().where((url) => url.isNotEmpty).toList();

    for (final url in filesToDelete) {
      try {
        // Verifier que c'est une URL Firebase Storage
        if (url.contains('firebasestorage.googleapis.com') ||
            url.contains('firebase.google.com')) {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        }
      } catch (e) {
        // Log l'erreur mais continuer - le fichier peut ne plus exister
        // ou ne pas etre un fichier Firebase Storage
      }
    }
  }

  /// Mettre a jour la preview de la conversation si le message supprime etait le dernier
  Future<void> _updateConversationPreviewIfNeeded(
    String conversationId,
    Map<dynamic, dynamic> deletedMessageData,
  ) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);

      if (rows.isEmpty) return;

      final convData =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      final lastSenderId = convData['lastMessageSenderId'] as String?;
      final deletedMsgSenderId = deletedMessageData['senderId'] as String?;

      // Verifier si c'etait le dernier message
      if (lastSenderId == deletedMsgSenderId) {
        // Chiffrer le texte de remplacement si E2EE est active
        String replacementText = 'Message supprime';
        if (_encryption case final encryption?) {
          replacementText = encryption.encryptText(replacementText);
        }

        final updated = {...convData, 'lastMessage': replacementText};
        await _supabase
            .from('conversations')
            .update({'data': updated})
            .eq('id', conversationId);
      }
    } catch (e) {
      // Erreur non critique, la conversation continue de fonctionner
    }
  }

  /// Suppression complete d'une conversation (admin uniquement)
  Future<void> _hardDeleteConversation(String conversationId) async {
    // 1. Fetch messages from Supabase and delete associated media files
    try {
      final rows = await _supabase
          .from('messages')
          .select('data')
          .eq('conversation_id', conversationId);

      for (final row in rows) {
        final msgData =
            Map<dynamic, dynamic>.from((row['data'] as Map?) ?? {});
        await _deleteMediaFiles(msgData);
      }
    } catch (_) {
      // Continue even if media cleanup fails
    }

    // 2. Hard delete the conversation row (cascade deletes messages in Supabase)
    await _supabase
        .from('conversations')
        .delete()
        .eq('id', conversationId);

    // 3. Clean up RTDB signaling data
    await _database.ref('typing/$conversationId').remove();
    await _database.ref('conversations/$conversationId').remove();
  }

  /// Suppression douce d'une conversation (utilisateur normal)
  Future<void> _softDeleteConversation(
    String conversationId,
    String userId,
  ) async {
    // Fetch current data JSONB, merge deletedBy entry, and write back
    final rows = await _supabase
        .from('conversations')
        .select('data')
        .eq('id', conversationId)
        .limit(1);

    if (rows.isEmpty) return;

    final current =
        Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
    final deletedBy =
        Map<String, dynamic>.from(current['deletedBy'] as Map? ?? {});
    deletedBy[userId] = DateTime.now().toUtc().toIso8601String();
    current['deletedBy'] = deletedBy;

    await _supabase
        .from('conversations')
        .update({'data': current})
        .eq('id', conversationId);
  }

  /// Parser une liste de strings depuis une valeur dynamique
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}

// ============ PROVIDER ============

/// Provider pour le service de suppression de messages
final messageDeletionServiceProvider = Provider<MessageDeletionService>((ref) {
  return MessageDeletionService();
});

/// Provider pour supprimer un message
final deleteMessageActionProvider = FutureProvider.family<
  DeletionResult,
  ({
    String conversationId,
    String messageId,
    String senderId,
    String currentUserId,
    DateTime messageCreatedAt,
    bool forEveryone,
  })
>((ref, params) async {
  final service = ref.watch(messageDeletionServiceProvider);

  if (params.forEveryone) {
    return service.deleteForEveryone(
      conversationId: params.conversationId,
      messageId: params.messageId,
      senderId: params.senderId,
      currentUserId: params.currentUserId,
      messageCreatedAt: params.messageCreatedAt,
    );
  } else {
    final result = await service.deleteForMe(
      conversationId: params.conversationId,
      messageId: params.messageId,
      userId: params.currentUserId,
    );
    return result.fold(
      (failure) => DeletionFailure(failure.message, DeletionErrorType.unknown),
      (_) => const DeletionSuccess(),
    );
  }
});
