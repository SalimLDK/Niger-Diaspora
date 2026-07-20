import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents a parsed text segment with its type and content
class TextSegment {
  final String text;
  final TextSegmentType type;
  final String? url; // For links
  final String? mentionUserId; // For @mentions

  const TextSegment({
    required this.text,
    required this.type,
    this.url,
    this.mentionUserId,
  });
}

/// Types of text segments
enum TextSegmentType {
  plain,
  bold,
  italic,
  boldItalic,
  strikethrough,
  code,
  link,
  mention,
  hashtag,
}

/// Callback types for interactive elements
typedef OnMentionTap = void Function(String userId, String displayName);
typedef OnHashtagTap = void Function(String hashtag);
typedef OnLinkTap = void Function(String url);

/// Rich text parser for message content
/// Supports markdown-like formatting:
/// - **bold** or __bold__
/// - *italic* or _italic_
/// - ***bold italic***
/// - ~~strikethrough~~
/// - `code`
/// - Links (auto-detected URLs)
/// - @mentions
/// - #hashtags
class RichTextParser {
  // Regex patterns for text formatting
  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*|__(.+?)__');
  static final _italicPattern = RegExp(r'\*([^*]+)\*|_([^_]+)_');
  static final _boldItalicPattern = RegExp(r'\*\*\*(.+?)\*\*\*');
  static final _strikethroughPattern = RegExp(r'~~(.+?)~~');
  static final _codePattern = RegExp(r'`([^`]+)`');
  static final _urlPattern = RegExp(
    r'https?://[^\s<>\[\]()]+|www\.[^\s<>\[\]()]+',
    caseSensitive: false,
  );
  static final _mentionPattern = RegExp(r'@(\w+)');
  static final _hashtagPattern = RegExp(r'#(\w+)');

  /// Parse text and return a list of TextSegments
  static List<TextSegment> parse(String text) {
    final segments = <TextSegment>[];
    var currentIndex = 0;

    // Combined pattern for all formatting
    final combinedPattern = RegExp(
      r'(\*\*\*(.+?)\*\*\*)|' // Bold italic
      r'(\*\*(.+?)\*\*|__(.+?)__)|' // Bold
      r'(\*([^*]+)\*|_([^_]+)_)|' // Italic
      r'(~~(.+?)~~)|' // Strikethrough
      r'(`([^`]+)`)|' // Code
      r'(https?://[^\s<>\[\]()]+|www\.[^\s<>\[\]()]+)|' // URLs
      r'(@\w+)|' // Mentions
      r'(#\w+)', // Hashtags
      caseSensitive: false,
    );

    for (final match in combinedPattern.allMatches(text)) {
      // Add plain text before this match
      if (match.start > currentIndex) {
        segments.add(
          TextSegment(
            text: text.substring(currentIndex, match.start),
            type: TextSegmentType.plain,
          ),
        );
      }

      final matchText = match.group(0)!;

      // Determine segment type
      if (matchText.startsWith('***') && matchText.endsWith('***')) {
        segments.add(
          TextSegment(
            text: matchText.substring(3, matchText.length - 3),
            type: TextSegmentType.boldItalic,
          ),
        );
      } else if ((matchText.startsWith('**') && matchText.endsWith('**')) ||
          (matchText.startsWith('__') && matchText.endsWith('__'))) {
        segments.add(
          TextSegment(
            text: matchText.substring(2, matchText.length - 2),
            type: TextSegmentType.bold,
          ),
        );
      } else if ((matchText.startsWith('*') &&
              matchText.endsWith('*') &&
              !matchText.startsWith('**')) ||
          (matchText.startsWith('_') &&
              matchText.endsWith('_') &&
              !matchText.startsWith('__'))) {
        segments.add(
          TextSegment(
            text: matchText.substring(1, matchText.length - 1),
            type: TextSegmentType.italic,
          ),
        );
      } else if (matchText.startsWith('~~') && matchText.endsWith('~~')) {
        segments.add(
          TextSegment(
            text: matchText.substring(2, matchText.length - 2),
            type: TextSegmentType.strikethrough,
          ),
        );
      } else if (matchText.startsWith('`') && matchText.endsWith('`')) {
        segments.add(
          TextSegment(
            text: matchText.substring(1, matchText.length - 1),
            type: TextSegmentType.code,
          ),
        );
      } else if (_urlPattern.hasMatch(matchText)) {
        final url =
            matchText.startsWith('www.') ? 'https://$matchText' : matchText;
        segments.add(
          TextSegment(text: matchText, type: TextSegmentType.link, url: url),
        );
      } else if (matchText.startsWith('@')) {
        segments.add(
          TextSegment(
            text: matchText,
            type: TextSegmentType.mention,
            mentionUserId: matchText.substring(1), // Remove @
          ),
        );
      } else if (matchText.startsWith('#')) {
        segments.add(
          TextSegment(text: matchText, type: TextSegmentType.hashtag),
        );
      }

      currentIndex = match.end;
    }

    // Add remaining plain text
    if (currentIndex < text.length) {
      segments.add(
        TextSegment(
          text: text.substring(currentIndex),
          type: TextSegmentType.plain,
        ),
      );
    }

    return segments;
  }

  /// Build a TextSpan tree from parsed segments
  static TextSpan buildTextSpan({
    required String text,
    required TextStyle baseStyle,
    Color? linkColor,
    Color? mentionColor,
    Color? hashtagColor,
    Color? codeBackgroundColor,
    OnLinkTap? onLinkTap,
    OnMentionTap? onMentionTap,
    OnHashtagTap? onHashtagTap,
  }) {
    final segments = parse(text);
    final spans = <InlineSpan>[];

    for (final segment in segments) {
      final span = _buildSpanForSegment(
        segment: segment,
        baseStyle: baseStyle,
        linkColor: linkColor ?? Colors.blue,
        mentionColor: mentionColor ?? Colors.blue,
        hashtagColor: hashtagColor ?? Colors.blue,
        codeBackgroundColor: codeBackgroundColor ?? Colors.grey.shade200,
        onLinkTap: onLinkTap,
        onMentionTap: onMentionTap,
        onHashtagTap: onHashtagTap,
      );
      spans.add(span);
    }

    return TextSpan(children: spans);
  }

  static InlineSpan _buildSpanForSegment({
    required TextSegment segment,
    required TextStyle baseStyle,
    required Color linkColor,
    required Color mentionColor,
    required Color hashtagColor,
    required Color codeBackgroundColor,
    OnLinkTap? onLinkTap,
    OnMentionTap? onMentionTap,
    OnHashtagTap? onHashtagTap,
  }) {
    switch (segment.type) {
      case TextSegmentType.plain:
        return TextSpan(text: segment.text, style: baseStyle);

      case TextSegmentType.bold:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        );

      case TextSegmentType.italic:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        );

      case TextSegmentType.boldItalic:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        );

      case TextSegmentType.strikethrough:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        );

      case TextSegmentType.code:
        return WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: codeBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              segment.text,
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 14) * 0.9,
              ),
            ),
          ),
        );

      case TextSegmentType.link:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () {
                  if (onLinkTap != null) {
                    onLinkTap(segment.url!);
                  } else {
                    _launchUrl(segment.url!);
                  }
                },
        );

      case TextSegmentType.mention:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(
            color: mentionColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () {
                  onMentionTap?.call(segment.mentionUserId!, segment.text);
                },
        );

      case TextSegmentType.hashtag:
        return TextSpan(
          text: segment.text,
          style: baseStyle.copyWith(
            color: hashtagColor,
            fontWeight: FontWeight.w500,
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap = () {
                  onHashtagTap?.call(segment.text.substring(1)); // Remove #
                },
        );
    }
  }

  /// Helper to launch URLs
  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Check if text contains any rich formatting
  static bool hasRichFormatting(String text) {
    return _boldPattern.hasMatch(text) ||
        _italicPattern.hasMatch(text) ||
        _strikethroughPattern.hasMatch(text) ||
        _codePattern.hasMatch(text) ||
        _urlPattern.hasMatch(text) ||
        _mentionPattern.hasMatch(text) ||
        _hashtagPattern.hasMatch(text);
  }

  /// Strip all formatting and return plain text
  static String stripFormatting(String text) {
    var result = text;
    result = result.replaceAllMapped(
      _boldItalicPattern,
      (m) => m.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      _boldPattern,
      (m) => m.group(1) ?? m.group(2) ?? '',
    );
    result = result.replaceAllMapped(
      _italicPattern,
      (m) => m.group(1) ?? m.group(2) ?? '',
    );
    result = result.replaceAllMapped(
      _strikethroughPattern,
      (m) => m.group(1) ?? '',
    );
    result = result.replaceAllMapped(_codePattern, (m) => m.group(1) ?? '');
    return result;
  }
}

/// Widget that displays rich text with formatting support
class RichTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? linkColor;
  final Color? mentionColor;
  final Color? hashtagColor;
  final Color? codeBackgroundColor;
  final OnLinkTap? onLinkTap;
  final OnMentionTap? onMentionTap;
  final OnHashtagTap? onHashtagTap;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const RichTextWidget({
    super.key,
    required this.text,
    this.style,
    this.linkColor,
    this.mentionColor,
    this.hashtagColor,
    this.codeBackgroundColor,
    this.onLinkTap,
    this.onMentionTap,
    this.onHashtagTap,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? DefaultTextStyle.of(context).style;

    return Text.rich(
      RichTextParser.buildTextSpan(
        text: text,
        baseStyle: defaultStyle,
        linkColor: linkColor,
        mentionColor: mentionColor,
        hashtagColor: hashtagColor,
        codeBackgroundColor: codeBackgroundColor,
        onLinkTap: onLinkTap,
        onMentionTap: onMentionTap,
        onHashtagTap: onHashtagTap,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
