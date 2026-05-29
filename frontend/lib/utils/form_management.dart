import 'package:flutter/material.dart';

/// Lightweight form submit helper (wraps [FormState] + loading flag).
class StudioFormController {
  StudioFormController({required GlobalKey<FormState> formKey})
      : _formKey = formKey;

  final GlobalKey<FormState> _formKey;
  bool _submitting = false;

  bool get isSubmitting => _submitting;

  bool validate() => _formKey.currentState?.validate() ?? false;

  void save() => _formKey.currentState?.save();

  /// Runs [action] when the form validates; toggles [onSubmittingChanged].
  Future<void> submit({
    required Future<void> Function() action,
    void Function(bool submitting)? onSubmittingChanged,
    List<FocusNode>? focusOnValidationError,
  }) async {
    if (_submitting) return;
    if (!validate()) {
      if (focusOnValidationError != null) {
        focusFirstError(focusOnValidationError);
      }
      return;
    }
    save();
    _submitting = true;
    onSubmittingChanged?.call(true);
    try {
      await action();
    } finally {
      _submitting = false;
      onSubmittingChanged?.call(false);
    }
  }

  /// Focuses the first [FocusNode] in [errorFocusNodes] when validation fails.
  static void focusFirstError(List<FocusNode> errorFocusNodes) {
    for (final node in errorFocusNodes) {
      if (node.context != null) {
        FocusScope.of(node.context!).requestFocus(node);
        return;
      }
    }
  }
}
