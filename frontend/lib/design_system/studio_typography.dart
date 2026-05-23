import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Stable desktop typography profiles for the Studio product shell.
///
/// Desktop should not scale fonts continuously with viewport width. Instead we
/// keep three tuned profiles and switch at coarse breakpoints:
/// - compact: dense laptop and split-window layouts
/// - regular: default desktop
/// - large: wide desktop where a little more air helps scanning
@immutable
class StudioTypography extends ThemeExtension<StudioTypography> {
  const StudioTypography({
    required this.pageTitle,
    required this.dialogTitle,
    required this.projectTitle,
    required this.cardTitle,
    required this.paneTitle,
    required this.bodyLarge,
    required this.body,
    required this.hint,
    required this.meta,
    required this.label,
    required this.display,
    required this.buttonHeight,
    required this.buttonPadding,
    required this.textButtonPadding,
    required this.inputPadding,
  });

  final double pageTitle;
  final double dialogTitle;
  final double projectTitle;
  final double cardTitle;
  final double paneTitle;
  final double bodyLarge;
  final double body;
  final double hint;
  final double meta;
  final double label;
  final double display;
  final double buttonHeight;
  final EdgeInsets buttonPadding;
  final EdgeInsets textButtonPadding;
  final EdgeInsets inputPadding;

  static const StudioTypography compact = StudioTypography(
    pageTitle: 20,
    dialogTitle: 16,
    projectTitle: 16,
    cardTitle: 15,
    paneTitle: 15,
    bodyLarge: 14,
    body: 13,
    hint: 12,
    meta: 12,
    label: 12,
    display: 28,
    buttonHeight: 40,
    buttonPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
    textButtonPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
    inputPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
  );

  static const StudioTypography regular = StudioTypography(
    pageTitle: 21,
    dialogTitle: 17,
    projectTitle: 17,
    cardTitle: 16,
    paneTitle: 15,
    bodyLarge: 15,
    body: 14,
    hint: 13,
    meta: 12,
    label: 12,
    display: 30,
    buttonHeight: 42,
    buttonPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
    textButtonPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.xs),
    inputPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
  );

  static const StudioTypography large = StudioTypography(
    pageTitle: 22,
    dialogTitle: 18,
    projectTitle: 18,
    cardTitle: 17,
    paneTitle: 16,
    bodyLarge: 16,
    body: 15,
    hint: 14,
    meta: 12,
    label: 13,
    display: 32,
    buttonHeight: 44,
    buttonPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.md, vertical: StudioSpacing.md),
    textButtonPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
    inputPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
  );

  static StudioTypography of(BuildContext context) {
    return Theme.of(context).extension<StudioTypography>() ?? regular;
  }

  @override
  StudioTypography copyWith({
    double? pageTitle,
    double? dialogTitle,
    double? projectTitle,
    double? cardTitle,
    double? paneTitle,
    double? bodyLarge,
    double? body,
    double? hint,
    double? meta,
    double? label,
    double? display,
    double? buttonHeight,
    EdgeInsets? buttonPadding,
    EdgeInsets? textButtonPadding,
    EdgeInsets? inputPadding,
  }) {
    return StudioTypography(
      pageTitle: pageTitle ?? this.pageTitle,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      projectTitle: projectTitle ?? this.projectTitle,
      cardTitle: cardTitle ?? this.cardTitle,
      paneTitle: paneTitle ?? this.paneTitle,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      body: body ?? this.body,
      hint: hint ?? this.hint,
      meta: meta ?? this.meta,
      label: label ?? this.label,
      display: display ?? this.display,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      buttonPadding: buttonPadding ?? this.buttonPadding,
      textButtonPadding: textButtonPadding ?? this.textButtonPadding,
      inputPadding: inputPadding ?? this.inputPadding,
    );
  }

  @override
  StudioTypography lerp(ThemeExtension<StudioTypography>? other, double t) {
    if (other is! StudioTypography) {
      return this;
    }
    return StudioTypography(
      pageTitle: lerpDouble(pageTitle, other.pageTitle, t)!,
      dialogTitle: lerpDouble(dialogTitle, other.dialogTitle, t)!,
      projectTitle: lerpDouble(projectTitle, other.projectTitle, t)!,
      cardTitle: lerpDouble(cardTitle, other.cardTitle, t)!,
      paneTitle: lerpDouble(paneTitle, other.paneTitle, t)!,
      bodyLarge: lerpDouble(bodyLarge, other.bodyLarge, t)!,
      body: lerpDouble(body, other.body, t)!,
      hint: lerpDouble(hint, other.hint, t)!,
      meta: lerpDouble(meta, other.meta, t)!,
      label: lerpDouble(label, other.label, t)!,
      display: lerpDouble(display, other.display, t)!,
      buttonHeight: lerpDouble(buttonHeight, other.buttonHeight, t)!,
      buttonPadding: EdgeInsets.lerp(buttonPadding, other.buttonPadding, t)!,
      textButtonPadding: EdgeInsets.lerp(
        textButtonPadding,
        other.textButtonPadding,
        t,
      )!,
      inputPadding: EdgeInsets.lerp(inputPadding, other.inputPadding, t)!,
    );
  }
}

StudioTypography studioTypographyForWidth(double width) {
  if (width >= 1720) {
    return StudioTypography.large;
  }
  if (width < 1280) {
    return StudioTypography.compact;
  }
  return StudioTypography.regular;
}
