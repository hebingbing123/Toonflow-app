import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/design_system/components/studio_primary_button.dart';

void main() {
  testWidgets('Studio dark theme exposes tokens extension', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: Builder(
          builder: (context) {
            final tokens = StudioTokens.of(context);
            expect(tokens.bgBase, StudioTokens.dark.bgBase);
            return StudioPrimaryButton(
              label: 'Continue',
              onPressed: () {},
            );
          },
        ),
      ),
    );
    expect(find.text('Continue'), findsOneWidget);
  });
}
