import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/studio_scheduler.dart';

void main() {
  tearDown(StudioScheduler.resetForTest);

  test('scheduleOnceUntil defers duplicate keys until post-frame', () {
    var count = 0;
    StudioScheduler.scheduleOnceUntil('a', () => count++);
    StudioScheduler.scheduleOnceUntil('a', () => count++);
    expect(count, 0);
  });

  testWidgets('scheduleOnceUntil invokes callback after frame', (
    WidgetTester tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          StudioScheduler.scheduleOnceUntil('widget_probe', () {
            count++;
            setState(() {});
          });
          return const SizedBox();
        },
      ),
    );
    await tester.pump();
    expect(count, greaterThanOrEqualTo(1));
  });

  test('scheduleOncePerFrame queues callbacks without running synchronously', () {
    var count = 0;
    StudioScheduler.scheduleOncePerFrame(() => count++);
    StudioScheduler.scheduleOncePerFrame(() => count++);
    expect(count, 0);
  });
}
