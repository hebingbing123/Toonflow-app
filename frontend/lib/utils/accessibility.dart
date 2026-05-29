import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Relative luminance for WCAG contrast checks.
double studioRelativeLuminance(Color color) {
  double channel(double component) {
    return component <= 0.03928
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Contrast ratio between foreground and background (WCAG).
double studioContrastRatio(Color foreground, Color background) {
  final l1 = studioRelativeLuminance(foreground);
  final l2 = studioRelativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// True when ratio meets WCAG 2.1 AA for body or large text.
bool studioMeetsWcagAa(
  Color foreground,
  Color background, {
  bool isLargeText = false,
}) {
  final ratio = studioContrastRatio(foreground, background);
  return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
}
