import 'package:flutter/material.dart';

import 'studio_entrance_motion.dart';

/// Cross-fades [child] when [transitionKey] changes (usage counts, prices, quotas).
///
/// Uses fade-only motion (no slide) to avoid digit layout jitter.
class StudioMetricSwitch extends StatelessWidget {
  const StudioMetricSwitch({
    super.key,
    required this.transitionKey,
    required this.child,
    this.duration = studioMotionQuickDuration,
  });

  final Object transitionKey;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return StudioFadeSwitcher(
      transitionKey: transitionKey,
      duration: duration,
      slideOffset: Offset.zero,
      child: child,
    );
  }
}
