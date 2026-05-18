import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:openflow_app/shell/platform_short_drama_pipeline_strip.dart';

void main() {
  testWidgets('PlatformShortDramaPipelineStrip invokes callback per chip',
      (WidgetTester tester) async {
    ProductWorkspacePane? last;
    await tester.binding.setSurfaceSize(const Size(1400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PlatformShortDramaPipelineStrip(
            onSelectPane: (pane) => last = pane,
            jobsPaneEnabled: true,
            qualityPaneEnabled: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).at(1));
    await tester.pump();
    expect(last, ProductWorkspacePane.scriptWorkspace);

    await tester.tap(find.byType(FilterChip).last);
    await tester.pump();
    expect(last, ProductWorkspacePane.shortVideoSpace);
  });
}
