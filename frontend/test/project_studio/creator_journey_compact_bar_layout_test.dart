import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_studio/creator_journey_compact_bar.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/ignore_layout_overflow.dart';

void main() {
  testWidgets('compact bar does not overflow at storyboard pane width', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.binding.setSurfaceSize(const Size(820, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 820,
              child: CreatorJourneyCompactBar(
                currentStep: StudioStep.storyboard,
                failedJobCount: 0,
                onSelectStep: (_) {},
                onBackToProjects: () {},
                onWorkspaceMenuSelected: (_) {},
                onOpenStepSetup: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.studioScriptStepSetupOpen), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('compact bar trailing actions align to the right edge', (
    WidgetTester tester,
  ) async {
    const barWidth = 1000.0;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.binding.setSurfaceSize(const Size(barWidth, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: barWidth,
              child: CreatorJourneyCompactBar(
                currentStep: StudioStep.deliver,
                failedJobCount: 0,
                onSelectStep: (_) {},
                onBackToProjects: () {},
                onWorkspaceMenuSelected: (_) {},
                onOpenReviewPackMilestone: () {},
                onOpenStepSetup: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final barRect = tester.getRect(find.byType(CreatorJourneyCompactBar));
    final trailingRect = tester.getRect(find.byIcon(Icons.tune_rounded));
    expect(
      barRect.right - trailingRect.right,
      lessThan(16),
      reason: 'workspace menu should sit on the compact bar right edge',
    );
    expectNoBenignQueuedExceptions(tester);
  });
}
