import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/core/theme/app_theme.dart';
import 'package:trueanchor/core/widgets/app_widgets.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('AppTheme palette meets WCAG AA for text', () {
    final s = AppTheme.colorScheme;
    final pairs = <String, (Color, Color)>{
      'onSurface / surface': (s.onSurface, s.surface),
      'onSurface / card (surfaceContainerLow)':
          (s.onSurface, s.surfaceContainerLow),
      'onSurfaceVariant / surface': (s.onSurfaceVariant, s.surface),
      'onSurfaceVariant / card (surfaceContainerLow)':
          (s.onSurfaceVariant, s.surfaceContainerLow),
      'onSurfaceVariant / surfaceContainerHighest':
          (s.onSurfaceVariant, s.surfaceContainerHighest),
      'onPrimary / primary': (s.onPrimary, s.primary),
      'primary / surface (links, section headers)': (s.primary, s.surface),
      'onPrimaryContainer / primaryContainer':
          (s.onPrimaryContainer, s.primaryContainer),
      'secondary / surface (Inward header)': (s.secondary, s.surface),
      'onSecondaryContainer / secondaryContainer':
          (s.onSecondaryContainer, s.secondaryContainer),
      'tertiary / surface (Outward header)': (s.tertiary, s.surface),
      'onTertiaryContainer / tertiaryContainer':
          (s.onTertiaryContainer, s.tertiaryContainer),
    };

    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      test(name, () {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('feedInsetsFor', () {
    test('keeps a 16px gutter on a phone', () {
      final insets = feedInsetsFor(390);
      expect(insets.left, AppTheme.space4);
      expect(insets.right, AppTheme.space4);
    });

    test('centres a 720px column on desktop', () {
      final insets = feedInsetsFor(1200);
      expect(insets.left, (1200 - AppTheme.maxFeedWidth) / 2);
      expect(insets.right, insets.left);
      expect(1200 - insets.horizontal, AppTheme.maxFeedWidth);
    });

    test('passes FAB clearance through to the bottom', () {
      expect(
        feedInsetsFor(390, bottom: AppTheme.fabClearance).bottom,
        AppTheme.fabClearance,
      );
    });
  });
}
