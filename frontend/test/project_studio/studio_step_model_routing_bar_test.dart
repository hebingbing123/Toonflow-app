import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/project_studio_model_routing_scope.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/project_studio/studio_step_model_routing_bar.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  testWidgets('script step routing bar shows primary title', (
    WidgetTester tester,
  ) async {
    const routing = ProjectModelRoutingResponse(
      projectId: '00000000-0000-0000-0000-000000000001',
      defaults: ProjectModelRoutingDefaults(textModel: '1:gpt-4.1-mini'),
      steps: <String, Map<String, String>>{
        'script': <String, String>{'text': '1:gpt-4o-mini'},
      },
      effective: <ModelRoutingEffectiveEntry>[
        ModelRoutingEffectiveEntry(
          step: 'script',
          slot: 'text',
          modelId: '1:gpt-4o-mini',
          source: 'step_override',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioModelRoutingScope(
            routing: routing,
            child: StudioStepModelRoutingBar(
              accessToken: 'test-token',
              projectId: routing.projectId,
              step: StudioStep.script,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Step model routing'), findsOneWidget);
  });

  testWidgets('deliver step shows inherit copy from scope', (
    WidgetTester tester,
  ) async {
    const routing = ProjectModelRoutingResponse(
      projectId: '00000000-0000-0000-0000-000000000001',
      defaults: ProjectModelRoutingDefaults(),
      steps: const <String, Map<String, String>>{},
      effective: <ModelRoutingEffectiveEntry>[
        ModelRoutingEffectiveEntry(
          step: 'deliver',
          slot: 'video',
          modelId: '1:video-model',
          source: 'step_override',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioModelRoutingScope(
            routing: routing,
            child: StudioStepModelRoutingBar(
              accessToken: 'test-token',
              projectId: routing.projectId,
              step: StudioStep.deliver,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('inherits the project\'s delivery routing'),
      findsOneWidget,
    );
  });
}
