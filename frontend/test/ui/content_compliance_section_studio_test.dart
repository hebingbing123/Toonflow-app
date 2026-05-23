import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/content_compliance/controller.dart';
import 'package:openflow_app/content_compliance/section.dart';
import 'package:openflow_app/design_system/components/studio_skeleton.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('content compliance shows queue loading skeleton', (
    WidgetTester tester,
  ) async {
    final controller = ContentComplianceController(
      accessTokenProvider: () => 'token',
      onErrorChanged: (_) {},
    )
      ..queueEnabledOverride = true
      ..skipAutoLoadQueueOnMount = true
      ..loadingQueue = true;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContentComplianceSection(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StudioSkeleton), findsWidgets);
    expectNoBenignQueuedExceptions(tester);
  });
}
