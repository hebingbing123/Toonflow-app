import 'package:flutter/material.dart';

/// Responsive filter row: horizontal wrap on wide screens, stacked column on narrow.
class StudioFilterRow extends StatelessWidget {
  const StudioFilterRow({
    super.key,
    required this.children,
    this.wideBreakpoint = 720,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final List<Widget> children;
  final double wideBreakpoint;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= wideBreakpoint) {
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: runSpacing),
              children[i],
            ],
          ],
        );
      },
    );
  }
}
