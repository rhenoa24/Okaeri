import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

import 'user_service.dart';

class FcmSenderService {
  FcmSenderService._();

  /// Replace with your Firebase project ID.
  static const _projectId = 'okaeri-82b49';

  static final UserService _userService = UserService();

  /// Sends a push notification to a user by UID.
  static Future<void> sendToUser({
    required String uid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final token = await _userService.getFcmToken(uid);

    if (token == null || token.isEmpty) {
      throw Exception('No FCM token found for user: $uid');
    }

    await sendToToken(token: token, title: title, body: body, data: data);
  }

  /// Sends a push notification directly to an FCM token.
  static Future<void> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final jsonString = await rootBundle.loadString(
      'assets/firebase/service_account.json',
    );

    final credentials = ServiceAccountCredentials.fromJson(
      jsonDecode(jsonString),
    );

    final client = await clientViaServiceAccount(credentials, const [
      'https://www.googleapis.com/auth/firebase.messaging',
    ]);

    try {
      final response = await client
          .post(
            Uri.parse(
              'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': {
                'token': token,
                'notification': {'title': title, 'body': body},
                'android': {'priority': 'HIGH'},
                'apns': {
                  'headers': {'apns-priority': '10'},
                },
                if (data != null) 'data': data,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 300) {
        throw Exception('FCM Error (${response.statusCode}): ${response.body}');
      }
    } finally {
      client.close();
    }
  }
}
