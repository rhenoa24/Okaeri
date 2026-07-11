import 'dart:convert';
import 'package:http/http.dart' as http;

/// Sends a push notification to a partner by calling the Cloudflare Worker,
/// which then talks to Firebase Cloud Messaging on our behalf.
class NotificationSender {
  // Replace with your actual deployed Worker URL.
  static const String _workerUrl =
      'https://okaeri-notify.okaeri-dev.workers.dev';

  // Must match the SHARED_SECRET value set via `wrangler secret put SHARED_SECRET`.
  // TODO: move this out of source code before sharing/publishing this repo
  // (see note below).
  static const String _sharedSecret = 'P0uKDPtLOZZf3p2Wtnajre0TPiLhgZaB';

  /// Sends a push notification. Fails silently (logs only) since a missed
  /// notification shouldn't block the user's actual action (e.g. posting
  /// a message board update should still succeed even if the push fails).
  static Future<void> send({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Okaeri-Secret': _sharedSecret,
        },
        body: jsonEncode({'token': token, 'title': title, 'body': body}),
      );

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print(
          'Notification send failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Notification send error: $e');
    }
  }
}
