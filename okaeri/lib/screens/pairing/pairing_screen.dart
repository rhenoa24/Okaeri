import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../services/couple_service.dart';

class PairingScreen extends StatefulWidget {
  final String?
  existingInviteCode; // passed if this user already created an invite

  const PairingScreen({super.key, this.existingInviteCode});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

enum _Mode { choose, invite, join }

class _PairingScreenState extends State<PairingScreen> {
  final CoupleService _coupleService = CoupleService();
  final TextEditingController _codeController = TextEditingController();

  late _Mode _mode;
  String? _generatedCode;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Resume the waiting screen instead of showing choose buttons again
    if (widget.existingInviteCode != null) {
      _mode = _Mode.invite;
      _generatedCode = widget.existingInviteCode;
    } else {
      _mode = _Mode.choose;
    }
  }

  Future<void> _handleInvite() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final code = await _coupleService.createInvite(uid);
    setState(() {
      _generatedCode = code;
      _mode = _Mode.invite;
      _isLoading = false;
    });
  }

  Future<void> _handleJoin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final error = await _coupleService.joinWithCode(uid, _codeController.text);

    setState(() {
      _isLoading = false;
      _errorMessage = error;
    });
    // If error is null, AuthGate's stream picks up the new coupleId automatically
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _Mode.choose:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🏡',
              style: TextStyle(fontSize: 56),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect with your partner to start your shared home.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _handleInvite,
              child: const Text('Invite your Partner'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _mode = _Mode.join),
              child: const Text('Join a Home'),
            ),
          ],
        );

      case _Mode.invite:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your partner:'),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _generatedCode ?? ''));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied!')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.pink),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _generatedCode ?? '',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('(tap to copy)', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Waiting for your partner to join...'),
          ],
        );

      case _Mode.join:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter the code your partner shared:'),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 24, letterSpacing: 4),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _handleJoin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join'),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _mode = _Mode.choose),
              child: const Text('Back'),
            ),
          ],
        );
    }
  }
}
