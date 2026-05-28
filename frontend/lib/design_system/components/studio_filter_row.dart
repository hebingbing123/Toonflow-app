import 'package:flutter/material.dart';

import '../tokens.dart';

/// Wide layout for [StudioFilterRow].
enum StudioFilterWideLayout {
  /// [Wrap] — many chips/buttons (compliance admin, stage overrides).
  wrap,

  /// Single [Row] on wide screens (未读 / 类型 / 搜索 / 刷新 toolbars).
  toolbarRow,
}

/// Responsive filter row: toolbar row on wide screens, wrap or column when needed.
class StudioFilterRow extends StatelessWidget {
  const StudioFilterRow({
    super.key,
    required this.children,
    this.wideBreakpoint = 720,
    this.wideLayout = StudioFilterWideLayout.wrap,
    this.spacing = StudioSpacing.xs,
    this.runSpacing = StudioSpacing.xs,
  });

  final List<Widget> children;
  final double wideBreakpoint;

  /// [toolbarRow] keeps filters on one line when width allows (PC / web).
  final StudioFilterWideLayout wideLayout;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spacedColumn(children.map(_adaptForColumn).toList()),
          );
        }
        return switch (wideLayout) {
          StudioFilterWideLayout.toolbarRow => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: _spacedRow(children.map(_adaptForRow).toList()),
          ),
          StudioFilterWideLayout.wrap => Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        };
      },
    );
  }

  List<Widget> _spacedColumn(List<Widget> items) {
    return <Widget>[
      for (var i = 0; i < items.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: runSpacing),
        items[i],
      ],
    ];
  }

  List<Widget> _spacedRow(List<Widget> items) {
    return <Widget>[
      for (var i = 0; i < items.length; i++) ...<Widget>[
        if (i > 0) SizedBox(width: spacing),
        items[i],
      ],
    ];
  }

  static Widget _adaptForRow(Widget child) {
    if (child is Expanded) {
      return child;
    }
    if (child is Flexible) {
      return child;
    }
    if (child is SizedBox) {
      if (child.width == double.infinity && child.child != null) {
        return Expanded(child: child.child!);
      }
      return child;
    }
    if (child is Align) {
      final aligned = child.child;
      if (aligned != null) {
        return aligned;
      }
    }
    return child;
  }

  static Widget _adaptForColumn(Widget child) {
    if (child is Expanded) {
      return SizedBox(width: double.infinity, child: child.child);
    }
    if (child is Flexible) {
      return SizedBox(width: double.infinity, child: child.child);
    }
    if (child is SizedBox &&
        child.width == double.infinity &&
        child.child != null) {
      return SizedBox(width: double.infinity, child: child.child);
    }
    return child;
  }
}
