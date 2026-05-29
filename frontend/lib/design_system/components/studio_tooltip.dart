import 'package:flutter/material.dart';

import '../studio_elevation.dart';
import '../studio_motion.dart';
import '../tokens.dart';
import 'studio_text_styles.dart';

/// Studio-styled tooltip (level-2 elevation, token colors).
class StudioTooltip extends StatelessWidget {
  const StudioTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = StudioMotionDurations.tooltipTransition,
    this.preferBelow = true,
    this.semanticLabel,
  });

  final String message;
  final Widget child;
  final Duration waitDuration;
  final bool preferBelow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tooltip = Tooltip(
      message: message,
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      decoration: BoxDecoration(
        color: tokens.bgElevated,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: StudioElevation.level2(isDark),
      ),
      textStyle: studioHintStyle(context)?.copyWith(color: tokens.textPrimary),
      child: child,
    );
    if (semanticLabel == null) {
      return tooltip;
    }
    return Semantics(label: semanticLabel, child: tooltip);
  }
}
