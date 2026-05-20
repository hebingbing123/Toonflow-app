import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/project_studio_scope.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/rust_api/core.dart';

void main() {
  testWidgets('ProjectStudioScope shows error callout on load failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProjectStudioScope(
          accessToken: 'token',
          projectNumericId: 1,
          projectUuid: '00000000-0000-4000-8000-000000000001',
          projectName: 'Test',
          initialStep: StudioStep.script,
          hostFactory: (snap, _) => ProjectStudioHost(
            projectNumericId: 1,
            projectUuid: '00000000-0000-4000-8000-000000000001',
            projectName: 'Test',
            accessToken: 'token',
            onExit: () {},
            onStepChanged: (_) {},
            onOpenAgentDrawer: () {},
            onRunHarnessAgent: (_) async {},
            buildStepBody: (_) => const SizedBox(),
          ),
          loadSnapshot: (_, __) async {
            throw RustApiException(
              'database_error',
              statusCode: 503,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StudioApiErrorCallout), findsOneWidget);
  });
}
