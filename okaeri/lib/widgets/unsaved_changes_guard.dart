import 'package:flutter/material.dart';

/// Mixin for editor screens that should warn the user before discarding
/// unsaved changes.
///
/// Usage:
/// 1. `class _MyEditorState extends State<MyEditor> with UnsavedChangesGuard<MyEditor> { ... }`
/// 2. Implement `hasUnsavedChanges` by comparing current field values
///    against a snapshot taken in `initState` (and refreshed after a
///    successful save, so popping right after saving doesn't warn).
/// 3. In `build`, wrap the screen's root widget:
///    `return guardUnsavedChanges(Scaffold(...));`
/// 4. Make sure any `TextEditingController` / `QuillController` that feeds
///    `hasUnsavedChanges` calls `setState` on change (e.g.
///    `controller.addListener(() => setState(() {}))`), otherwise the
///    guard won't notice edits until something else triggers a rebuild.
///
/// Both the system back gesture and a default `AppBar` back button route
/// through `Navigator.pop`, so both are covered by this one guard.
mixin UnsavedChangesGuard<T extends StatefulWidget> on State<T> {
  /// Subclasses report whether there's currently something to lose.
  bool get hasUnsavedChanges;

  Widget guardUnsavedChanges(Widget child) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscard();
        if (shouldDiscard && mounted) {
          Navigator.pop(context);
        }
      },
      child: child,
    );
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes that will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Discard',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}