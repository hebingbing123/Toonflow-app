import 'package:flutter/material.dart';

import '../tokens.dart';

/// Horizontal action strip that can wrap onto additional lines when space is tight.
class StudioDenseActionRow extends StatelessWidget {
  const StudioDenseActionRow({
    super.key,
    required this.children,
    this.spacing = StudioSpacing.xs,
    this.alignment = WrapAlignment.start,
    this.expandToMaxWidth = true,
  });

  final List<Widget> children;
  final double spacing;
  final WrapAlignment alignment;
  final bool expandToMaxWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrap = Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: alignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        );
        if (!constraints.hasBoundedWidth) {
          return wrap;
        }
        return expandToMaxWidth
            ? ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Align(alignment: _wrapToAlign(alignment), child: wrap),
              )
            : Align(alignment: _wrapToAlign(alignment), child: wrap);
      },
    );
  }

  Alignment _wrapToAlign(WrapAlignment wrap) {
    return switch (wrap) {
      WrapAlignment.end => Alignment.centerRight,
      WrapAlignment.center => Alignment.center,
      WrapAlignment.spaceBetween => Alignment.center,
      WrapAlignment.spaceAround => Alignment.center,
      WrapAlignment.spaceEvenly => Alignment.center,
      _ => Alignment.centerLeft,
    };
  }
}
