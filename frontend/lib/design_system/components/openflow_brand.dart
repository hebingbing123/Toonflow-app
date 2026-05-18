import 'package:flutter/material.dart';

import '../theme.dart';

const _kOpenFlowGlyphAsset = 'assets/brand/openflow_glyph.png';

/// Shared OpenFlow brand mark for app chrome and login surfaces.
class OpenFlowBrandMark extends StatelessWidget {
  const OpenFlowBrandMark({
    super.key,
    required this.size,
    this.borderRadius,
    this.iconScale = 0.72,
  });

  final double size;
  final double? borderRadius;
  final double iconScale;

  @override
  Widget build(BuildContext context) {
    final studio = StudioColors.of(context);
    final radius = borderRadius ?? size * 0.28;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: studio.brandGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF7C6CF0).withValues(alpha: 0.28),
            blurRadius: size * 0.34,
            offset: Offset(0, size * 0.18),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: Padding(
          padding: EdgeInsets.all(size * (1 - iconScale) / 2),
          child: Image.asset(
            _kOpenFlowGlyphAsset,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
