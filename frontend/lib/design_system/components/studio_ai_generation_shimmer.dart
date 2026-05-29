import 'package:flutter/material.dart';

import '../components/studio_loading_placeholders.dart';
import '../tokens.dart';

/// AI generation wait placeholder with shimmer skeleton (rebuild plan P1-1).
class StudioAiGenerationShimmer extends StatelessWidget {
  const StudioAiGenerationShimmer({
    super.key,
    this.lines = 4,
    this.padding,
  });

  final int lines;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(StudioSpacing.sm),
      child: StudioListSkeleton(itemCount: lines.clamp(2, 8)),
    );
  }
}
