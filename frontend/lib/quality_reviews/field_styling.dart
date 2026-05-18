import 'package:flutter/material.dart';

import '../design_system/components/studio_text_styles.dart';

/// Muted secondary copy on studio dark surfaces (never use [ColorScheme.outline]).
Color qualityReviewsMutedColor(BuildContext context) => studioMutedTextColor(context);

TextStyle? qualityReviewsMutedTextStyle(BuildContext context) =>
    studioMutedBodySmall(context);

TextStyle? qualityReviewsFieldTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  );
}

InputDecoration qualityReviewsInputDecoration(
  BuildContext context, {
  String? labelText,
  String? helperText,
  String? hintText,
}) {
  final muted = qualityReviewsMutedColor(context);
  return InputDecoration(
    labelText: labelText,
    helperText: helperText,
    hintText: hintText,
    labelStyle: TextStyle(color: muted),
    floatingLabelStyle: TextStyle(color: muted),
    helperStyle: TextStyle(color: muted),
    hintStyle: TextStyle(color: muted.withValues(alpha: 0.85)),
  );
}

/// Ensures dialog form fields use readable on-surface text in dark theme.
ThemeData qualityReviewsFormTheme(BuildContext context) {
  final base = Theme.of(context);
  final scheme = base.colorScheme;
  final muted = scheme.onSurfaceVariant;
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: TextStyle(color: muted),
      floatingLabelStyle: TextStyle(color: muted),
      helperStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.85)),
    ),
  );
}
