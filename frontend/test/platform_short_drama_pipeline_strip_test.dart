import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:openflow_app/shell/platform_short_drama_pipeline_strip.dart';

void main() {
  testWidgets('PlatformShortDramaPipelineStrip invokes callback per chip',
      (WidgetTester tester) async {
    ProductWorkspacePane? last;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformShortDramaPipelineStrip(
            onSelectPane: (pane) => last = pane,
            jobsPaneEnabled: true,
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ActionChip, '脚本'));
    await tester.pump();
    expect(last, ProductWorkspacePane.scriptWorkspace);

    await tester.tap(find.widgetWithText(ActionChip, '短视频'));
    await tester.pump();
    expect(last, ProductWorkspacePane.shortVideoSpace);
  });
}
