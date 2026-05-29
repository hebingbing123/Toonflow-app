import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  testWidgets('studioFormPrimaryButtonStyle uses onPrimary label on light theme', (
    WidgetTester tester,
  ) async {
    final theme = buildStudioLightTheme(useBundledFonts: false);
    final scheme = theme.colorScheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            return Scaffold(
              backgroundColor: scheme.surface,
              body: Center(
                child: FilledButton(
                  style: studioFormPrimaryButtonStyle(context),
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump();

    final labelStyle = DefaultTextStyle.of(tester.element(find.text('Save'))).style;
    expect(labelStyle.color, scheme.onPrimary);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      scheme.onPrimary,
    );
    expect(
      button.style?.textStyle?.resolve(<WidgetState>{})?.color,
      scheme.onPrimary,
    );
  });

  testWidgets('studioFormButtonLabelMetrics omits explicit color', (
    WidgetTester tester,
  ) async {
    final theme = buildStudioLightTheme(useBundledFonts: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            final metrics = studioFormButtonLabelMetrics(context);
            expect(metrics.color, isNull);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pump();
  });
}
