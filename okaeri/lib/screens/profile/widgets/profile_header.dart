import 'package:flutter/material.dart';
import '../../../../../widgets/avatar_circle.dart';

/// Avatar + display name block at the top of the profile screen.
/// In edit mode: shows a camera badge over the avatar and turns the name
/// into a text field. In read mode: it's just a portrait.
class ProfileHeader extends StatelessWidget {
  final String? photoBase64;
  final AvatarKind kind;
  final bool isEditing;
  final TextEditingController nameController;
  final VoidCallback onPickPhoto;

  const ProfileHeader({
    super.key,
    required this.photoBase64,
    required this.kind,
    required this.isEditing,
    required this.nameController,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: AvatarCircle(
                  key: ValueKey(photoBase64),
                  base64Image: photoBase64,
                  name: nameController.text,
                  size: 108,
                  kind: kind,
                ),
              ),
              if (isEditing)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: InkWell(
                    onTap: onPickPhoto,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isEditing
                ? SizedBox(
                    key: const ValueKey('name-edit'),
                    width: 240,
                    child: TextField(
                      controller: nameController,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: UnderlineInputBorder(),
                        hintText: 'Display name',
                      ),
                    ),
                  )
                : Text(
                    nameController.text.isEmpty
                        ? 'Unnamed'
                        : nameController.text,
                    key: const ValueKey('name-view'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
