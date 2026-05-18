import 'package:flutter/material.dart';

import '../studio_typography.dart';

/// Readable secondary copy on studio dark surfaces (never [ColorScheme.outline]).
Color studioMutedTextColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
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
