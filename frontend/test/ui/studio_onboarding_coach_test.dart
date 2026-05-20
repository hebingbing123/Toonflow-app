import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_onboarding_coach.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('shows first-run coach when not yet seen', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      studioGoldenApp(
        child: const StudioOnboardingCoach(
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('项目'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
  });

  testWidgets('hides coach after markSeen', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StudioOnboardingCoach.markSeen();

    await tester.pumpWidget(
      studioGoldenApp(
        child: const StudioOnboardingCoach(
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsNothing);
    expect(find.text('完成'), findsNothing);
  });
}
