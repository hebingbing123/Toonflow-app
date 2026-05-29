import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_sparkline_chart.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  testWidgets('StudioSparklineChart paints for two or more points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        home: const Scaffold(
          body: StudioSparklineChart(
            values: <double>[1, 3, 2, 5],
            semanticsLabel: 'Trend',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(StudioSparklineChart), findsOneWidget);
  });
}
