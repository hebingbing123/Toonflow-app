import 'package:flutter/material.dart';

/// Whether motion should be suppressed (OS reduced motion, tests, a11y).
bool studioDisableAnimations(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Returns [Duration.zero] when [studioDisableAnimations] is true.
Duration studioAnimationDuration(BuildContext context, Duration duration) =>
    studioDisableAnimations(context) ? Duration.zero : duration;

/// Returns a linear curve when animations are disabled.
Curve studioAnimationCurve(BuildContext context, Curve curve) =>
    studioDisableAnimations(context) ? Curves.linear : curve;
