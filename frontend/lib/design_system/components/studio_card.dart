import 'package:flutter/material.dart';

import '../ix/studio_pointer.dart';
import '../studio_elevation.dart';
import '../studio_motion.dart';
import '../theme.dart';
import '../tokens.dart';
import 'studio_surfaces.dart';

class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StudioSpacing.sm),
    this.onTap,
    this.emphasized = false,
    this.elevationLevel = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// When false, uses a flat surface (secondary panels, dense tool pages).
  final bool emphasized;

  /// Shadow level 0–5 when not [emphasized] ([StudioElevation]).
  final int elevationLevel;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final studio = StudioColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(StudioSpacing.radiusCard);
    List<BoxShadow>? boxShadow;
    if (emphasized) {
      boxShadow = studioInsetElevationShadow(
        context,
        alpha: 0.14,
        blurRadius: StudioSpacing.radiusComfort,
        spreadRadius: -12,
      );
    } else if (elevationLevel > 0) {
      boxShadow = switch (elevationLevel) {
        1 => StudioElevation.level1(isDark),
        2 => StudioElevation.level2(isDark),
        3 => StudioElevation.level3(isDark),
        4 => StudioElevation.level4(isDark),
        5 => StudioElevation.level5(isDark),
        _ => StudioElevation.level1(isDark),
      };
    }
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: emphasized ? studio.panelGradient : null,
        color: emphasized ? null : tokens.bgSurface.withValues(alpha: 0.96),
        borderRadius: radius,
        border: Border.all(
          color: emphasized
              ? tokens.surfaceHighlight
              : tokens.borderSubtle,
        ),
        boxShadow: boxShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return StudioPointerHover(
      enabled: true,
      borderRadius: radius,
      liftShadow: false,
      builder: (context, hovered) {
        return studioWrapClickCursor(
          enabled: true,
          child: Material(
            color: StudioPrimitives.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              hoverColor: studioNestedMaterialHover,
              highlightColor: studioNestedMaterialHighlight,
              child: AnimatedScale(
                scale: hovered ? 1.008 : 1,
                duration: StudioMotionDurations.hoverTransition,
                curve: StudioMotionCurves.hoverCurve,
                child: card,
              ),
            ),
          ),
        );
      },
    );
  }
}
