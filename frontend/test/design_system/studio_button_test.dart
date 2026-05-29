import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_button.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  testWidgets('StudioButton shows label and respects loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: Scaffold(
          body: StudioButton(
            label: 'Save',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('Save'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
