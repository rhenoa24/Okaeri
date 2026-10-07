import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Who this avatar represents — drives the placeholder color when there's
/// no photo yet.
enum AvatarKind { me, partner, neutral }

// Caches decoded photo bytes keyed by the base64 string so repeated
// rebuilds (e.g. from an unrelated setState like a tab change) reuse the
// same Uint8List instance instead of decoding a fresh one each time.
// MemoryImage compares `bytes` by identity, so a fresh Uint8List on every
// build makes Flutter treat it as a brand-new image and reload it —
// that's what causes the flicker. A single-entry cache is enough since
// only one avatar is decoded at a time on this screen; swap for an LRU
// cache if this widget ever needs to render many distinct avatars at once.
String? _cachedBase64;
Uint8List? _cachedBytes;

Uint8List? _decodeCached(String base64Image) {
  if (_cachedBase64 == base64Image) return _cachedBytes;
  try {
    final bytes = base64Decode(base64Image);
    _cachedBase64 = base64Image;
    _cachedBytes = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// A circular avatar that shows a base64-encoded photo if one is provided,
/// otherwise falls back to a colored circle with the person's initials.
class AvatarCircle extends StatelessWidget {
  final String? base64Image;
  final String name;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final AvatarKind kind;

  const AvatarCircle({
    super.key,
    this.base64Image,
    required this.name,
    this.size = 40,
    this.borderColor,
    this.borderWidth = 0,
    this.kind = AvatarKind.neutral,
  });

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color _bgColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (kind) {
      case AvatarKind.me:
        return scheme.primary;
      case AvatarKind.partner:
        return scheme.secondary;
      case AvatarKind.neutral:
        return scheme.outlineVariant;
    }
  }

  Color _fgColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (kind) {
      case AvatarKind.me:
        return scheme.onPrimary;
      case AvatarKind.partner:
        return scheme.onSecondary;
      case AvatarKind.neutral:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget circle;

    final bytes = base64Image != null && base64Image!.isNotEmpty
        ? _decodeCached(base64Image!)
        : null;

    if (bytes != null) {
      circle = CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.transparent,
        backgroundImage: MemoryImage(bytes),
      );
    } else {
      // Either no photo, or malformed base64 — fall back to initials
      // rather than crash.
      circle = _initialsCircle(context);
    }

    if (borderWidth <= 0) return circle;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Theme.of(context).scaffoldBackgroundColor,
          width: borderWidth,
        ),
      ),
      child: circle,
    );
  }

  Widget _initialsCircle(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _bgColor(context),
      child: Text(
        _initials,
        style: TextStyle(
          color: _fgColor(context),
          fontWeight: FontWeight.bold,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
