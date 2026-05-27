import 'package:flutter/material.dart';

import '../design_system/tokens.dart';

/// Shared coach chrome so tour cards match [ThemeData] / [StudioTokens].
@immutable
class ProductDemoCoachTheme {
  const ProductDemoCoachTheme._({
    required this.accent,
    required this.onAccent,
    required this.optionalAccent,
  });

  factory ProductDemoCoachTheme.of(
    StudioTokens tokens, {
    required bool isOptionalUtility,
  }) {
    return ProductDemoCoachTheme._(
      accent: tokens.primary,
      onAccent: StudioPrimitives.white,
      optionalAccent: isOptionalUtility ? tokens.warning : tokens.primary,
    );
  }

  final Color accent;
  final Color onAccent;
  final Color optionalAccent;

  Color badgeFill(StudioTokens tokens, {required bool isOptionalUtility}) {
    final color = isOptionalUtility ? optionalAccent : accent;
    return color.withValues(alpha: 0.14);
  }

  Color badgeBorder(StudioTokens tokens, {required bool isOptionalUtility}) {
    final color = isOptionalUtility ? optionalAccent : accent;
    return color.withValues(alpha: 0.38);
  }

  ButtonStyle primaryButton(ThemeData theme, StudioTokens tokens) {
    return FilledButton.styleFrom(
      backgroundColor: tokens.primary,
      foregroundColor: onAccent,
      disabledBackgroundColor: tokens.primary.withValues(alpha: 0.35),
      disabledForegroundColor: tokens.textMuted,
      minimumSize: const Size(96, StudioSpacing.iconTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.radiusComfort),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
      ),
      textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  ButtonStyle secondaryButton(ThemeData theme, StudioTokens tokens) {
    return TextButton.styleFrom(
      foregroundColor: tokens.textSecondary,
      minimumSize: const Size(64, StudioSpacing.iconTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.radiusComfort, vertical: StudioSpacing.xs),
      textStyle: theme.textTheme.labelLarge,
    );
  }

  ButtonStyle tertiaryButton(ThemeData theme, StudioTokens tokens) {
    return TextButton.styleFrom(
      foregroundColor: tokens.textMuted,
      minimumSize: const Size(64, StudioSpacing.iconTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.xs),
      textStyle: theme.textTheme.labelMedium,
    );
  }
}
