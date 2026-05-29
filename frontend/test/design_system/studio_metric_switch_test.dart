import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_metric_switch.dart';

void main() {
  testWidgets('StudioMetricSwitch rebuilds child when transitionKey changes', (
    WidgetTester tester,
  ) async {
    var key = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: <Widget>[
                  StudioMetricSwitch(
                    transitionKey: key,
                    child: Text('value $key'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => key = 2),
                    child: const Text('bump'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('value 1'), findsOneWidget);
    await tester.tap(find.text('bump'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('value 2'), findsOneWidget);
  });
}
