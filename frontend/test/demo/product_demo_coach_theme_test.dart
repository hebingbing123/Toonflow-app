import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/demo/product_demo_coach_theme.dart';
import 'package:openflow_app/design_system/tokens.dart';

void main() {
  testWidgets('ProductDemoCoachTheme uses primary for mainline chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[
          StudioTokens.dark,
        ]),
        home: Builder(
          builder: (context) {
            final tokens = StudioTokens.of(context);
            final coach = ProductDemoCoachTheme.of(tokens, isOptionalUtility: false);
            final optional =
                ProductDemoCoachTheme.of(tokens, isOptionalUtility: true);
            expect(coach.accent, tokens.primary);
            expect(optional.optionalAccent, tokens.warning);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
