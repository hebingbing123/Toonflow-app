import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_icon_button.dart';

void main() {
  testWidgets('StudioIconButton exposes Semantics label and Tooltip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioIconButton(
            icon: Icons.refresh,
            label: 'Reload projects',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Tooltip), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Reload projects' &&
            widget.properties.button == true,
      ),
      findsOneWidget,
    );
  });
}
