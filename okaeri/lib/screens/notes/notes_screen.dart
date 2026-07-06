import 'package:flutter/material.dart';

class NotesScreen extends StatelessWidget {
  final String coupleId;
  const NotesScreen({super.key, required this.coupleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '📝 Our Room & 🌙 My Corner\ncoming soon',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
