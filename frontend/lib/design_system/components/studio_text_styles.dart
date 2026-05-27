import 'package:flutter/material.dart';

import '../studio_typography.dart';
import '../tokens.dart';

/// Readable secondary copy on studio dark surfaces (never [ColorScheme.outline]).
Color studioMutedTextColor(BuildContext context) {
  return StudioTokens.of(context).textSecondary;
}

TextStyle? studioPageTitleStyle(BuildContext context) {
  final theme = Theme.of(context);
  final typography = StudioTypography.of(context);
  return theme.textTheme.titleLarge?.copyWith(
    fontSize: typography.pageTitle,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );
}

TextStyle? studioProjectTitleStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return Theme.of(context).textTheme.titleLarge?.copyWith(
    fontSize: typography.projectTitle,
    fontWeight: FontWeight.w600,
    height: 1.16,
  );
}

TextStyle? studioDialogTitleStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return Theme.of(context).textTheme.titleLarge?.copyWith(
    fontSize: typography.dialogTitle,
    fontWeight: FontWeight.w700,
    height: 1.16,
  );
}

TextStyle? studioPaneTitleStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return Theme.of(context).textTheme.titleMedium?.copyWith(
    fontSize: typography.paneTitle,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}

TextStyle? studioCardTitleStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return Theme.of(context).textTheme.titleMedium?.copyWith(
    fontSize: typography.cardTitle,
    fontWeight: FontWeight.w600,
    height: 1.18,
  );
}

TextStyle? studioSectionIntroStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontSize: typography.body,
    color: studioMutedTextColor(context),
    height: 1.5,
  );
}

TextStyle? studioHintStyle(BuildContext context) {
  return Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: studioMutedTextColor(context));
}

TextStyle? studioControlLabelStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return Theme.of(context).textTheme.labelLarge?.copyWith(
    fontSize: typography.label,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}

TextStyle? studioChromeTitleStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return Theme.of(context).textTheme.labelLarge?.copyWith(
    fontSize: typography.bodyLarge,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}

TextStyle? studioMutedBodySmall(BuildContext context) {
  return studioHintStyle(context);
}

TextStyle? studioMutedBodyMedium(BuildContext context) {
  return studioSectionIntroStyle(context);
}

/// Badge / count pill on dark chrome (sidebar, app bar).
/// Section title on dark studio inset panels (script step rail, etc.).
TextStyle? studioInsetSectionTitleStyle(BuildContext context) {
  return studioPaneTitleStyle(context)?.copyWith(
    color: StudioTokens.of(context).textPrimary,
  );
}

TextStyle studioBadgeTextStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).copyWith(
    color: Theme.of(context).colorScheme.onPrimary,
    fontSize: typography.meta,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );
}

/// Title line on semantic status banners (freshness, panel version, etc.).
TextStyle studioAccentBannerTitleStyle(BuildContext context, Color accentColor) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
    fontSize: typography.bodyLarge,
    fontWeight: FontWeight.bold,
    color: accentColor,
    height: 1.3,
  );
}

/// Body line on semantic status banners.
TextStyle studioAccentBannerBodyStyle(BuildContext context, Color accentColor) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
    fontSize: typography.meta,
    color: accentColor,
    height: 1.35,
  );
}

/// Monospace meta copy (reports, technical details).
TextStyle studioMonospaceMetaStyle(BuildContext context, {Color? color}) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
    fontFamily: 'monospace',
    fontSize: typography.meta,
    color: color,
  );
}

/// Large stat value in comparison / summary tiles.
TextStyle studioStatHeroValueStyle(BuildContext context, Color color) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.displaySmall ?? const TextStyle()).copyWith(
    fontSize: typography.display,
    fontWeight: FontWeight.bold,
    color: color,
    height: 1.1,
  );
}

/// Wizard step indicator number inside a circle.
TextStyle studioWizardStepNumberStyle(BuildContext context, Color color) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).copyWith(
    fontSize: typography.meta,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

/// Wizard step label under the indicator.
TextStyle studioWizardStepLabelStyle(
  BuildContext context, {
  required Color color,
  FontWeight fontWeight = FontWeight.w500,
}) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
    fontSize: typography.meta,
    height: 1.25,
    fontWeight: fontWeight,
    color: color,
  );
}

/// Popup menu section header.
TextStyle studioMenuSectionHeaderStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w700,
    fontSize: typography.meta,
    color: StudioTokens.of(context).textSecondary,
  );
}

/// Filter count pill and compact chips.
TextStyle studioFilterCountBadgeStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.labelSmall ?? const TextStyle()).copyWith(
    fontSize: typography.meta,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onPrimaryContainer,
  );
}

/// Outlined button label in filter panels.
TextStyle studioFilterActionLabelStyle(BuildContext context) {
  final typography = StudioTypography.of(context);
  return (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
    fontSize: typography.bodyLarge,
  );
}

extension TextStyleTabularFigures on TextStyle {
  TextStyle withTabularFigures() {
    return copyWith(
      fontFeatures: <FontFeature>[
        ...?fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );
  }
}

