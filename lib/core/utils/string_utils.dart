class StringUtils {
  /// Normalize a string to be used as a Firebase Cloud Messaging topic
  /// Topics must match the following regular expression: [a-zA-Z0-9-_.~%]+
  static String normalizeTopic(String topic) {
    if (topic.isEmpty) return 'general';

    // Replace invalid characters with underscore
    return topic.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
  }
}
