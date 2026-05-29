import 'package:flutter/material.dart';

import '../tokens.dart';

/// Studio-styled text field with label, hint, error, and 2px primary focus ring.
class StudioInput extends StatelessWidget {
  const StudioInput({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.semanticLabel,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? semanticLabel;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: hasError ? errorText : null,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: tokens.bgInset.withValues(alpha: 0.92),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          borderSide: BorderSide(color: tokens.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          borderSide: BorderSide(color: tokens.primaryFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          borderSide: BorderSide(color: tokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
      ),
    );

    if (semanticLabel == null) {
      return field;
    }
    return Semantics(
      textField: true,
      label: semanticLabel ?? label,
      child: field,
    );
  }
}
