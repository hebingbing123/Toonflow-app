import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_collapsible_filter_panel.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('StudioCollapsibleFilterPanel is collapsed when collapsible', (
    WidgetTester tester,
  ) async {
    const marker = Key('filter_child_marker');
    await tester.pumpWidget(
      studioGoldenApp(
        child: StudioCollapsibleFilterPanel(
          collapsible: true,
          child: const SizedBox(key: marker, height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(marker), findsNothing);
    expect(find.byKey(const Key('studio_collapsible_filter_panel')), findsOneWidget);

    await tester.tap(find.text(AppLocalizationsZh().studioFilterToolbarTitle));
    await tester.pumpAndSettle();

    expect(find.byKey(marker), findsOneWidget);
  });

  testWidgets('default inline mode shows filter row without ExpansionTile', (
    WidgetTester tester,
  ) async {
    const marker = Key('inline_filter');
    await tester.pumpWidget(
      studioGoldenApp(
        child: const StudioCollapsibleFilterPanel(
          child: SizedBox(key: marker, height: 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(marker), findsOneWidget);
    expect(find.byKey(const Key('studio_collapsible_filter_panel')), findsNothing);
  });
}
