import 'package:flutter/material.dart';

import '../tokens.dart';

/// Border color for secondary panels on Studio dark surfaces.
Color studioPanelBorderColor(BuildContext context) {
  return StudioTokens.of(context).borderSubtle;
}

/// Muted helper/border color (prefer over [ColorScheme.outline] in Studio UI).
Color studioPanelMutedColor(BuildContext context) {
  return StudioTokens.of(context).textMuted;
}

/// Flat panel chrome (no gradient/glow). Prefer over `colorScheme.outline*`.
BoxDecoration studioInsetPanelDecoration(
  BuildContext context, {
  Color? backgroundColor,
  double? borderRadius,
}) {
  final tokens = StudioTokens.of(context);
  return BoxDecoration(
    color: backgroundColor ?? tokens.bgSurface.withValues(alpha: 0.96),
    border: Border.all(color: tokens.borderSubtle),
    borderRadius: BorderRadius.circular(
      borderRadius ?? StudioSpacing.radiusCard,
    ),
  );
}

/// Dense tool rows (Help Hub, docs lists) — meets [StudioSpacing.iconTouchTarget].
ButtonStyle studioUtilityIconButtonStyle(BuildContext context) {
  final tokens = StudioTokens.of(context);
  return IconButton.styleFrom(
    foregroundColor: tokens.textSecondary,
    hoverColor: tokens.primary.withValues(alpha: 0.08),
    minimumSize: const Size(
      StudioSpacing.iconTouchTarget,
      StudioSpacing.iconTouchTarget,
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

/// Top-bar chrome (Shell more menu, locale, sign-out) — 44px with surface fill.
ButtonStyle studioChromeIconButtonStyle(BuildContext context) {
  final tokens = StudioTokens.of(context);
  return IconButton.styleFrom(
    backgroundColor: tokens.bgSurface.withValues(alpha: 0.72),
    foregroundColor: tokens.textSecondary,
    hoverColor: tokens.accentSoft.withValues(alpha: 0.94),
    highlightColor: tokens.primarySoft,
    fixedSize: const Size(
      StudioSpacing.navItemTouchTarget,
      StudioSpacing.navItemTouchTarget,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

/// Slightly recessed panel (input rails, workbench sidecars).
BoxDecoration studioRecessedPanelDecoration(BuildContext context) {
  final tokens = StudioTokens.of(context);
  return BoxDecoration(
    color: tokens.bgInset.withValues(alpha: 0.88),
    border: Border.all(color: tokens.borderSubtle),
    borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
  );
}
