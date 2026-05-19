import 'package:flutter/material.dart';

import 'studio_dropdown_field.dart';

/// Dropdown that stores API enum [codes] but always shows localized labels.
///
/// Thin wrapper over [StudioDropdownField] for string API codes.
class StudioCodeDropdownField extends StatelessWidget {
  const StudioCodeDropdownField({
    super.key,
    required this.value,
    required this.labelText,
    required this.codes,
    required this.labelForValue,
    required this.onChanged,
    this.width = 220,
  });

  final String value;
  final String labelText;
  final List<String> codes;
  final String Function(String code) labelForValue;
  final ValueChanged<String> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return StudioDropdownField<String>(
      value: value,
      labelText: labelText,
      width: width,
      entries: codes
          .map(
            (code) => StudioDropdownEntry<String>(
              value: code,
              label: labelForValue(code),
            ),
          )
          .toList(growable: false),
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}
