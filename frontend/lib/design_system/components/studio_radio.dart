import 'package:flutter/material.dart';

import '../tokens.dart';

/// Studio-styled radio with platform touch target.
///
/// Uses legacy [Radio] API until [RadioGroup] is stable across our Flutter pin.
class StudioRadio<T> extends StatelessWidget {
  const StudioRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
    this.semanticLabel,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final minSize = StudioSpacing.touchTargetForContext(context);
    final control = SizedBox(
      width: minSize,
      height: minSize,
      child: Center(
        // ignore: deprecated_member_use
        child: Radio<T>(
          value: value,
          // ignore: deprecated_member_use
          groupValue: groupValue,
          // ignore: deprecated_member_use
          onChanged: onChanged,
        ),
      ),
    );
    if (label == null) {
      return Semantics(
        label: semanticLabel,
        checked: value == groupValue,
        child: control,
      );
    }
    return Semantics(
      label: semanticLabel ?? label,
      checked: value == groupValue,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(value),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            control,
            const SizedBox(width: StudioSpacing.xs),
            Flexible(child: Text(label!)),
          ],
        ),
      ),
    );
  }
}
