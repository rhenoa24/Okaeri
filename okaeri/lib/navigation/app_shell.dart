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
      backgroundColor: Theme.of(context).colorScheme.surfaceDim,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 30),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed: _showAddActionSheet,
          shape: const CircleBorder(),
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(
            Icons.add,
            size: 30,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
      floatingActionButtonLocation: const _LoweredCenterDocked(20),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: Theme.of(context).colorScheme.surface),
          BottomAppBar(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                Expanded(
                  child: const SizedBox(width: 40), // space for the notch/FAB
                ),
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
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color),
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
