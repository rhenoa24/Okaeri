import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoadingName = false;
  bool _isLoadingPassword = false;
  String? _nameMessage;
  String? _passwordMessage;

  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await _userService.getDisplayName(uid);
    _nameController.text = name;
    setState(() {});
  }

  Future<void> _saveName() async {
    setState(() {
      _isLoadingName = true;
      _nameMessage = null;
    });
    final error = await _userService.updateDisplayName(
      uid,
      _nameController.text,
    );
    setState(() {
      _isLoadingName = false;
      _nameMessage = error ?? 'Saved!';
    });
  }

  Future<void> _savePassword() async {
    setState(() {
      _isLoadingPassword = true;
      _passwordMessage = null;
    });
    final error = await _userService.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    setState(() {
      _isLoadingPassword = false;
      _passwordMessage = error ?? 'Password updated!';
    });
    if (error == null) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Display name',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          if (_nameMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _nameMessage!,
              style: TextStyle(
                color: _nameMessage == 'Saved!' ? Colors.green : Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoadingName ? null : _saveName,
            child: _isLoadingName
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Name'),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 20),

          const Text(
            'Change password',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              border: OutlineInputBorder(),
            ),
          ),
          if (_passwordMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _passwordMessage!,
              style: TextStyle(
                color: _passwordMessage == 'Password updated!'
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoadingPassword ? null : _savePassword,
            child: _isLoadingPassword
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update Password'),
          ),
        ],
      ),
    );
  }
}
