import 'package:flutter/material.dart';

import '../ix/studio_pointer.dart';
import '../tokens.dart';

/// Shared tappable wrapper with Material ripple and minimum touch target.
///
/// Use this instead of raw [GestureDetector] for interactive elements that should
/// provide visual feedback and be easy to hit on touch devices.
class StudioTap extends StatelessWidget {
  const StudioTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding,
    this.minSize = StudioSpacing.touchTarget,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final double minSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final radius = borderRadius ?? BorderRadius.circular(StudioSpacing.radiusDense);
    final effectiveOnTap = enabled ? onTap : null;

    final interactive = effectiveOnTap != null;

    return StudioPointerHover(
      enabled: interactive,
      borderRadius: radius,
      builder: (context, hovered) {
        return studioWrapClickCursor(
          enabled: interactive,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: effectiveOnTap,
                borderRadius: radius,
                splashColor: tokens.primary.withValues(alpha: 0.18),
                highlightColor: tokens.primary.withValues(alpha: 0.08),
                hoverColor: studioPointerChromeEnabled(context)
                    ? tokens.primary.withValues(alpha: 0.10)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  decoration: hovered
                      ? BoxDecoration(
                          borderRadius: radius,
                          color: tokens.bgElevated.withValues(alpha: 0.42),
                        )
                      : null,
                  child: Padding(
                    padding: padding ?? EdgeInsets.zero,
                    child: Center(child: child),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

