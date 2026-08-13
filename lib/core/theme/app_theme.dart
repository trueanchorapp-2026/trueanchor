import 'package:flutter/material.dart';

/// Material 3, light only for V1 (CLAUDE.md: "Light mode initially").
abstract final class AppTheme {
  /// Single source of truth for spacing so screens stay visually consistent.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;

  /// Forms and content columns stop widening past this on desktop web.
  static const maxContentWidth = 560.0;

  static const _seed = Color(0xFF2E5A88);

  /// For a filled button that must size to its label — anything inside a [Row]
  /// or a [ListTile]'s leading/trailing slot.
  ///
  /// The app-wide [FilledButtonThemeData] sets `Size.fromHeight(48)`, and
  /// `Size.fromHeight` means an *infinite* minimum width. In a Column that
  /// clamps down to the parent's width and the button simply fills the line,
  /// which is the convention every form page relies on. A Row lays its
  /// non-flex children out with `maxWidth: infinity`, so there is nothing to
  /// clamp against and layout asserts with "BoxConstraints forces an infinite
  /// width". A ListTile does clamp — to the tile's own width — so the button
  /// swallows the row and the tile asserts "Trailing widget consumes the
  /// entire tile width". Override the minimum width in both places rather
  /// than fighting the parent.
  static final inlineButtonStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 40),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Full-width by default: `fromHeight` leaves the minimum width
          // infinite. Buttons placed in a Row must use [inlineButtonStyle].
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
    );
  }
}
