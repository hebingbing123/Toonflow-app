import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

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
            ? <BoxShadow>[
                BoxShadow(
                  color: tokens.primary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  spreadRadius: -12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        child: card,
      ),
    );
  }
}
