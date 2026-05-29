import 'package:flutter/material.dart';

import '../tokens.dart';

/// Studio-styled slider using semantic primary color.
class StudioSlider extends StatelessWidget {
  const StudioSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.semanticLabel,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final slider = Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      activeColor: tokens.primary,
      inactiveColor: tokens.borderSubtle,
    );
    if (label == null) {
      return Semantics(label: semanticLabel, child: slider);
    }
    return Semantics(
      label: semanticLabel ?? label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label!, style: Theme.of(context).textTheme.labelMedium),
          slider,
        ],
      ),
    );
  }
}
