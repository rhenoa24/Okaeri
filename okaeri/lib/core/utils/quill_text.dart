import 'dart:convert';

/// Pulls plain text out of a Quill Delta JSON string, for preview snippets.
String extractPlainText(String contentJson) {
  try {
    final ops = jsonDecode(contentJson) as List<dynamic>;
    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is Map && op['insert'] is String) {
        buffer.write(op['insert']);
      }
    }
    return buffer.toString().trim();
  } catch (_) {
    return '';
  }
}
