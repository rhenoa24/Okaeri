import 'package:flutter/material.dart';
import '../screens/home/home_screen.dart';
import '../screens/notes/notes_screen.dart';
import '../screens/notes/note_editor_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/calendar/event_editor_screen.dart';
import '../screens/more/more_screen.dart';

class AppShell extends StatefulWidget {
  final String coupleId;
  const AppShell({super.key, required this.coupleId});

  @override
  State<AppShell> createState() => _AppShellState();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('New Note'),
                subtitle: const Text('Capture thoughts, ideas, or memories.'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(
                        coupleId: widget.coupleId,
                        initialVisibility:
                            'shared', // default; user can toggle in editor
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('New Event'),
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
                leading: const Icon(Icons.alarm),
                title: const Text('New Plan'),
                subtitle: const Text(
                  'Organize dates, activities, and schedules.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('New Plan')),
                        body: const Center(
                          child: Text('Plan editor coming soon'),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddActionSheet,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              index: 0,
            ),
            _navItem(
              icon: Icons.edit_note_outlined,
              activeIcon: Icons.edit_note,
              label: 'Notes',
              index: 1,
            ),
            const SizedBox(width: 40), // space for the notch/FAB
            _navItem(
              icon: Icons.calendar_today_outlined,
              activeIcon: Icons.calendar_today,
              label: 'Calendar',
              index: 2,
            ),
            _navItem(
              icon: Icons.more_horiz,
              activeIcon: Icons.more_horiz,
              label: 'More',
              index: 3,
            ),
          ],
        ),
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
        : Colors.grey;

    return InkWell(
      onTap: () => _onTabTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
