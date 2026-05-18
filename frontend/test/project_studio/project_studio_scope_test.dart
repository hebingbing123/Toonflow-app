import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/project_studio_scope.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/rust_api.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

ProjectStudioHost _hostFor(
  StudioReadinessSnapshot readiness, {
  List<StudioReadinessSnapshot>? received,
}) {
  received?.add(readiness);
  return ProjectStudioHost(
    projectNumericId: 42,
    projectUuid: 'project-42',
    projectName: 'Project Delta',
    accessToken: null,
    home: readiness.home,
    assetsOverview: readiness.assetsOverview,
    readiness: readiness.readiness,
    initialStep: StudioStep.script,
    completedSteps: readiness.completedSteps,
    onExit: () {},
    onStepChanged: (_) {},
    onOpenAgentDrawer: () {},
    onOpenAssetEditor: (_) {},
    onRunHarnessAgent: (_) async {},
    buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
  );
}

void main() {
  testWidgets('project studio scope shows loading while snapshot is pending', (
    tester,
  ) async {
    final completer = Completer<StudioReadinessSnapshot>();

    await tester.pumpWidget(
      _wrapApp(
        child: ProjectStudioScope(
          accessToken: 'token',
          projectNumericId: 42,
          projectUuid: 'project-42',
          projectName: 'Project Delta',
          initialStep: StudioStep.script,
          loadSnapshot: (accessToken, projectUuid) => completer.future,
          hostFactory: (readiness, refreshSnapshot) => _hostFor(readiness),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const StudioReadinessSnapshot(completedSteps: 4));
    await tester.pumpAndSettle();
    expect(find.text('Project Delta'), findsOneWidget);
    expect(find.text('4/6'), findsOneWidget);
  });

  testWidgets('project studio scope builds page from loaded snapshot', (
    tester,
  ) async {
    final received = <StudioReadinessSnapshot>[];

    await tester.pumpWidget(
      _wrapApp(
        child: ProjectStudioScope(
          accessToken: 'token',
          projectNumericId: 42,
          projectUuid: 'project-42',
          projectName: 'Project Delta',
          initialStep: StudioStep.script,
          loadSnapshot: (accessToken, projectUuid) async =>
              const StudioReadinessSnapshot(completedSteps: 5),
          hostFactory: (readiness, refreshSnapshot) =>
              _hostFor(readiness, received: received),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(received, hasLength(1));
    expect(received.single.completedSteps, 5);
    expect(find.text('Project Delta'), findsOneWidget);
    expect(find.text('5/6'), findsOneWidget);
  });

  testWidgets('project studio scope refresh callback reloads snapshot', (
    tester,
  ) async {
    final received = <StudioReadinessSnapshot>[];
    Future<void> Function()? refreshSnapshot;
    var loadCount = 0;

    await tester.pumpWidget(
      _wrapApp(
        child: ProjectStudioScope(
          accessToken: 'token',
          projectNumericId: 42,
          projectUuid: 'project-42',
          projectName: 'Project Delta',
          initialStep: StudioStep.script,
          loadSnapshot: (accessToken, projectUuid) async {
            loadCount += 1;
            return StudioReadinessSnapshot(completedSteps: loadCount + 2);
          },
          hostFactory: (readiness, refresh) {
            refreshSnapshot = refresh;
            return _hostFor(readiness, received: received);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(received, hasLength(1));
    expect(received.single.completedSteps, 3);
    expect(find.text('3/6'), findsOneWidget);

    await refreshSnapshot!();
    await tester.pumpAndSettle();

    expect(received, hasLength(2));
    expect(received.last.completedSteps, 4);
    expect(find.text('4/6'), findsOneWidget);
  });

  testWidgets(
    'project studio scope renders cockpit content from project home',
    (tester) async {
      const home = ProjectHome(
        project: ProjectRow(
          id: 'project-42',
          numericId: 42,
          name: 'Project Delta',
          intro: null,
          projectType: null,
          imageModel: null,
          imageQuality: null,
          videoModel: null,
          artStyle: null,
          directorManual: null,
          mode: null,
          videoRatio: null,
          createTimeMs: null,
          artStylePack: null,
          storyStylePack: null,
          targetMarket: null,
          targetPlatforms: null,
          durationStrategy: null,
          voiceProfile: null,
          subtitleStyle: null,
          bgmStrategy: null,
          projectAccessMode: 'restricted',
          projectAccessRole: 'editor',
        ),
        stats: ProjectStats(
          scriptCount: 1,
          storyboardCount: 3,
          roleCount: 1,
          novelCount: 1,
          videoCount: 0,
        ),
        readinessScore: 72,
        readinessSummary: 'Ready to move.',
        onboarding: ProjectHomeOnboarding(
          complete: true,
          checklist: <ProjectHomeChecklistItem>[],
        ),
        styleBibleReady: true,
        cockpit: ProjectHomeCockpit(
          headline: 'Project Delta is ready for the next push.',
          subheadline: 'Focus on getting the first video out.',
          primaryAction: ProjectHomeAction(
            key: 'generate_video',
            title: 'Start the first video pass',
            detail:
                'The fastest way to raise confidence is to ship one sample.',
            targetStep: 'video',
            ctaLabel: 'Enter video stage',
            launchIntent: ProjectHomeLaunchIntent(targetStep: 'video'),
          ),
          secondaryActions: <ProjectHomeAction>[
            ProjectHomeAction(
              key: 'review_storyboard',
              title: 'Review storyboard readiness',
              detail: 'Check the shots that still block generation.',
              targetStep: 'storyboard',
              ctaLabel: 'Check storyboard state',
              launchIntent: ProjectHomeLaunchIntent(targetStep: 'storyboard'),
            ),
          ],
          metrics: <ProjectHomeMetric>[
            ProjectHomeMetric(
              key: 'readiness',
              label: 'Project readiness',
              value: '72/100',
              detail: 'Most foundations are already in place.',
              launchIntent: ProjectHomeLaunchIntent(targetStep: 'video'),
            ),
          ],
          starterTemplates: <ProjectHomeStarterTemplate>[
            ProjectHomeStarterTemplate(
              key: 'starter_trailer',
              title: 'Sample-first route',
              detail: 'Get one clip out before broadening the scope.',
              targetStep: 'video',
              ctaLabel: 'Run sample route',
              launchIntent: ProjectHomeLaunchIntent(
                targetStep: 'video',
                agentKind: 'grid_prompt_generator',
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrapApp(
          child: ProjectStudioScope(
            accessToken: 'token',
            projectNumericId: 42,
            projectUuid: 'project-42',
            projectName: 'Project Delta',
            initialStep: StudioStep.script,
            loadSnapshot: (accessToken, projectUuid) async =>
                const StudioReadinessSnapshot(completedSteps: 5, home: home),
            hostFactory: (readiness, refreshSnapshot) => _hostFor(readiness),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Project Delta is ready for the next push.'),
        findsOneWidget,
      );
      expect(find.text('Enter video stage'), findsOneWidget);
      expect(find.text('Sample-first route'), findsOneWidget);
      expect(find.text('72/100'), findsOneWidget);
    },
  );

  testWidgets('project studio scope renders asset hub during assets step', (
    tester,
  ) async {
    const assetsOverview = ProjectAssetsOverview(
      schemaVersion: 1,
      totalCount: 4,
      candidateCounts: AssetsOverviewCandidateCounts(
        pending: 1,
        linked: 2,
        ignored: 0,
        unset: 1,
      ),
      byAssetType: <AssetsOverviewTypeGroup>[],
      hub: AssetsOverviewHub(
        headline: 'The project already has a usable role library.',
        subheadline: 'Anchor the last character before moving to storyboard.',
        primaryAction: AssetsOverviewHubAction(
          key: 'anchor_characters',
          title: 'Finish character anchors',
          detail: 'One project character is still missing an asset anchor.',
          targetStep: 'assets',
          ctaLabel: 'Fix anchors',
        ),
        metrics: <AssetsOverviewHubMetric>[
          AssetsOverviewHubMetric(
            key: 'roles',
            label: 'Role assets',
            value: '3',
            detail: 'One still has no project character attached.',
          ),
        ],
        characterSummaries: <AssetsOverviewCharacterSummary>[
          AssetsOverviewCharacterSummary(
            characterId: 'char-1',
            name: 'Lead',
            assetId: null,
            assetName: null,
            linkedScriptNumericIds: <int>[11],
            hasVoiceConfig: false,
            missingAssetAnchor: true,
          ),
        ],
        reusableRoleAssets: <AssetsOverviewRoleSummary>[
          AssetsOverviewRoleSummary(
            assetId: 'asset-1',
            numericId: 7,
            name: 'Lead Model',
            candidateStatus: 'linked',
            linkedScriptNumericIds: <int>[11, 12],
            linkedCharacterNames: <String>['Lead'],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _wrapApp(
        child: ProjectStudioScope(
          accessToken: 'token',
          projectNumericId: 42,
          projectUuid: 'project-42',
          projectName: 'Project Delta',
          initialStep: StudioStep.assets,
          loadSnapshot: (accessToken, projectUuid) async =>
              const StudioReadinessSnapshot(
                completedSteps: 4,
                assetsOverview: assetsOverview,
              ),
          hostFactory: (readiness, refreshSnapshot) => ProjectStudioHost(
            projectNumericId: 42,
            projectUuid: 'project-42',
            projectName: 'Project Delta',
            accessToken: null,
            assetsOverview: readiness.assetsOverview,
            initialStep: StudioStep.assets,
            completedSteps: readiness.completedSteps,
            onExit: () {},
            onStepChanged: (_) {},
            onOpenAgentDrawer: () {},
            onOpenAssetEditor: (_) {},
            onRunHarnessAgent: (_) async {},
            buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The project already has a usable role library.'),
      findsOneWidget,
    );
    expect(find.text('Fix anchors'), findsOneWidget);
    expect(find.text('Reusable role assets'), findsOneWidget);
    expect(find.text('#7 Lead Model'), findsOneWidget);
  });

  testWidgets(
    'project studio scope shows error text when snapshot load fails',
    (tester) async {
      await tester.pumpWidget(
        _wrapApp(
          child: ProjectStudioScope(
            accessToken: 'token',
            projectNumericId: 42,
            projectUuid: 'project-42',
            projectName: 'Project Delta',
            initialStep: StudioStep.script,
            loadSnapshot: (accessToken, projectUuid) async {
              throw StateError('boom');
            },
            hostFactory: (readiness, refreshSnapshot) => _hostFor(readiness),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bad state: boom'), findsOneWidget);
      expect(find.text('Project Delta'), findsNothing);
    },
  );
}
