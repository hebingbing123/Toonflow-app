import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openflow_app/design_system/components/studio_card.dart';
import 'package:openflow_app/design_system/components/studio_primary_button.dart';
import 'package:openflow_app/design_system/tokens.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  ThemeData testTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(primary: StudioTokens.dark.primary),
      extensions: <ThemeExtension<dynamic>>[StudioTokens.dark],
    );
  }

  testWidgets('StudioCard golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: StudioCard(child: Text('Studio')),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(StudioCard),
      matchesGoldenFile('goldens/studio_card.png'),
    );
  });

  testWidgets('StudioPrimaryButton golden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme(),
        home: Scaffold(
          body: Center(
            child: StudioPrimaryButton(
              label: 'Continue',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(StudioPrimaryButton),
      matchesGoldenFile('goldens/studio_primary_button.png'),
    );
  });
}
