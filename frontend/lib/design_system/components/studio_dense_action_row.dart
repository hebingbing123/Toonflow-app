import 'package:flutter/material.dart';

import '../tokens.dart';

/// Horizontal action strip: keeps controls on one line with scroll when needed.
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
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _spaced(children),
        );
        if (!constraints.hasBoundedWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: row,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: expandToMaxWidth
              ? ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Align(
                    alignment: _wrapToAlign(alignment),
                    child: row,
                  ),
                )
              : Align(
                  alignment: _wrapToAlign(alignment),
                  child: row,
                ),
        );
      },
    );
  }

  List<Widget> _spaced(List<Widget> items) {
    return <Widget>[
      for (var i = 0; i < items.length; i++) ...<Widget>[
        if (i > 0) SizedBox(width: spacing),
        items[i],
      ],
    ];
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
