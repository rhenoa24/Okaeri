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
///
/// `hasUnsavedChanges` is evaluated fresh at the moment the user tries to
/// leave, not cached from the last rebuild — so there's no need to wire up
/// controller listeners just to keep the guard in sync. (Don't add those:
/// a `setState` on every keystroke forces controllers like Quill's to
/// rebuild constantly, which can drop focus and make typing feel broken.)
///
/// Both the system back gesture and a default `AppBar` back button route
/// through `Navigator.pop`/`maybePop`, so both are covered by this one
/// guard.
mixin UnsavedChangesGuard<T extends StatefulWidget> on State<T> {
  /// Subclasses report whether there's currently something to lose.
  bool get hasUnsavedChanges;

  Widget guardUnsavedChanges(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!hasUnsavedChanges) {
          if (mounted) Navigator.pop(context);
          return;
        }

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
            child: Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
