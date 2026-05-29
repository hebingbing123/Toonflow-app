import 'package:flutter/material.dart';

/// Studio animation timing and easing (see also [StudioInteractionTiming] for debounce).
abstract final class StudioMotionDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 500);

  static const Duration hoverTransition = fast;
  static const Duration focusTransition = fast;
  static const Duration dialogTransition = normal;
  static const Duration drawerTransition = slow;
  static const Duration pageTransition = normal;
  static const Duration tooltipTransition = fast;
  static const Duration snackbarTransition = normal;
}

/// Studio recommended easing curves for UI transitions.
abstract final class StudioMotionCurves {
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeInOut = Curves.easeInOut;

  static const Curve hoverCurve = easeOut;
  static const Curve dialogCurve = easeInOut;
  static const Curve drawerCurve = easeOut;
  static const Curve pageCurve = easeInOut;
}

/// Whether motion should be suppressed (OS reduced motion, tests, a11y).
bool studioDisableAnimations(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    ) ||
    WidgetsBinding.instance.runtimeType.toString().contains(
      'AutomatedTestWidgetsFlutterBinding',
    );

/// Returns [Duration.zero] when [studioDisableAnimations] is true.
Duration studioAnimationDuration(BuildContext context, Duration duration) =>
    studioDisableAnimations(context) ? Duration.zero : duration;

/// Returns a linear curve when animations are disabled.
Curve studioAnimationCurve(BuildContext context, Curve curve) =>
    studioDisableAnimations(context) ? Curves.linear : curve;
