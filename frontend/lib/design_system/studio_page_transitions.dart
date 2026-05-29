import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'studio_motion.dart';

/// Fade transition for full-screen modal routes (search, status).
CustomTransitionPage<void> studioFadeTransitionPage({
  required LocalKey key,
  required Widget child,
  BuildContext? motionContext,
}) {
  final ctx = motionContext;
  final duration = ctx == null
      ? StudioMotionDurations.pageTransition
      : studioAnimationDuration(ctx, StudioMotionDurations.pageTransition);
  final reverse = ctx == null
      ? StudioMotionDurations.fast
      : studioAnimationDuration(ctx, StudioMotionDurations.fast);
  final curve = ctx == null
      ? StudioMotionCurves.pageCurve
      : studioAnimationCurve(ctx, StudioMotionCurves.pageCurve);

  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverse,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: studioAnimationCurve(context, curve),
        ),
        child: child,
      );
    },
  );
}

/// Project studio push — brief overlap for [Hero] flight.
CustomTransitionPage<void> studioProjectStudioTransitionPage({
  required LocalKey key,
  required Widget child,
  BuildContext? motionContext,
}) {
  final ctx = motionContext;
  final duration = ctx == null
      ? StudioMotionDurations.slow
      : studioAnimationDuration(ctx, StudioMotionDurations.slow);
  final reverse = ctx == null
      ? StudioMotionDurations.pageTransition
      : studioAnimationDuration(ctx, StudioMotionDurations.pageTransition);

  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverse,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: studioAnimationCurve(context, StudioMotionCurves.pageCurve),
        reverseCurve: studioAnimationCurve(context, StudioMotionCurves.easeIn),
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
