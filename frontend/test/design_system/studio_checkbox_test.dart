import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_checkbox.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  testWidgets('StudioCheckbox toggles via label tap', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: Scaffold(
          body: StudioCheckbox(
            value: value,
            label: 'Accept',
            onChanged: (v) => value = v ?? false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(value, isTrue);
  });
}
