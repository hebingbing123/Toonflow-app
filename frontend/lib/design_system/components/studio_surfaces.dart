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
///
/// Dark theme uses softer shadows so panels rely on [studioPanelBorderColor]
/// instead of heavy glow (see studio visual guidelines).
Color studioShadowColor(BuildContext context, {double alpha = 0.12}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveAlpha = isDark ? alpha * 0.42 : alpha;
  return StudioTokens.of(context).overlay.withValues(alpha: effectiveAlpha);
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

/// Label metrics for form/toolbar buttons — **no** [Color] so [ButtonStyle.foregroundColor] wins.
///
/// [ThemeData.textTheme] applies [StudioTokens.textPrimary] to [TextTheme.labelLarge];
/// merging that into [ButtonStyle.textStyle] breaks [FilledButton] contrast on light panels.
TextStyle studioFormButtonLabelMetrics(BuildContext context) {
  final typography = StudioTypography.of(context);
  final fromTheme = studioControlLabelStyle(context) ??
      Theme.of(context).textTheme.labelLarge ??
      const TextStyle();
  return TextStyle(
    inherit: true,
    fontSize: fromTheme.fontSize ?? typography.label,
    fontWeight: FontWeight.w600,
    height: fromTheme.height ?? 1.2,
    fontFamily: fromTheme.fontFamily,
    letterSpacing: fromTheme.letterSpacing,
  );
}

ButtonStyle _studioFormButtonDimensions(BuildContext context) {
  final typography = StudioTypography.of(context);
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(
      Size(0, typography.buttonHeight),
    ),
    padding: WidgetStatePropertyAll<EdgeInsets>(typography.buttonPadding),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: WidgetStatePropertyAll(studioFormButtonLabelMetrics(context)),
  );
}

/// Content-sized action on dense workbench forms (not full-bleed).
ButtonStyle studioFormButtonStyle(BuildContext context) {
  return _studioFormButtonDimensions(context);
}

/// [FilledButton] on workbench forms.
ButtonStyle studioFormPrimaryButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final labelColor = scheme.onPrimary;
  return FilledButton.styleFrom(
    foregroundColor: labelColor,
    backgroundColor: scheme.primary,
  ).merge(_studioFormButtonDimensions(context)).copyWith(
        textStyle: WidgetStatePropertyAll(
          studioFormButtonLabelMetrics(context).copyWith(color: labelColor),
        ),
      );
}

/// [OutlinedButton] / [FilledButton.tonal] on workbench forms.
ButtonStyle studioFormSecondaryButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom().merge(_studioFormButtonDimensions(context));
}

/// [FilledButton.tonal] on workbench forms.
ButtonStyle studioFormTonalButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final labelColor = scheme.onSecondaryContainer;
  return FilledButton.styleFrom(
    foregroundColor: labelColor,
    backgroundColor: scheme.secondaryContainer,
  ).merge(_studioFormButtonDimensions(context)).copyWith(
        textStyle: WidgetStatePropertyAll(
          studioFormButtonLabelMetrics(context).copyWith(color: labelColor),
        ),
      );
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
  final labelColor = tokens.textPrimary;
  return studioFormTonalButtonStyle(context).merge(
    ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(tokens.bgInset),
      foregroundColor: WidgetStatePropertyAll(labelColor),
      textStyle: WidgetStatePropertyAll(
        studioFormButtonLabelMetrics(context).copyWith(color: labelColor),
      ),
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
  final labelColor = scheme.onError;
  return studioFormPrimaryButtonStyle(context).copyWith(
    backgroundColor: WidgetStatePropertyAll(tokens.danger),
    foregroundColor: WidgetStatePropertyAll(labelColor),
    textStyle: WidgetStatePropertyAll(
      studioFormButtonLabelMetrics(context).copyWith(color: labelColor),
    ),
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
    textStyle: WidgetStatePropertyAll(studioFormButtonLabelMetrics(context)),
  );
}

/// Dense tonal actions in pane headers and filter toolbars.
ButtonStyle studioToolbarTonalButtonStyle(BuildContext context) {
  return studioFormTonalButtonStyle(context).merge(_studioToolbarButtonDimensions(context));
}

/// Single emphasized action in a pane toolbar row (not full-bleed hero CTA).
ButtonStyle studioToolbarPrimaryButtonStyle(BuildContext context) {
  return studioFormPrimaryButtonStyle(context).merge(_studioToolbarButtonDimensions(context));
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

/// Outline / dropdown fields with floating labels (use inside collapsible panels).
InputDecoration studioOutlineFieldDecoration(InputDecoration decoration) {
  final hasFloatingLabel =
      (decoration.labelText?.isNotEmpty ?? false) ||
      (decoration.hintText?.isNotEmpty ?? false);
  if (!hasFloatingLabel) {
    return decoration;
  }
  return decoration.copyWith(isDense: false);
}

/// When [StudioPointerHover] or card chrome already paints hover, suppress InkWell tint.
const Color studioNestedMaterialHover = Colors.transparent;

const Color studioNestedMaterialHighlight = Colors.transparent;
