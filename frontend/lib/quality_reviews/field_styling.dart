import 'package:flutter/material.dart';

import '../design_system/ix/studio_form_keyboard.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';

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
  final mutedStyle = studioHintStyle(context);
  return InputDecoration(
    labelText: labelText,
    helperText: helperText,
    hintText: hintText,
    labelStyle: mutedStyle,
    floatingLabelStyle: mutedStyle,
    helperStyle: mutedStyle,
    hintStyle: mutedStyle?.copyWith(color: muted.withValues(alpha: 0.85)),
  );
}

/// Review ID field + action button aligned on the input baseline (studio pane).
class QualityReviewIdLookupRow extends StatelessWidget {
  const QualityReviewIdLookupRow({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.loading,
    required this.onSubmit,
    required this.fieldLabel,
    required this.actionLabel,
    this.busyLabel,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool loading;
  final VoidCallback? onSubmit;
  final String fieldLabel;
  final String actionLabel;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && controller.text.trim().isNotEmpty;
    final action = FilledButton.tonal(
      style: studioFormTonalButtonStyle(context),
      onPressed: enabled ? onSubmit : null,
      child: Text(loading ? (busyLabel ?? '…') : actionLabel),
    );
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.done,
      style: qualityReviewsFieldTextStyle(context),
      decoration: qualityReviewsInputDecoration(
        context,
        labelText: fieldLabel,
      ),
    );
    final width = MediaQuery.sizeOf(context).width;
    final body = width < 520
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              field,
              const SizedBox(height: StudioSpacing.xs),
              action,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: field),
              const SizedBox(width: StudioSpacing.xs),
              action,
            ],
          );
    return StudioFormKeyboardScope(
      onEnterSubmit: enabled ? onSubmit : null,
      child: body,
    );
  }
}

/// Ensures dialog form fields use readable on-surface text in dark theme.
ThemeData qualityReviewsFormTheme(BuildContext context) {
  final base = Theme.of(context);
  final scheme = base.colorScheme;
  final mutedStyle = studioHintStyle(context);
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: mutedStyle,
      floatingLabelStyle: mutedStyle,
      helperStyle: mutedStyle,
      hintStyle: mutedStyle?.copyWith(
        color: StudioTokens.of(context).textSecondary.withValues(alpha: 0.85),
      ),
    ),
  );
}
