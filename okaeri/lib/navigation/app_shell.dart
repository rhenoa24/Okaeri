import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/home/home_screen.dart';
import '../screens/notes/notes_screen.dart';
import '../screens/notes/note_editor_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/calendar/event_editor_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/calendar/plan_editor_screen.dart';

class AppShell extends StatefulWidget {
  final String coupleId;
  const AppShell({super.key, required this.coupleId});

  @override
  State<AppShell> createState() => _AppShellState();
}

// centerDocked doesn't expose a way to nudge the FAB's vertical position,
// so this wraps it and pushes the resulting offset down by a few pixels.
class _LoweredCenterDocked extends FloatingActionButtonLocation {
  const _LoweredCenterDocked(this.dy);
  final double dy;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset original = FloatingActionButtonLocation.centerDocked.getOffset(
      scaffoldGeometry,
    );
    return Offset(original.dx, original.dy + dy);
  }
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex =
      0; // maps to _screens below (the + button isn't a screen)

  late final List<Widget> _screens = [
    HomeScreen(coupleId: widget.coupleId),
    NotesScreen(coupleId: widget.coupleId),
    CalendarScreen(coupleId: widget.coupleId),
    MoreScreen(coupleId: widget.coupleId),
  ];

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.note_add_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  'New Note',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Capture thoughts, ideas, or memories.'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(
                        coupleId: widget.coupleId,
                        initialVisibility: 'shared',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.favorite_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  'New Event',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Remember special dates and moments.'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventEditorScreen(
                        coupleId: widget.coupleId,
                        initialDate: DateTime.now(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.alarm,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  'New Plan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Organize dates, activities, and schedules.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanEditorScreen(
                        coupleId: widget.coupleId,
                        initialDate: DateTime.now(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),
                BottomAppBar(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  child: Row(
                    children: [
                      Expanded(
                        child: _navItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home,
                          label: 'Home',
                          index: 0,
                        ),
                      ),
                      Expanded(
                        child: _navItem(
                          icon: Icons.edit_note_outlined,
                          activeIcon: Icons.edit_note,
                          label: 'Notes',
                          index: 1,
                        ),
                      ),

                      // Space for center button — no icon (blank space keeps
                      // the label aligned with the others) and no index, since
                      // this area is just visual space under the FAB, not a
                      // real tab.
                      Expanded(child: _navItem(label: 'Create')),

                      Expanded(
                        child: _navItem(
                          icon: Icons.calendar_today_outlined,
                          activeIcon: Icons.calendar_today,
                          label: 'Calendar',
                          index: 2,
                        ),
                      ),
                      Expanded(
                        child: _navItem(
                          icon: Icons.more_horiz,
                          activeIcon: Icons.more_horiz,
                          label: 'More',
                          index: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Positioned(
              top: -25,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Material(
                  color: Theme.of(context).colorScheme.primary,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _showAddActionSheet,
                    child: Icon(
                      Icons.add,
                      size: 30,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // icon/activeIcon/index are optional so this can also render the
  // placeholder "space for center button" slot: no icon (just blank space
  // the same size as a real icon, so the label row stays aligned) and no
  // tap behavior, since that area sits under the floating circle button.
  Widget _navItem({
    IconData? icon,
    IconData? activeIcon,
    required String label,
    int? index,
  }) {
    final isSelected = index != null && _selectedIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;

    final iconWidget = icon == null
        ? const SizedBox(height: 24)
        : Icon(isSelected ? (activeIcon ?? icon) : icon, color: color);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: index == null ? null : () => _onTabTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
