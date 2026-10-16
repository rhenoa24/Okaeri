import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Sends a push notification to a partner by calling the Cloudflare Worker,
/// which then talks to Firebase Cloud Messaging on our behalf.
class NotificationSender {
  static const String _workerUrl =
      'https://okaeri-notify.okaeri-dev.workers.dev';

  /// Sends a push notification. Fails silently (logs only) since a missed
  /// notification shouldn't block the user's actual action (e.g. posting
  /// a message board update should still succeed even if the push fails).
  static Future<void> send({
    required String token,
    required String title,
    String? body,
  }) async {
    try {
      // Short-lived proof that the caller is a logged-in Okaeri user.
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        // ignore: avoid_print
        print('Notification skipped: no signed-in user');
        return;
      }

      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'token': token, 'title': title, 'body': ?body}),
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
