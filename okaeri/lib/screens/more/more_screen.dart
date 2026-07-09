import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../profile/profile_screen.dart';
import '../../theme/theme_preview.dart';
import '../../theme/theme_controller.dart';

class MoreScreen extends StatefulWidget {
  final String coupleId;
  const MoreScreen({super.key, required this.coupleId});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile & Settings'),
            subtitle: const Text('Display name, password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme Preview'),
            subtitle: const Text('Preview generated Material 3 colors'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemePreviewScreen()),
              );
            },
          ),

          const Divider(),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text("Theme"),
                subtitle: Text(switch (mode) {
                  ThemeMode.system => "Follow system",
                  ThemeMode.light => "Light",
                  ThemeMode.dark => "Dark",
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (context) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.phone_android),
                              title: const Text("Follow system"),
                              trailing: mode == ThemeMode.system
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () {
                                ThemeController.setThemeMode(ThemeMode.system);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.light_mode),
                              title: const Text("Light"),
                              trailing: mode == ThemeMode.light
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () {
                                ThemeController.setThemeMode(ThemeMode.light);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.dark_mode),
                              title: const Text("Dark"),
                              trailing: mode == ThemeMode.dark
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () {
                                ThemeController.setThemeMode(ThemeMode.dark);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
    );
  }
}
