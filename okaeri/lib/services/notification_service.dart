import 'package:firebase_messaging/firebase_messaging.dart';
import 'user_service.dart';
import 'local_notification_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final UserService _userService = UserService();

  static bool _initialized = false;

  static Future<void> initialize(String uid) async {
    if (_initialized) return;
    _initialized = true;

    // Ask permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Set up local notifications (for showing banners while app is open)
    await LocalNotificationService.initialize();

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
      final title = message.notification?.title ?? 'Okaeri';
      final body = message.notification?.body ?? '';
      LocalNotificationService.show(title: title, body: body);
    });
  }

  static void reset() {
    _initialized = false;
  }
}
