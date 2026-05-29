import 'package:flutter/material.dart';

import '../ix/studio_pointer.dart';
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// When false, uses a flat surface (secondary panels, dense tool pages).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final studio = StudioColors.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: emphasized ? studio.panelGradient : null,
        color: emphasized ? null : tokens.bgSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        border: Border.all(
          color: emphasized
              ? tokens.surfaceHighlight
              : tokens.borderSubtle,
        ),
        boxShadow: emphasized
            ? studioInsetElevationShadow(
                context,
                alpha: 0.14,
                blurRadius: StudioSpacing.radiusComfort,
                spreadRadius: -12,
              )
            : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    final radius = BorderRadius.circular(StudioSpacing.radiusCard);
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
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                child: card,
              ),
            ),
          ),
        );
      },
    );
  }
}
