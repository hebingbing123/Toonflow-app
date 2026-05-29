import 'package:flutter/material.dart';

import 'studio_repaint_boundary.dart';
import '../tokens.dart';

/// Normalized sparkline (0–1) drawn with [CustomPaint] — no external chart lib (17.2).
class StudioSparklineChart extends StatelessWidget {
  const StudioSparklineChart({
    super.key,
    required this.values,
    this.height = 48,
    this.semanticsLabel,
    this.lineColor,
    this.fillColor,
  });

  final List<double> values;
  final double height;
  final String? semanticsLabel;
  final Color? lineColor;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    if (values.length < 2) {
      return SizedBox(height: height);
    }
    final label = semanticsLabel ?? 'Sparkline, ${values.length} points';
    return Semantics(
      label: label,
      child: StudioRepaintBoundary(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(
              values: values,
              lineColor: lineColor ?? tokens.primary,
              fillColor: fillColor ?? tokens.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}
