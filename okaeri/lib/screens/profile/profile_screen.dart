import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/profile_details.dart';
import '../../models/user_note.dart';
import '../../services/user_service.dart';
import '../../widgets/avatar_circle.dart';
import 'profile_note_editor_screen.dart';
import 'widgets/basic_info_tab.dart';
import 'widgets/note_collection_tab.dart';
import 'widgets/profile_header.dart';
import '../../services/profile_notes_service.dart';

/// Shows a person's profile: avatar + display name (toggle between a plain
/// read-only view and an edit view), plus three tabs — Basic Info,
/// Favorites, and Notes. [isMe] only affects copy (e.g. the empty states);
/// both your own and your partner's profile are editable here.
class ProfileScreen extends StatefulWidget {
  final String uid;
  final bool isMe;

  const ProfileScreen({super.key, required this.uid, required this.isMe});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final ProfileNotesService _profileNotesService = ProfileNotesService();

  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late final TabController _tabController;

  bool _loading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  int _tabIndex = 0;

  String? _photoBase64;
  ProfileDetails _details = const ProfileDetails();

  // Snapshots to revert to if the user cancels out of edit mode.
  String _savedName = '';
  String? _savedPhotoBase64;
  ProfileDetails _savedDetails = const ProfileDetails();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() => _tabIndex = _tabController.index);
      });
    _load();
  }

  Future<void> _load() async {
    // NOTE: watchDisplayName, watchPhotoBase64 already exist on
    // UserService. watchProfileDetails is scaffolding — add it alongside
    // them (same doc, extra fields) whenever you're ready.
    final name = await _userService.watchDisplayName(widget.uid).first;
    final photo = await _userService.watchPhotoBase64(widget.uid).first;
    // final details = await _userService.watchProfileDetails(widget.uid).first;

    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _photoBase64 = photo;
      // _details = details;
      _loading = false;
    });
  }

  void _enterEditMode() {
    // Snapshot current values so "cancel" can restore them.
    _savedName = _nameController.text;
    _savedPhotoBase64 = _photoBase64;
    _savedDetails = _details;
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() {
      _nameController.text = _savedName;
      _photoBase64 = _savedPhotoBase64;
      _details = _savedDetails;
      _isEditing = false;
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
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    await _userService.updateProfile(
      uid: widget.uid,
      displayName: _nameController.text.trim(),
      photoBase64: _photoBase64,
    );
    // TODO: await _userService.updateProfileDetails(uid: widget.uid, details: _details);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
  }

  Future<void> _openNote(NoteCategory category, {UserNote? note}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteEditorScreen(uid: widget.uid, category: category, note: note),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showComposeFab = _tabIndex == 1 || _tabIndex == 2;
    final composeCategory = _tabIndex == 1
        ? NoteCategory.favorite
        : NoteCategory.note;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: _isSaving ? null : _cancelEdit,
                ),
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
                  tooltip: 'Save',
                  onPressed: _isSaving ? null : _save,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: _enterEditMode,
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ProfileHeader(
                  photoBase64: _photoBase64,
                  kind: widget.isMe ? AvatarKind.me : AvatarKind.partner,
                  isEditing: _isEditing,
                  nameController: _nameController,
                  onPickPhoto: _pickPhoto,
                ),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('Basic Info'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border, size: 18),
                          SizedBox(width: 6),
                          Text('Favorites'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sticky_note_2_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('Notes'),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      BasicInfoTab(
                        isEditing: _isEditing,
                        details: _details,
                        onChanged: (d) => setState(() => _details = d),
                      ),

                      _buildNotesTab(
                        category: NoteCategory.favorite,
                        emptyLabel: widget.isMe
                            ? 'Nothing saved yet — tap + to add a favorite.'
                            : 'No favorites added for $_displayName yet.',
                      ),

                      _buildNotesTab(
                        category: NoteCategory.note,
                        emptyLabel: widget.isMe
                            ? 'Nothing written yet — tap + to add a note.'
                            : 'No notes written about $_displayName yet.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: (!_loading && showComposeFab)
          ? FloatingActionButton(
              onPressed: () => _openNote(composeCategory),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildNotesTab({
    required NoteCategory category,
    required String emptyLabel,
  }) {
    return StreamBuilder<List<UserNote>>(
      stream: _profileNotesService.watchNotes(widget.uid, category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        return NoteCollectionTab(
          category: category,
          emptyLabel: emptyLabel,
          notes: snapshot.data ?? const [],
          onTapNote: (n) => _openNote(category, note: n),
        );
      },
    );
  }

  String get _displayName =>
      _nameController.text.isEmpty ? 'them' : _nameController.text;
}
