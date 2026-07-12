import 'dart:convert';
import 'package:flutter/material.dart';

/// Who this avatar represents — drives the placeholder color when there's
/// no photo yet.
enum AvatarKind { me, partner, neutral }

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

    if (base64Image != null && base64Image!.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Image!);
        circle = CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.transparent,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        // Malformed base64 — fall back to initials rather than crash.
        circle = _initialsCircle(context);
      }
    } else {
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
