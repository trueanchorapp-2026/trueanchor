import 'package:flutter/material.dart';

/// Material 3, light only for V1 (CLAUDE.md: "Light mode initially").
///
/// "Still Waters" palette: sage, warm cream and sand, matching the
/// co-founder's mockups. Every role is set explicitly rather than left to
/// [ColorScheme.fromSeed], whose tonal math drifts away from the mockup hues.
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

  /// Feeds and list pages stop widening past this on desktop web.
  static const maxFeedWidth = 720.0;

  /// Bottom padding for a list that sits under a FAB, so the last item can
  /// scroll clear of it.
  static const fabClearance = 96.0;

  static const radiusSmall = 8.0;
  static const radiusMedium = 12.0;
  static const radiusLarge = 16.0;

  /// Serif display face for headings and Scripture.
  static const serifFamily = 'Lora';

  /// Sans body face for everything else.
  static const sansFamily = 'Inter';

  static const _sage = Color(0xFF4E6E66);

  /// The explicit palette. Public so tests can assert contrast on it.
  static final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: _sage,
    brightness: Brightness.light,
  ).copyWith(
    primary: _sage,
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFD5E3DC),
    onPrimaryContainer: const Color(0xFF123029),
    secondary: const Color(0xFF5F6F58),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFE3E8D9),
    onSecondaryContainer: const Color(0xFF283321),
    tertiary: const Color(0xFF8A6631),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: const Color(0xFFF3E4CB),
    onTertiaryContainer: const Color(0xFF3B2A0E),
    surface: const Color(0xFFFAF6EE),
    onSurface: const Color(0xFF1F2B28),
    onSurfaceVariant: const Color(0xFF56625D),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFF5EFE3),
    surfaceContainer: const Color(0xFFEFE8DA),
    surfaceContainerHigh: const Color(0xFFE9E1D1),
    surfaceContainerHighest: const Color(0xFFE3DAC8),
    outline: const Color(0xFF7D8A84),
    outlineVariant: const Color(0xFFE2D8C6),
    surfaceTint: Colors.transparent,
  );

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
    textStyle: const TextStyle(
      fontFamily: sansFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(
          fontFamily: sansFamily,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    TextStyle? serif(TextStyle? style, {FontWeight? weight}) => style?.copyWith(
          fontFamily: serifFamily,
          fontWeight: weight ?? FontWeight.w600,
          letterSpacing: 0,
        );

    return base.copyWith(
      displayLarge: serif(base.displayLarge, weight: FontWeight.w400),
      displayMedium: serif(base.displayMedium, weight: FontWeight.w400),
      displaySmall: serif(base.displaySmall, weight: FontWeight.w400),
      headlineLarge: serif(base.headlineLarge),
      headlineMedium: serif(base.headlineMedium),
      headlineSmall: serif(base.headlineSmall),
      titleLarge: serif(base.titleLarge),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
    );
  }

  static ThemeData light() {
    final scheme = colorScheme;
    final text = _textTheme(scheme);
    final mediumShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: sansFamily,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Full-width by default: `fromHeight` leaves the minimum width
          // infinite. Buttons placed in a Row must use [inlineButtonStyle].
          minimumSize: const Size.fromHeight(48),
          shape: mediumShape,
          textStyle: const TextStyle(
            fontFamily: sansFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: mediumShape,
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(
            fontFamily: sansFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: mediumShape,
          textStyle: const TextStyle(
            fontFamily: sansFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        labelStyle: text.labelLarge,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        tabAlignment: TabAlignment.start,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: mediumShape,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge + 4),
        ),
        titleTextStyle: text.headlineSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: mediumShape,
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle:
            text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
    );
  }
}
