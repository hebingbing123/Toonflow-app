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

/// Elevation shadow color from [StudioTokens.overlay].
Color studioShadowColor(BuildContext context, {double alpha = 0.12}) {
  return StudioTokens.of(context).overlay.withValues(alpha: alpha);
}

/// Standard inset panel drop shadow (replaces hardcoded overlay blacks).
List<BoxShadow> studioInsetElevationShadow(
  BuildContext context, {
  double alpha = 0.12,
  double blurRadius = 10,
  double spreadRadius = -8,
  Offset offset = const Offset(0, 4),
}) {
  return <BoxShadow>[
    BoxShadow(
      color: studioShadowColor(context, alpha: alpha),
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
      offset: offset,
    ),
  ];
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
    padding: WidgetStatePropertyAll<EdgeInsets>(typography.buttonPadding),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: WidgetStatePropertyAll<TextStyle>(
      labelStyle ??
          (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w600,
          ),
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

/// [FilledButton.tonal] on workbench forms.
ButtonStyle studioFormTonalButtonStyle(BuildContext context) {
  return FilledButton.styleFrom().merge(_studioFormButtonDimensions(context));
}

/// [FilledButton.icon] / [OutlinedButton.icon] on dense workbench rows.
ButtonStyle studioFormIconLabeledButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    iconSize: 18,
    padding: const EdgeInsets.symmetric(
      horizontal: StudioSpacing.xs,
      vertical: StudioSpacing.xs,
    ),
  ).merge(_studioFormButtonDimensions(context));
}

/// [OutlinedButton.icon] on dense workbench rows.
ButtonStyle studioFormOutlinedIconLabeledButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    iconSize: 18,
    padding: const EdgeInsets.symmetric(
      horizontal: StudioSpacing.xs,
      vertical: StudioSpacing.xs,
    ),
  ).merge(_studioFormButtonDimensions(context));
}

/// [TextButton.icon] secondary actions on dense workbench rows.
ButtonStyle studioFormTextButtonIconStyle(BuildContext context) {
  return TextButton.styleFrom(
    iconSize: 18,
    padding: const EdgeInsets.symmetric(
      horizontal: StudioSpacing.xs,
      vertical: StudioSpacing.xs,
    ),
  ).merge(_studioFormButtonDimensions(context));
}

/// Inset tonal chips (agent quick bar, compact step actions) at form control height.
ButtonStyle studioFormInsetTonalChipStyle(BuildContext context) {
  final tokens = StudioTokens.of(context);
  return studioFormTonalButtonStyle(context).merge(
    ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(tokens.bgInset),
      foregroundColor: WidgetStatePropertyAll(tokens.textPrimary),
      side: WidgetStatePropertyAll(BorderSide(color: tokens.borderDefault)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        ),
      ),
    ),
  );
}

/// Destructive [FilledButton] in dialogs (delete, revoke) at form control height.
ButtonStyle studioFormDestructivePrimaryButtonStyle(BuildContext context) {
  final tokens = StudioTokens.of(context);
  final scheme = Theme.of(context).colorScheme;
  return studioFormPrimaryButtonStyle(context).copyWith(
    backgroundColor: WidgetStatePropertyAll(tokens.danger),
    foregroundColor: WidgetStatePropertyAll(scheme.onError),
  );
}

/// Destructive [FilledButton.icon] in dense forms.
ButtonStyle studioFormDestructiveIconLabeledButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    iconSize: 18,
    padding: const EdgeInsets.symmetric(
      horizontal: StudioSpacing.xs,
      vertical: StudioSpacing.xs,
    ),
  ).merge(studioFormDestructivePrimaryButtonStyle(context));
}

ButtonStyle _studioToolbarButtonDimensions(BuildContext context) {
  final typography = StudioTypography.of(context);
  final toolbarHeight = typography.buttonHeight;
  final labelStyle = studioControlLabelStyle(context)?.copyWith(
    fontWeight: FontWeight.w600,
  );
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(Size(0, toolbarHeight)),
    padding: const WidgetStatePropertyAll<EdgeInsets>(
      EdgeInsets.symmetric(
        horizontal: StudioSpacing.sm,
        vertical: StudioSpacing.xs,
      ),
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.compact,
    textStyle: WidgetStatePropertyAll<TextStyle>(
      labelStyle ??
          (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w600,
          ),
    ),
  );
}

/// Dense tonal actions in pane headers and filter toolbars.
ButtonStyle studioToolbarTonalButtonStyle(BuildContext context) {
  return FilledButton.styleFrom().merge(_studioToolbarButtonDimensions(context));
}

/// Single emphasized action in a pane toolbar row (not full-bleed hero CTA).
ButtonStyle studioToolbarPrimaryButtonStyle(BuildContext context) {
  return FilledButton.styleFrom().merge(_studioToolbarButtonDimensions(context));
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
    dividerColor: StudioPrimitives.transparent,
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
