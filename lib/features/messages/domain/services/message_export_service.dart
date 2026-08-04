import 'dart:convert' show HtmlEscape, HtmlEscapeMode, jsonEncode;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

enum ExportFormat { txt, json, html }

/// Service d'export des conversations
class MessageExportService {
  // HtmlEscapeMode.element escapes only <, >, & — correct for text inside
  // HTML elements. Avoids over-escaping / to &#47; which breaks URLs and
  // closing tags in assertions while remaining safe against injection.
  static const _htmlEscape = HtmlEscape(HtmlEscapeMode.element);

  static bool _isSafeUrl(String url) =>
      url.startsWith('https://') || url.startsWith('http://');
  /// Exporter une conversation
  Future<File> exportConversation({
    required ConversationEntity conversation,
    required List<MessageEntity> messages,
    required ExportFormat format,
    required String currentUserId,
    bool includeMedia = false,
  }) async {
    switch (format) {
      case ExportFormat.txt:
        return _exportAsText(conversation, messages);
      case ExportFormat.json:
        return _exportAsJson(conversation, messages);
      case ExportFormat.html:
        return _exportAsHtml(
          conversation,
          messages,
          includeMedia,
          currentUserId,
        );
    }
  }

  /// Obtenir le nom d'affichage de la conversation
  String _getDisplayName(ConversationEntity conversation) {
    return conversation.name ?? 'Conversation';
  }

  /// Export format texte simple
  Future<File> _exportAsText(
    ConversationEntity conversation,
    List<MessageEntity> messages,
  ) async {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // En-tete
    buffer.writeln('=' * 50);
    buffer.writeln('CONVERSATION DIASPO NIGER');
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('Avec: ${_getDisplayName(conversation)}');
    buffer.writeln('Exportee le: ${dateFormat.format(DateTime.now())}');
    buffer.writeln('Nombre de messages: ${messages.length}');
    buffer.writeln();
    buffer.writeln('-' * 50);
    buffer.writeln();

    // Messages (du plus ancien au plus recent)
    for (final message in messages.reversed) {
      final time = dateFormat.format(message.createdAt);
      final sender = message.senderName;

      String content;
      if (message.deletedForEveryone) {
        content = '[Message supprime]';
      } else if (message.type == MessageType.text) {
        content = message.content;
      } else if (message.type == MessageType.image) {
        content =
            '[Image] ${message.content.isNotEmpty ? message.content : ''}';
      } else if (message.type == MessageType.video) {
        content =
            '[Video] ${message.content.isNotEmpty ? message.content : ''}';
      } else if (message.type == MessageType.audio) {
        content =
            '[Audio - ${message.audioDuration ?? 0}s: ${message.fileName ?? 'fichier'}]';
      } else if (message.type == MessageType.voiceNote) {
        content = '[Message vocal - ${message.audioDuration ?? 0}s]';
      } else if (message.type == MessageType.file) {
        content = '[Document: ${message.fileName ?? 'fichier'}]';
      } else {
        content = message.content;
      }

      buffer.writeln('[$time] $sender:');
      buffer.writeln(content);
      buffer.writeln();
    }

    // Sauvegarder le fichier
    final dir = await getTemporaryDirectory();
    final fileName =
        'conversation_${conversation.id}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file;
  }

  /// Export format JSON
  Future<File> _exportAsJson(
    ConversationEntity conversation,
    List<MessageEntity> messages,
  ) async {
    final export = {
      'conversation': {
        'id': conversation.id,
        'displayName': _getDisplayName(conversation),
        'type': conversation.type.name,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
      },
      'messages':
          messages
              .map(
                (m) => {
                  'id': m.id,
                  'senderId': m.senderId,
                  'senderName': m.senderName,
                  'content':
                      m.deletedForEveryone ? '[Message supprime]' : m.content,
                  'type': m.type.name,
                  'createdAt': m.createdAt.toUtc().toIso8601String(),
                  'isDeleted': m.deletedForEveryone,
                },
              )
              .toList(),
    };

    final dir = await getTemporaryDirectory();
    final fileName =
        'conversation_${conversation.id}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonEncode(export));

    return file;
  }

  /// Export format HTML
  Future<File> _exportAsHtml(
    ConversationEntity conversation,
    List<MessageEntity> messages,
    bool includeMedia,
    String currentUserId,
  ) async {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final safeDisplayName = _htmlEscape.convert(_getDisplayName(conversation));

    buffer.writeln('''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Conversation avec $safeDisplayName</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
    .header { background: #075E54; color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
    .message { margin: 10px 0; padding: 10px 15px; border-radius: 10px; max-width: 80%; }
    .message.sent { background: #DCF8C6; margin-left: auto; }
    .message.received { background: white; }
    .sender { font-weight: bold; font-size: 0.9em; color: #075E54; }
    .time { font-size: 0.75em; color: #999; margin-top: 5px; }
    .deleted { font-style: italic; color: #999; }
    .media { color: #666; font-style: italic; }
  </style>
</head>
<body>
  <div class="header">
    <h1>Conversation avec $safeDisplayName</h1>
    <p>Exportee le ${dateFormat.format(DateTime.now())}</p>
    <p>${messages.length} messages</p>
  </div>
''');

    for (final message in messages.reversed) {
      final time = dateFormat.format(message.createdAt);
      final isSent = message.senderId == currentUserId;

      final safeSenderName = _htmlEscape.convert(message.senderName);

      String content;
      if (message.deletedForEveryone) {
        content = '<span class="deleted">Message supprime</span>';
      } else if (message.type == MessageType.image &&
          includeMedia &&
          message.fileUrl != null &&
          _isSafeUrl(message.fileUrl!)) {
        final safeUrl = _htmlEscape.convert(message.fileUrl!);
        content = '<img src="$safeUrl" style="max-width:100%;" alt="Image">';
      } else if (message.type != MessageType.text) {
        content = '<span class="media">[${_htmlEscape.convert(message.type.name)}]</span>';
      } else {
        content = _htmlEscape.convert(message.content).replaceAll('\n', '<br>');
      }

      buffer.writeln('''
  <div class="message ${isSent ? 'sent' : 'received'}">
    <div class="sender">$safeSenderName</div>
    <div>$content</div>
    <div class="time">$time</div>
  </div>
''');
    }

    buffer.writeln('</body></html>');

    final dir = await getTemporaryDirectory();
    final fileName =
        'conversation_${conversation.id}_${DateTime.now().millisecondsSinceEpoch}.html';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file;
  }

  /// Partager le fichier exporte
  Future<void> shareExportedFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Export de conversation Diaspo Niger',
      ),
    );
  }
}
