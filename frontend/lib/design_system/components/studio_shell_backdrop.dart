import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Shared ambient backdrop for the studio shell.
class StudioShellBackdrop extends StatelessWidget {
  const StudioShellBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final studio = StudioColors.of(context);
    final tokens = StudioTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: studio.shellBackdrop),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _StudioShellBackdropPainter(
                  gridColor: tokens.surfaceHighlight.withValues(alpha: 0.22),
                  primaryColor: tokens.panelGlow.withValues(alpha: 0.16),
                  accentColor: tokens.panelGlowSecondary.withValues(
                    alpha: 0.12,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -160,
            left: -120,
            child: _AmbientGlow(
              size: 420,
              colors: <Color>[
                tokens.panelGlow.withValues(alpha: 0.14),
                tokens.panelGlow.withValues(alpha: 0),
              ],
            ),
          ),
          Positioned(
            top: 48,
            right: -140,
            child: _AmbientGlow(
              size: 360,
              colors: <Color>[
                tokens.panelGlowSecondary.withValues(alpha: 0.12),
                tokens.panelGlowSecondary.withValues(alpha: 0),
              ],
            ),
          ),
          Positioned(
            bottom: -220,
            left: 180,
            child: _AmbientGlow(
              size: 520,
              colors: <Color>[
                tokens.signal.withValues(alpha: 0.07),
                tokens.signal.withValues(alpha: 0),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _StudioShellBackdropPainter extends CustomPainter {
  const _StudioShellBackdropPainter({
    required this.gridColor,
    required this.primaryColor,
    required this.accentColor,
  });

  final Color gridColor;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 72.0;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final tracePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;

    final upperPath = Path()
      ..moveTo(size.width * 0.06, size.height * 0.32)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.16,
        size.width * 0.42,
        size.height * 0.46,
        size.width * 0.58,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.12,
        size.width * 0.84,
        size.height * 0.24,
        size.width,
        size.height * 0.14,
      );
    tracePaint.color = primaryColor;
    canvas.drawPath(upperPath, tracePaint);

    final lowerPath = Path()
      ..moveTo(size.width * 0.18, size.height)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.82,
        size.width * 0.50,
        size.height * 0.96,
        size.width * 0.68,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.64,
        size.width * 0.92,
        size.height * 0.76,
        size.width,
        size.height * 0.68,
      );
    tracePaint.color = accentColor;
    canvas.drawPath(lowerPath, tracePaint);

    final nodePaint = Paint()..style = PaintingStyle.fill;
    final nodes = <Offset>[
      Offset(size.width * 0.22, size.height * 0.24),
      Offset(size.width * 0.48, size.height * 0.28),
      Offset(size.width * 0.72, size.height * 0.18),
      Offset(size.width * 0.34, size.height * 0.76),
      Offset(size.width * 0.72, size.height * 0.70),
    ];
    for (var i = 0; i < nodes.length; i++) {
      nodePaint.color = i.isEven ? primaryColor : accentColor;
      canvas.drawCircle(nodes[i], 3.2, nodePaint);
      canvas.drawCircle(
        nodes[i],
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = nodePaint.color.withValues(alpha: 0.24),
      );
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = primaryColor.withValues(alpha: 0.16);
    for (var i = 0; i < 3; i++) {
      final inset = 26.0 + (i * 22);
      canvas.drawArc(
        Rect.fromLTWH(
          size.width - 240 - inset,
          size.height - 240 - inset,
          200 + inset,
          200 + inset,
        ),
        -math.pi * 0.18,
        math.pi * 0.46,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StudioShellBackdropPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
