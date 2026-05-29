import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/studio_responsive_layout.dart';

void main() {
  testWidgets('StudioResponsiveLayout picks mobile builder on narrow width',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            child: StudioResponsiveLayout(
              mobile: (_) => const Text('mobile'),
              tablet: (_) => const Text('tablet'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('mobile'), findsOneWidget);
  });

  testWidgets('StudioResponsiveLayout falls back to mobile on tablet when omitted',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 800,
            child: StudioResponsiveLayout(
              mobile: (_) => const Text('mobile'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('mobile'), findsOneWidget);
  });
}
