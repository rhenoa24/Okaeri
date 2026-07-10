import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/pairing/pairing_screen.dart';
import 'app_shell.dart';
import '../services/notification_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // Call this right before returning any "real" destination screen
  // (Login, Pairing, or AppShell). Safe to call more than once — it's a
  // no-op after the first successful removal — so every terminal branch
  // below can just call it unconditionally.
  Widget _reveal(Widget child) {
    FlutterNativeSplash.remove();
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final coupleService = CoupleService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          // Splash is still covering the screen here — nothing to reveal yet.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) return _reveal(const LoginScreen());

        NotificationService.initialize(user.uid);

        return StreamBuilder<String?>(
          stream: coupleService.watchCoupleId(user.uid),
          builder: (context, coupleIdSnapshot) {
            if (coupleIdSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final coupleId = coupleIdSnapshot.data;
            if (coupleId == null) return _reveal(const PairingScreen());

            return StreamBuilder<Map<String, dynamic>?>(
              stream: coupleService.watchCouple(coupleId),
              builder: (context, coupleSnapshot) {
                if (coupleSnapshot.connectionState == ConnectionState.waiting &&
                    !coupleSnapshot.hasData) {
                  // First couple snapshot hasn't arrived yet — keep the
                  // splash up instead of momentarily flashing PairingScreen
                  // (members would read as empty until data arrives).
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final members = List<String>.from(
                  coupleSnapshot.data?['members'] ?? [],
                );

                if (members.length < 2) {
                  // Resume showing the existing code, don't let them regenerate
                  final existingCode =
                      coupleSnapshot.data?['inviteCode'] as String?;
                  return _reveal(
                    PairingScreen(existingInviteCode: existingCode),
                  );
                }

                return _reveal(AppShell(coupleId: coupleId));
              },
            );
          },
        );
      },
    );
  }
}
