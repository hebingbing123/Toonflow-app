import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expands [StudioCollapsibleFilterPanel] when present and collapsed.
Future<void> expandStudioCollapsibleFilterPanel(WidgetTester tester) async {
  final panel = find.byKey(const Key('studio_collapsible_filter_panel'));
  if (panel.evaluate().isEmpty) {
    return;
  }

  final tile = tester.widget<ExpansionTile>(panel);
  if (tile.initiallyExpanded) {
    return;
  }

  await tester.tap(panel);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Pumps [widget] and expands any Studio collapsible filter toolbar.
Future<void> pumpWithExpandedStudioFilters(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  await expandStudioCollapsibleFilterPanel(tester);
}
