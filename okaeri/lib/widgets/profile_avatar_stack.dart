import 'package:flutter/material.dart';
import 'avatar_circle.dart';

/// Two overlapping profile circles (partner behind, "me" in front),
/// like a little Venn diagram. Tapping opens the profile picker.
class ProfileAvatarStack extends StatelessWidget {
  final String myName;
  final String? myPhotoBase64;
  final String partnerName;
  final String? partnerPhotoBase64;
  final VoidCallback onTap;
  final double size;
  final double overlap;

  const ProfileAvatarStack({
    super.key,
    required this.myName,
    required this.myPhotoBase64,
    required this.partnerName,
    required this.partnerPhotoBase64,
    required this.onTap,
    this.size = 34,
    this.overlap = 14,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor =
        Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          width: size * 2 - overlap,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                child: AvatarCircle(
                  base64Image: partnerPhotoBase64,
                  name: partnerName.isEmpty ? 'Partner' : partnerName,
                  size: size,
                  borderWidth: 2,
                  borderColor: ringColor,
                  kind: AvatarKind.partner,
                ),
              ),
              Positioned(
                left: size - overlap,
                child: AvatarCircle(
                  base64Image: myPhotoBase64,
                  name: myName.isEmpty ? 'You' : myName,
                  size: size,
                  borderWidth: 2,
                  borderColor: ringColor,
                  kind: AvatarKind.me,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
