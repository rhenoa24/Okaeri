import 'package:flutter/material.dart';
import 'avatar_circle.dart';
import '../screens/profile/profile_screen.dart';

/// Opens a bottom sheet with the two profiles (you + partner) side by side.
/// Tapping either one pushes [ProfileScreen] for that person.
Future<void> showProfileSheet(
  BuildContext context, {
  required String myId,
  required String myName,
  String? myPhotoBase64,
  required String partnerId,
  required String partnerName,
  String? partnerPhotoBase64,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProfileSheetItem(
                label: myName.isEmpty ? 'You' : myName,
                photoBase64: myPhotoBase64,
                kind: AvatarKind.me,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(uid: myId, isMe: true),
                    ),
                  );
                },
              ),
              _ProfileSheetItem(
                label: partnerName.isEmpty ? 'Partner' : partnerName,
                photoBase64: partnerPhotoBase64,
                kind: AvatarKind.partner,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(uid: partnerId, isMe: false),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProfileSheetItem extends StatelessWidget {
  final String label;
  final String? photoBase64;
  final AvatarKind kind;
  final VoidCallback onTap;

  const _ProfileSheetItem({
    required this.label,
    required this.photoBase64,
    required this.kind,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarCircle(
              base64Image: photoBase64,
              name: label,
              size: 72,
              kind: kind,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
