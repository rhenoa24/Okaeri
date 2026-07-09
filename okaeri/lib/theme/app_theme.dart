import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFFD22C32);

  static ColorScheme _buildHybridScheme(Brightness brightness) {
    final fidelityScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final monochromeScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    );

    // Start from fidelity, override just the surface-related roles
    // with monochrome's neutral values.
    return fidelityScheme.copyWith(
      surface: monochromeScheme.surface,
      onSurface: monochromeScheme.onSurface,
      onSurfaceVariant: monochromeScheme.onSurfaceVariant,

      surfaceContainerLowest: monochromeScheme.surfaceContainerLowest,
      surfaceContainerLow: monochromeScheme.surfaceContainerLow,
      surfaceContainer: monochromeScheme.surfaceContainer,
      surfaceContainerHigh: monochromeScheme.surfaceContainerHigh,
      surfaceContainerHighest: monochromeScheme.surfaceContainerHighest,

      surfaceDim: monochromeScheme.surfaceDim,
      surfaceBright: monochromeScheme.surfaceBright,

      outline: monochromeScheme.outline,
      outlineVariant: monochromeScheme.outlineVariant,

      // keep fidelity's primary/secondary/tertiary/error roles as-is,
      // since those are the ones you want the seed color's true hue in
    );
  }

  static ThemeData get darkTheme {
    final scheme = _buildHybridScheme(Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // ...rest of your theme config (text theme, appBarTheme, etc.)
    );
  }

  static ThemeData get lightTheme {
    final scheme = _buildHybridScheme(Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}
