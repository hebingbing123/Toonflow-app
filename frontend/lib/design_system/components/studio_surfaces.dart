import 'package:flutter/material.dart';

import '../studio_typography.dart';
import '../tokens.dart';
import 'studio_text_styles.dart';

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

ButtonStyle _studioFormButtonDimensions(BuildContext context) {
  final typography = StudioTypography.of(context);
  final labelStyle = studioControlLabelStyle(context)?.copyWith(
    fontWeight: FontWeight.w600,
  );
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(
      Size(0, typography.buttonHeight),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsets>(
      EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    textStyle: WidgetStatePropertyAll<TextStyle>(
      labelStyle ?? const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

/// Content-sized action on dense workbench forms (not full-bleed).
ButtonStyle studioFormButtonStyle(BuildContext context) {
  return _studioFormButtonDimensions(context);
}

/// [FilledButton] on workbench forms.
ButtonStyle studioFormPrimaryButtonStyle(BuildContext context) {
  return FilledButton.styleFrom().merge(_studioFormButtonDimensions(context));
}

/// [OutlinedButton] / [FilledButton.tonal] on workbench forms.
ButtonStyle studioFormSecondaryButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom().merge(_studioFormButtonDimensions(context));
}

/// Smaller tab labels for focus-mode workbench rails (小说 / 剧本 / 提取).
TabBarThemeData studioWorkbenchTabBarTheme(BuildContext context) {
  return TabBarThemeData(
    labelStyle: studioControlLabelStyle(context)?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: studioHintStyle(context)?.copyWith(
      fontWeight: FontWeight.w500,
    ),
    dividerColor: Colors.transparent,
    indicatorSize: TabBarIndicatorSize.label,
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
