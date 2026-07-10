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
      primary: fidelityScheme.primaryContainer,
      onPrimary: fidelityScheme.onPrimaryContainer,

      surface: monochromeScheme.surfaceContainerLowest,
      onSurface: monochromeScheme.onSurface,
      onSurfaceVariant: monochromeScheme.onSurfaceVariant,

      surfaceContainerLowest: monochromeScheme.surfaceContainerLowest,
      surfaceContainerLow: monochromeScheme.surfaceContainerLow,
      surfaceContainer: monochromeScheme.surfaceContainer,
      surfaceContainerHigh: monochromeScheme.surfaceContainerHigh,
      surfaceContainerHighest: monochromeScheme.surfaceContainerHighest,

      surfaceBright: monochromeScheme.surfaceBright,
      outline: monochromeScheme.outline,
      outlineVariant: monochromeScheme.outlineVariant,

      surfaceDim: brightness == Brightness.light
          ? fidelityScheme
                .surface // custom light-only shadow
          : monochromeScheme.surfaceDim,

      // keep fidelity's primary/secondary/tertiary/error roles as-is,
      // since those are the ones you want the seed color's true hue in
      error: Colors.red,
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final scheme = _buildHybridScheme(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceDim,
        elevation: 1,
        shadowColor: scheme.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.surfaceContainer,
        thickness: 1,
      ),

      tabBarTheme: TabBarThemeData(
        dividerColor: scheme.surfaceDim,
        dividerHeight: 1,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceDim,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: scheme.onPrimary,
        dayForegroundColor: WidgetStatePropertyAll(scheme.onSurface),
        todayForegroundColor: WidgetStatePropertyAll(scheme.onSurface),
        todayBorder: BorderSide.none,
        todayBackgroundColor: WidgetStatePropertyAll(
          scheme.surfaceContainerHigh,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceDim,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceDim,
        hourMinuteColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainer;
        }),
        dialBackgroundColor: scheme.surfaceContainer,
        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainer;
        }),
        dayPeriodBorderSide: BorderSide.none,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
      ),
    );
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
}
