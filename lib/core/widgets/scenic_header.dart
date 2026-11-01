import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The calm landscape hero band, after the co-founder's mockups: soft sky,
/// layered sage hills, still water. Used sparingly — Home and today's verse —
/// so scrolling screens keep the plain cream background and full contrast.
///
/// The landscape is painted rather than a photo: no asset weight on web, no
/// licensing, crisp at any width, and it always renders offline. Text sits on
/// a frosted cream panel, never directly on the scene, so it stays readable
/// whatever the scene does.
class ScenicHeader extends StatelessWidget {
  const ScenicHeader({
    required this.child,
    this.minHeight = 180,
    super.key,
  });

  /// Content shown on the frosted panel at the bottom of the band.
  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge + 4),
      child: CustomPaint(
        painter: _LandscapePainter(scheme),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space4,
              AppTheme.space6 + AppTheme.space5,
              AppTheme.space4,
              AppTheme.space4,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space4),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sage = scheme.primary;

    // Sky: pale sage into warm cream at the horizon.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(scheme.primaryContainer, scheme.surface, 0.2)!,
            scheme.tertiaryContainer,
          ],
        ).createShader(Offset.zero & size),
    );

    Path hill(double baseline, List<double> peaks) {
      final path = Path()..moveTo(0, h * baseline);
      final step = w / (peaks.length - 1);
      for (var i = 1; i < peaks.length; i++) {
        final x0 = step * (i - 1);
        final x1 = step * i;
        path.cubicTo(
          x0 + step / 2, h * peaks[i - 1],
          x0 + step / 2, h * peaks[i],
          x1, h * peaks[i],
        );
      }
      return path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }

    // Far, middle and near hills, each a deeper sage.
    canvas.drawPath(
      hill(0.42, [0.42, 0.30, 0.38, 0.26, 0.36]),
      Paint()..color = Color.lerp(sage, scheme.surface, 0.72)!,
    );
    canvas.drawPath(
      hill(0.50, [0.52, 0.44, 0.40, 0.48, 0.42]),
      Paint()..color = Color.lerp(sage, scheme.surface, 0.52)!,
    );
    canvas.drawPath(
      hill(0.60, [0.58, 0.62, 0.54, 0.60, 0.66]),
      Paint()..color = Color.lerp(sage, scheme.surface, 0.30)!,
    );

    // Still water across the foreground, reflecting the sky.
    final water = Rect.fromLTWH(0, h * 0.70, w, h * 0.30);
    canvas.drawRect(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(scheme.primaryContainer, scheme.surface, 0.1)!,
            Color.lerp(sage, scheme.surface, 0.55)!,
          ],
        ).createShader(water),
    );
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
