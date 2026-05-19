import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/tokens.dart';

/// Six-step SOP ring on project cards (0–6 completed segments).
class StudioStepProgressRing extends StatelessWidget {
  const StudioStepProgressRing({
    super.key,
    required this.completedSteps,
    this.size = 44,
    this.strokeWidth = 4,
  });

  final int completedSteps;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final done = completedSteps.clamp(0, 6);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          completed: done,
          total: 6,
          activeColor: tokens.primary,
          accentColor: tokens.accent,
          trackColor: tokens.borderSubtle,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Text(
            '$done/6',
            style: TextStyle(
              fontSize: size * 0.26,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.completed,
    required this.total,
    required this.activeColor,
    required this.accentColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final int completed;
  final int total;
  final Color activeColor;
  final Color accentColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final segment = 2 * math.pi / total;
    const startAngle = -math.pi / 2;

    for (var i = 0; i < total; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = i < completed
            ? (i.isEven ? activeColor : accentColor)
            : trackColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + i * segment + 0.08,
        segment - 0.16,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor;
  }
}
