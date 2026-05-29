import 'package:flutter/material.dart';

import '../tokens.dart';

/// Studio-styled switch with semantic label support.
class StudioSwitch extends StatelessWidget {
  const StudioSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final minSize = StudioSpacing.touchTargetForContext(context);
    final control = SizedBox(
      width: minSize,
      height: minSize,
      child: Center(
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: tokens.primary,
        ),
      ),
    );
    if (label == null) {
      return Semantics(
        label: semanticLabel,
        toggled: value,
        child: control,
      );
    }
    return Semantics(
      label: semanticLabel ?? label,
      toggled: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: Text(label!)),
          control,
        ],
      ),
    );
  }
}
