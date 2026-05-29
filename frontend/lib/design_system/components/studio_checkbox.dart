import 'package:flutter/material.dart';

import '../tokens.dart';

/// Studio-styled checkbox with platform touch target.
class StudioCheckbox extends StatelessWidget {
  const StudioCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final String? semanticLabel;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    final minSize = StudioSpacing.touchTargetForContext(context);
    final control = SizedBox(
      width: minSize,
      height: minSize,
      child: Center(
        child: Checkbox(
          value: value,
          tristate: tristate,
          onChanged: onChanged,
        ),
      ),
    );
    if (label == null) {
      return Semantics(
        label: semanticLabel,
        checked: value == true,
        child: control,
      );
    }
    return Semantics(
      label: semanticLabel ?? label,
      checked: value == true,
      child: InkWell(
        onTap: onChanged == null
            ? null
            : () => onChanged!(value == true ? false : true),
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
