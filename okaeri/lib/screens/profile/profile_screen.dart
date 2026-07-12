import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/user_service.dart';
import '../../widgets/avatar_circle.dart';

/// Shows and edits a single person's profile (Display Name + photo).
/// [isMe] only affects the title shown — both your own and your partner's
/// profile are editable here.
class ProfileScreen extends StatefulWidget {
  final String uid;
  final bool isMe;

  const ProfileScreen({super.key, required this.uid, required this.isMe});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _photoBase64;
  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // NOTE: watchDisplayName and watchPhotoBase64 both exist on
    // UserService now — same shape, different field.
    final name = await _userService.watchDisplayName(widget.uid).first;
    final photo = await _userService.watchPhotoBase64(widget.uid).first;

    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _photoBase64 = photo;
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    setState(() {
      _photoBase64 = base64Encode(bytes);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    await _userService.updateProfile(
      uid: widget.uid,
      displayName: _nameController.text.trim(),
      photoBase64: _photoBase64,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMe ? 'My Profile' : "$_partnerTitle's Profile"),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarCircle(
                        base64Image: _photoBase64,
                        name: _nameController.text,
                        size: 120,
                        kind: widget.isMe ? AvatarKind.me : AvatarKind.partner,
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: InkWell(
                          onTap: _pickPhoto,
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Display Name',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter display name',
                  ),
                ),
                const SizedBox(height: 24),
                // More profile fields (bio, anniversary role, etc.) go here.
              ],
            ),
    );
  }

  String get _partnerTitle =>
      _nameController.text.isEmpty ? 'Partner' : _nameController.text;
}
