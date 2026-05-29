import 'package:flutter/material.dart';

import 'tokens.dart';

/// Studio shadow system (level 0–5) for cards, menus, modals, and toasts.
abstract final class StudioElevation {
  /// Flat surface — no shadow.
  static const List<BoxShadow> level0 = [];

  /// Subtle lift (cards, chips).
  static List<BoxShadow> level1(bool isDark) => [
    BoxShadow(
      color: StudioPrimitives.black.withValues(alpha: isDark ? 0.20 : 0.08),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Moderate elevation (dropdowns, tooltips).
  static List<BoxShadow> level2(bool isDark) => [
    BoxShadow(
      color: StudioPrimitives.black.withValues(alpha: isDark ? 0.24 : 0.10),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// High elevation (dialogs, sheets).
  static List<BoxShadow> level3(bool isDark) => [
    BoxShadow(
      color: StudioPrimitives.black.withValues(alpha: isDark ? 0.28 : 0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Very high elevation (modals, overlays).
  static List<BoxShadow> level4(bool isDark) => [
    BoxShadow(
      color: StudioPrimitives.black.withValues(alpha: isDark ? 0.32 : 0.14),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Maximum elevation (toasts, notifications).
  static List<BoxShadow> level5(bool isDark) => [
    BoxShadow(
      color: StudioPrimitives.black.withValues(alpha: isDark ? 0.36 : 0.16),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  /// Wraps [child] with [BoxDecoration] shadow for the given [level] (1–5).
  static Widget box({
    required Widget child,
    required int level,
    required bool isDark,
    BorderRadius? borderRadius,
  }) {
    final shadows = switch (level) {
      0 => level0,
      1 => level1(isDark),
      2 => level2(isDark),
      3 => level3(isDark),
      4 => level4(isDark),
      5 => level5(isDark),
      _ => level1(isDark),
    };
    if (shadows.isEmpty) {
      return child;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
