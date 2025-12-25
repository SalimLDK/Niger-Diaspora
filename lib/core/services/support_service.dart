import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportService {
  static const String supportEmail = 'support@diasponiger.com';
  static const String bugReportEmail = 'bugs@diasponiger.com';
  static const String feedbackEmail = 'feedback@diasponiger.com';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.diasponiger.app';
  static const String appStoreUrl =
      'https://apps.apple.com/app/diasponiger/id123456789';

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
      subject: 'Support - Niger Diaspora App',
      body: _buildContactEmailBody(additionalInfo),
    );
  }

  /// Send bug report email
  Future<bool> sendBugReportEmail({
    required String bugDescription,
    String? stepsToReproduce,
  }) async {
    return sendEmail(
      to: bugReportEmail,
      subject: 'Bug Report - Niger Diaspora App',
      body: _buildBugReportEmailBody(bugDescription, stepsToReproduce),
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
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
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

  String _buildBugReportEmailBody(String bugDescription, String? stepsToReproduce) {
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
