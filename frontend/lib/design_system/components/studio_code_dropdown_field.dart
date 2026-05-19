import 'package:flutter/material.dart';

/// Dropdown that stores API enum [codes] but always shows localized labels.
///
/// Material 3 [DropdownMenu] renders the raw [value] in the text field after
/// selection; this widget uses [DropdownButtonFormField] so the closed field
/// matches the menu labels.
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
    final field = DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: labelText,
        isDense: true,
      ),
      items: codes
          .map(
            (code) => DropdownMenuItem<String>(
              value: code,
              child: Text(labelForValue(code)),
            ),
          )
          .toList(growable: false),
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
    if (width == null) {
      return field;
    }
    return SizedBox(width: width, child: field);
  }
}
