import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/admin/domain/entities/app_settings_entity.dart';
import '../../features/admin/presentation/providers/app_settings_provider.dart';

part 'support_service.g.dart';

/// Provider for SupportService with dynamic email settings
@riverpod
SupportService supportService(Ref ref) {
  final urls = ref.watch(systemUrlsProvider);
  return SupportService(urls: urls);
}

class SupportService {
  final SystemUrlsEntity urls;

  // Fallback constants (used when settings not loaded)
  static const String defaultSupportEmail = 'support@diasponiger.com';
  static const String defaultPrivacyEmail = 'privacy@diasponiger.com';
  static const String defaultBugsEmail = 'bugs@diasponiger.com';
  static const String defaultFeedbackEmail = 'feedback@diasponiger.com';
  static const String defaultModerationEmail = 'moderation@diasponiger.com';

  // Les deux liens etaient faux et menaient a une page « app introuvable ».
  // `com.diasponiger.app` n'a jamais existe : l'`applicationId` reel est
  // `com.diasponiger.diasponiger` (android/app/build.gradle.kts). Et
  // `id123456789` etait un identifiant invente ; le vrai, attribue le
  // 2026-09-01 a la creation de la fiche, est `6807607258`.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.diasponiger.diasponiger';
  static const String appStoreUrl =
      'https://apps.apple.com/app/id6807607258';

  SupportService({SystemUrlsEntity? urls})
      : urls = urls ?? const SystemUrlsEntity();

  // Dynamic email getters
  String get supportEmail => urls.supportEmail;
  String get privacyEmail => urls.privacyEmail;
  String get bugsEmail => urls.bugsEmail;
  String get feedbackEmail => urls.feedbackEmail;
  String get moderationEmail => urls.moderationEmail;

  /// Numéro du support, vide tant qu'aucun n'est configuré.
  String get supportPhone => urls.supportPhone;

  /// Y a-t-il un numéro joignable ? Les écrans doivent masquer la ligne
  /// « Téléphone » quand ce n'est pas le cas, plutôt qu'afficher un
  /// gabarit du type « +33 1 XX XX XX XX ».
  bool get hasSupportPhone => urls.supportPhone.trim().isNotEmpty;

  /// Open email client with pre-filled subject and body
  Future<bool> sendEmail({
    required String to,
    required String subject,
    String? body,
  }) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: to,
      query: _encodeQueryParameters({
        'subject': subject,
        if (body != null) 'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        return await launchUrl(emailUri);
      }
      return false;
    } catch (e) {
      debugPrint('Error launching email: $e');
      return false;
    }
  }

  /// Send contact email
  Future<bool> sendContactEmail({String? additionalInfo}) async {
    return sendEmail(
      to: supportEmail,
      subject: 'Support - Diaspo Niger App',
      body: _buildContactEmailBody(additionalInfo),
    );
  }

  /// Send bug report email
  Future<bool> sendBugReportEmail({
    required String bugDescription,
    String? stepsToReproduce,
  }) async {
    return sendEmail(
      to: bugsEmail,
      subject: 'Bug Report - Diaspo Niger App',
      body: _buildBugReportEmailBody(bugDescription, stepsToReproduce),
    );
  }

  /// Send privacy-related email
  Future<bool> sendPrivacyEmail({String? subject, String? body}) async {
    return sendEmail(
      to: privacyEmail,
      subject: subject ?? 'Privacy Request - Diaspo Niger App',
      body: body,
    );
  }

  /// Send feedback email
  Future<bool> sendFeedbackEmail({String? feedback}) async {
    return sendEmail(
      to: feedbackEmail,
      subject: 'Feedback - Diaspo Niger App',
      body: feedback,
    );
  }

  /// Send moderation report email
  Future<bool> sendModerationEmail({
    required String reportType,
    String? details,
  }) async {
    return sendEmail(
      to: moderationEmail,
      subject: 'Moderation Report: $reportType - Diaspo Niger App',
      body: details,
    );
  }

  /// Open store for rating
  Future<bool> openStoreForReview() async {
    final String url = Platform.isIOS ? appStoreUrl : playStoreUrl;
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('Error opening store: $e');
      return false;
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  String _buildContactEmailBody(String? additionalInfo) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('App Version: 1.0.0');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('OS Version: ${Platform.operatingSystemVersion}');
    buffer.writeln('---');
    buffer.writeln();
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      buffer.writeln(additionalInfo);
    } else {
      buffer.writeln('Décrivez votre problème ici :');
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _buildBugReportEmailBody(
    String bugDescription,
    String? stepsToReproduce,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('=== RAPPORT DE BUG ===');
    buffer.writeln();
    buffer.writeln('Description du bug :');
    buffer.writeln(bugDescription);
    buffer.writeln();
    if (stepsToReproduce != null && stepsToReproduce.isNotEmpty) {
      buffer.writeln('Étapes pour reproduire :');
      buffer.writeln(stepsToReproduce);
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.writeln('Informations système :');
    buffer.writeln('App Version: 1.0.0');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('OS Version: ${Platform.operatingSystemVersion}');
    buffer.writeln('---');
    return buffer.toString();
  }
}
