import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/pairing/pairing_screen.dart';
import 'app_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final coupleService = CoupleService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<String?>(
          stream: coupleService.watchCoupleId(user.uid),
          builder: (context, coupleIdSnapshot) {
            if (coupleIdSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final coupleId = coupleIdSnapshot.data;
            if (coupleId == null) return const PairingScreen();

            return StreamBuilder<Map<String, dynamic>?>(
              stream: coupleService.watchCouple(coupleId),
              builder: (context, coupleSnapshot) {
                final members = List<String>.from(
                  coupleSnapshot.data?['members'] ?? [],
                );

                if (members.length < 2) {
                  // Resume showing the existing code, don't let them regenerate
                  final existingCode =
                      coupleSnapshot.data?['inviteCode'] as String?;
                  return PairingScreen(existingInviteCode: existingCode);
                }

                return AppShell(coupleId: coupleId);
              },
            );
          },
        );
      },
    );
  }
}
