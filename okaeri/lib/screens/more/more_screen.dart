import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_settings_screen.dart';
// import '../../theme/theme_preview.dart';
import '../../theme/theme_controller.dart';
import '../period_tracker/period_tracker_screen.dart';

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
                MaterialPageRoute(
                  builder: (_) => const ProfileSettingsScreen(),
                ),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text('Period Tracker'),
            subtitle: const Text('Shared cycle log & predictions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PeriodTrackerScreen(coupleId: widget.coupleId),
                ),
              );
            },
          ),

          // const Divider(),

          // ListTile(
          //   leading: const Icon(Icons.palette_outlined),
          //   title: const Text('Theme Preview'),
          //   subtitle: const Text('Preview generated Material 3 colors'),
          //   trailing: const Icon(Icons.chevron_right),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const ThemePreviewScreen()),
          //     );
          //   },
          // ),
          const Divider(),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return ListTile(
                leading: Icon(switch (mode) {
                  ThemeMode.system => Icons.phone_android,
                  ThemeMode.light => Icons.light_mode,
                  ThemeMode.dark => Icons.dark_mode,
                }),
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
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
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
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
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
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
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
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Log out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
    );
  }
}
