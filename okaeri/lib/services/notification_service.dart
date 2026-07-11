import 'package:firebase_messaging/firebase_messaging.dart';
import 'user_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final UserService _userService = UserService();

  static bool _initialized = false;

  static Future<void> initialize(String uid) async {
    if (_initialized) return;
    _initialized = true;

    // Ask permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Save current token
    final token = await _messaging.getToken();

    if (token != null) {
      await _userService.updateFcmToken(uid, token);
    }

    // Listen for future token changes
    _messaging.onTokenRefresh.listen((newToken) async {
      await _userService.updateFcmToken(uid, newToken);
    });

    // Handle notifications that arrive while the app is open (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification received: ${message.notification?.title}');
      // TODO: show a local snackbar/dialog, or use flutter_local_notifications
      // to display a system-style notification while the app is open
    });
  }

  static void reset() {
    _initialized = false;
  }
}
