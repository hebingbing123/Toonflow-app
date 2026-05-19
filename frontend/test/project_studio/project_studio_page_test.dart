import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _wrapRouterApp(GoRouter router) {
  return MaterialApp.router(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  test('project home launch intent parses from JSON payloads', () {
    final action = ProjectHomeAction.fromJson(<String, dynamic>{
      'key': 'mystery',
      'title': 'Open queue',
      'detail': 'Use the explicit task route.',
      'target_step': 'script',
      'cta_label': 'Open queue',
      'launch_intent': <String, dynamic>{
        'action': 'open_tasks',
        'notice': 'Explicit notice',
      },
    });
    final metric = ProjectHomeMetric.fromJson(<String, dynamic>{
      'key': 'weird_metric',
      'label': 'Role review',
      'value': '4',
      'detail': 'Use the asset target from payload.',
      'launch_intent': <String, dynamic>{'asset_target': 'confirm_candidates'},
    });
    final starter = ProjectHomeStarterTemplate.fromJson(<String, dynamic>{
      'key': 'odd_route',
      'title': 'Sample route',
      'detail': 'Use the explicit starter route.',
      'target_step': 'script',
      'cta_label': 'Run route',
      'launch_intent': <String, dynamic>{
        'target_step': 'video',
        'agent_kind': 'grid_prompt_generator',
      },
    });

    expect(action.launchIntent!.action, 'open_tasks');
    expect(action.launchIntent!.notice, 'Explicit notice');
    expect(metric.launchIntent!.assetTarget, 'confirm_candidates');
    expect(starter.launchIntent!.targetStep, 'video');
    expect(starter.launchIntent!.agentKind, 'grid_prompt_generator');
  });

  test('assets overview launch intent parses from JSON payloads', () {
    final action = AssetsOverviewHubAction.fromJson(<String, dynamic>{
      'key': 'opaque_asset_action',
      'title': 'Open asset editor',
      'detail': 'Trust the explicit asset target.',
      'target_step': 'storyboard',
      'cta_label': 'Open',
      'launch_intent': <String, dynamic>{
        'target_step': 'assets',
        'asset_target': 'confirm_candidates',
        'notice': 'Review pending candidates',
      },
    });
    final metric = AssetsOverviewHubMetric.fromJson(<String, dynamic>{
      'key': 'opaque_metric',
      'label': 'Candidate review',
      'value': '2',
      'detail': 'Trust the explicit asset target.',
      'launch_intent': <String, dynamic>{'asset_target': 'anchor_characters'},
    });

    expect(action.launchIntent!.targetStep, 'assets');
    expect(action.launchIntent!.assetTarget, 'confirm_candidates');
    expect(action.launchIntent!.notice, 'Review pending candidates');
    expect(metric.launchIntent!.assetTarget, 'anchor_characters');
  });

  test('project home JSON parsing rejects missing or empty launch intents', () {
    expect(
      () => ProjectHomeAction.fromJson(<String, dynamic>{
        'key': 'missing_intent',
        'title': 'Broken route',
        'detail': 'Server omitted launch_intent.',
        'target_step': 'script',
        'cta_label': 'Broken',
      }),
      throwsFormatException,
    );
    expect(
      () => ProjectHomeMetric.fromJson(<String, dynamic>{
        'key': 'empty_intent',
        'label': 'Broken metric',
        'value': '1',
        'detail': 'Server sent an empty launch_intent.',
        'launch_intent': <String, dynamic>{},
      }),
      throwsFormatException,
    );
    expect(
      () => ProjectHomeStarterTemplate.fromJson(<String, dynamic>{
        'key': 'null_intent',
        'title': 'Broken starter',
        'detail': 'Server sent a null launch_intent.',
        'target_step': 'video',
        'cta_label': 'Broken',
        'launch_intent': null,
      }),
      throwsFormatException,
    );
  });

  test(
    'assets overview JSON parsing rejects missing or empty launch intents',
    () {
      expect(
        () => AssetsOverviewHubAction.fromJson(<String, dynamic>{
          'key': 'missing_intent',
          'title': 'Broken route',
          'detail': 'Server omitted launch_intent.',
          'target_step': 'assets',
          'cta_label': 'Broken',
        }),
        throwsFormatException,
      );
      expect(
        () => AssetsOverviewHubMetric.fromJson(<String, dynamic>{
          'key': 'empty_intent',
          'label': 'Broken metric',
          'value': '1',
          'detail': 'Server sent an empty launch_intent.',
          'launch_intent': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'project studio restores saved step and runs step agent actions',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'studio_last_step_42': 'storyboard',
      });

      final stepChanges = <StudioStep>[];
      final agentKinds = <String>[];
      final assetTargets = <ProjectStudioAssetEditorTarget>[];

      final host = ProjectStudioHost(
        projectNumericId: 42,
        projectUuid: 'project-42',
        projectName: 'Project Delta',
        accessToken: null,
        initialStep: StudioStep.script,
        completedSteps: 3,
        conflictMessage: 'Version mismatch detected',
        onExit: () {},
        onStepChanged: stepChanges.add,
        onOpenAgentDrawer: () {},
        onOpenAssetEditor: assetTargets.add,
        onRunHarnessAgent: (kind) async {
          agentKinds.add(kind);
        },
        buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
      );

      await tester.pumpWidget(_wrapApp(child: ProjectStudioPage(host: host)));
      await tester.pumpAndSettle();

      expect(find.text('Project Delta'), findsOneWidget);
      expect(find.text('3/6'), findsOneWidget);
      expect(find.text('Version mismatch detected'), findsOneWidget);
      expect(find.text('body-storyboard'), findsOneWidget);
      expect(find.text('Break storyboard'), findsOneWidget);
      expect(find.text('Grid prompts'), findsOneWidget);
      expect(stepChanges, <StudioStep>[StudioStep.storyboard]);

      await tester.tap(find.text('Break storyboard'));
      await tester.pump();
      await tester.tap(find.text('Grid prompts'));
      await tester.pump();

      expect(agentKinds, <String>[
        'storyboard_breaker',
        'grid_prompt_generator',
      ]);
      expect(assetTargets, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('asset hub can open asset editor from assets step', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'assets',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      assetsOverview: const ProjectAssetsOverview(
        schemaVersion: 1,
        totalCount: 3,
        candidateCounts: AssetsOverviewCandidateCounts(
          pending: 1,
          linked: 1,
          ignored: 0,
          unset: 1,
        ),
        byAssetType: <AssetsOverviewTypeGroup>[],
        hub: AssetsOverviewHub(
          headline: 'Role library is almost ready.',
          subheadline: 'Open asset maintenance to close the remaining gaps.',
          primaryAction: AssetsOverviewHubAction(
            key: 'anchor_characters',
            title: 'Finish character anchors',
            detail: 'One character still needs an asset anchor.',
            targetStep: 'assets',
            ctaLabel: 'Fix anchors',
            launchIntent: ProjectHomeLaunchIntent(
              targetStep: 'assets',
              assetTarget: 'anchor_characters',
            ),
          ),
          metrics: <AssetsOverviewHubMetric>[],
          characterSummaries: <AssetsOverviewCharacterSummary>[],
          reusableRoleAssets: <AssetsOverviewRoleSummary>[],
        ),
      ),
      initialStep: StudioStep.assets,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/42/video',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fix anchors'));
    await tester.pump();

    expect(assetTargets, hasLength(1));
    expect(
      assetTargets.single.kind,
      ProjectStudioAssetEditorTargetKind.anchorCharacters,
    );
    expect(assetTargets.single.notice, isNotEmpty);
  });

  testWidgets(
    'storyboard readiness bridge opens asset editor with storyboard focus',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'studio_last_step_42': 'storyboard',
      });

      final assetTargets = <ProjectStudioAssetEditorTarget>[];
      final host = ProjectStudioHost(
        projectNumericId: 42,
        projectUuid: 'project-42',
        projectName: 'Project Delta',
        accessToken: null,
        readiness: const ProjectShortVideoReadiness(
          schemaVersion: 1,
          rollup: ShortVideoReadinessRollup(
            totalStoryboards: 2,
            readyCount: 0,
            blockedCount: 2,
            byReason: <ShortVideoReadinessReasonRollup>[
              ShortVideoReadinessReasonRollup(
                reason: 'candidate_pending',
                storyboardCount: 1,
              ),
            ],
          ),
          storyboards: <StoryboardShortVideoReadiness>[
            StoryboardShortVideoReadiness(
              storyboardId: 'sb-101',
              storyboardNumericId: 101,
              scriptNumericId: 7,
              sbIndex: 3,
              hasBasicSlot: true,
              hasPromptContext: true,
              hasReferenceVisual: true,
              hasLiveActionReferenceShots: false,
              hasLiveActionPerformanceNotes: false,
              candidateCleared: false,
              noBlockingJob: true,
              readyForGeneration: false,
              blockingReasons: <String>['candidate_pending'],
            ),
          ],
        ),
        assetsOverview: const ProjectAssetsOverview(
          schemaVersion: 1,
          totalCount: 3,
          candidateCounts: AssetsOverviewCandidateCounts(
            pending: 1,
            linked: 1,
            ignored: 0,
            unset: 1,
          ),
          byAssetType: <AssetsOverviewTypeGroup>[
            AssetsOverviewTypeGroup(
              assetType: 'role',
              items: <AssetsOverviewItem>[
                AssetsOverviewItem(
                  assetId: 'asset-901',
                  numericId: 901,
                  name: 'Lead Role',
                  assetType: 'role',
                  candidateStatus: 'pending',
                  linkedScriptNumericIds: <int>[7],
                ),
              ],
            ),
          ],
          hub: AssetsOverviewHub(
            headline: 'Asset hub is almost ready.',
            subheadline: 'A few anchors still block storyboard progress.',
            primaryAction: AssetsOverviewHubAction(
              key: 'anchor_characters',
              title: 'Anchor characters',
              detail: 'One character still needs an anchor.',
              targetStep: 'assets',
              ctaLabel: 'Fix anchors',
              launchIntent: ProjectHomeLaunchIntent(
                assetTarget: 'anchor_characters',
              ),
            ),
            metrics: <AssetsOverviewHubMetric>[],
            characterSummaries: <AssetsOverviewCharacterSummary>[
              AssetsOverviewCharacterSummary(
                characterId: 'character-1',
                name: 'Aster',
                assetId: null,
                assetName: null,
                linkedScriptNumericIds: <int>[7],
                hasVoiceConfig: false,
                missingAssetAnchor: true,
              ),
            ],
            reusableRoleAssets: <AssetsOverviewRoleSummary>[],
          ),
        ),
        initialStep: StudioStep.script,
        completedSteps: 3,
        onExit: () {},
        onStepChanged: (_) {},
        onOpenAgentDrawer: () {},
        onOpenAssetEditor: assetTargets.add,
        onRunHarnessAgent: (_) async {},
        buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
      );

      await tester.pumpWidget(_wrapApp(child: ProjectStudioPage(host: host)));
      await tester.pumpAndSettle();

      expect(find.text('Storyboard asset blockers'), findsOneWidget);
      expect(find.text('Review candidates'), findsOneWidget);
      expect(find.text('Fix anchors'), findsOneWidget);

      await tester.tap(find.text('Review candidates').first);
      await tester.pump();

      expect(assetTargets, hasLength(1));
      expect(
        assetTargets.single.kind,
        ProjectStudioAssetEditorTargetKind.confirmCandidates,
      );
      expect(assetTargets.single.preferredScriptNumericId, 7);
      expect(assetTargets.single.preferredAssetNumericId, 901);
      expect(assetTargets.single.preferredStoryboardNumericId, 101);
      expect(
        assetTargets.single.notice,
        contains(
          'Storyboard #101 is still blocked by pending candidate assets.',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('asset hub primary action honors explicit launch intent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'assets',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final stepChanges = <StudioStep>[];
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      assetsOverview: const ProjectAssetsOverview(
        schemaVersion: 1,
        totalCount: 3,
        candidateCounts: AssetsOverviewCandidateCounts(
          pending: 1,
          linked: 1,
          ignored: 0,
          unset: 1,
        ),
        byAssetType: <AssetsOverviewTypeGroup>[
          AssetsOverviewTypeGroup(
            assetType: 'role',
            items: <AssetsOverviewItem>[
              AssetsOverviewItem(
                assetId: 'asset-1',
                numericId: 91,
                name: 'Lead Asset',
                assetType: 'role',
                candidateStatus: 'pending',
                linkedScriptNumericIds: <int>[7],
              ),
            ],
          ),
        ],
        hub: AssetsOverviewHub(
          headline: 'Asset hub listens to explicit intents now.',
          subheadline: 'The payload should route to candidate review.',
          primaryAction: AssetsOverviewHubAction(
            key: 'opaque_server_action',
            title: 'Review pending candidates',
            detail: 'Use launch intent, not the key.',
            targetStep: 'storyboard',
            ctaLabel: 'Review candidates',
            launchIntent: ProjectHomeLaunchIntent(
              targetStep: 'assets',
              assetTarget: 'confirm_candidates',
              notice: 'Review pending candidates',
            ),
          ),
          metrics: <AssetsOverviewHubMetric>[],
          characterSummaries: <AssetsOverviewCharacterSummary>[
            AssetsOverviewCharacterSummary(
              characterId: 'character-1',
              name: 'Lead',
              assetId: null,
              assetName: null,
              linkedScriptNumericIds: <int>[7],
              hasVoiceConfig: false,
              missingAssetAnchor: true,
            ),
          ],
          reusableRoleAssets: <AssetsOverviewRoleSummary>[],
        ),
      ),
      initialStep: StudioStep.assets,
      onExit: () {},
      onStepChanged: stepChanges.add,
      onOpenAgentDrawer: () {},
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/42/video',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review candidates'));
    await tester.pump();

    expect(assetTargets, hasLength(1));
    expect(
      assetTargets.single.kind,
      ProjectStudioAssetEditorTargetKind.confirmCandidates,
    );
    expect(assetTargets.single.preferredAssetNumericId, 91);
    expect(assetTargets.single.notice, 'Review pending candidates');
    expect(stepChanges, isNot(contains(StudioStep.storyboard)));
  });

  testWidgets('asset hub metrics honor explicit launch intents only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'assets',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final stepChanges = <StudioStep>[];
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      assetsOverview: const ProjectAssetsOverview(
        schemaVersion: 1,
        totalCount: 3,
        candidateCounts: AssetsOverviewCandidateCounts(
          pending: 1,
          linked: 1,
          ignored: 0,
          unset: 0,
        ),
        byAssetType: <AssetsOverviewTypeGroup>[
          AssetsOverviewTypeGroup(
            assetType: 'role',
            items: <AssetsOverviewItem>[
              AssetsOverviewItem(
                assetId: 'asset-1',
                numericId: 33,
                name: 'Lead Asset',
                assetType: 'role',
                candidateStatus: 'pending',
                linkedScriptNumericIds: <int>[7],
              ),
            ],
          ),
        ],
        hub: AssetsOverviewHub(
          headline: 'Metrics should drill into the right tools.',
          subheadline: 'Both metrics use explicit launch intents.',
          primaryAction: AssetsOverviewHubAction(
            key: 'opaque_asset_action',
            title: 'Anchor roles',
            detail: 'Primary action is not the point of this test.',
            targetStep: 'assets',
            ctaLabel: 'Open editor',
            launchIntent: ProjectHomeLaunchIntent(
              targetStep: 'assets',
              assetTarget: 'anchor_characters',
            ),
          ),
          metrics: <AssetsOverviewHubMetric>[
            AssetsOverviewHubMetric(
              key: 'candidate_load',
              label: 'Candidate review',
              value: '1',
              detail: 'Use explicit intent to open pending candidates.',
              launchIntent: ProjectHomeLaunchIntent(
                assetTarget: 'confirm_candidates',
                notice: 'Review pending candidates',
              ),
            ),
            AssetsOverviewHubMetric(
              key: 'reuse',
              label: 'Cross-script reuse',
              value: '0',
              detail: 'Use explicit intent to open role reuse review.',
              launchIntent: ProjectHomeLaunchIntent(
                assetTarget: 'link_roles_to_scripts',
              ),
            ),
          ],
          characterSummaries: <AssetsOverviewCharacterSummary>[],
          reusableRoleAssets: <AssetsOverviewRoleSummary>[
            AssetsOverviewRoleSummary(
              assetId: 'asset-1',
              numericId: 33,
              name: 'Lead Asset',
              candidateStatus: 'linked',
              linkedScriptNumericIds: <int>[7, 8],
              linkedCharacterNames: <String>['Lead'],
            ),
          ],
        ),
      ),
      initialStep: StudioStep.assets,
      onExit: () {},
      onStepChanged: stepChanges.add,
      onOpenAgentDrawer: () {},
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/assets',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/assets',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Candidate review'));
    await tester.pump();
    await tester.tap(find.text('Cross-script reuse'));
    await tester.pump();

    expect(assetTargets, hasLength(2));
    expect(
      assetTargets.first.kind,
      ProjectStudioAssetEditorTargetKind.confirmCandidates,
    );
    expect(assetTargets.first.preferredAssetNumericId, 33);
    expect(assetTargets.first.preferredScriptNumericId, 7);
    expect(assetTargets.first.notice, 'Review pending candidates');
    expect(
      assetTargets.last.kind,
      ProjectStudioAssetEditorTargetKind.reviewRoleReuse,
    );
    expect(assetTargets.last.preferredAssetNumericId, 33);
    expect(assetTargets.last.preferredScriptNumericId, 7);
    expect(stepChanges, isNot(contains(StudioStep.storyboard)));
    expect(stepChanges, isNot(contains(StudioStep.video)));
  });

  testWidgets('cockpit actions route to tasks, asset editor, and agents', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'script',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final agentKinds = <String>[];
    var taskOpenCount = 0;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      home: const ProjectHome(
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
          storyboardCount: 2,
          roleCount: 1,
          novelCount: 0,
          videoCount: 0,
        ),
        readinessScore: 61,
        readinessSummary: 'Keep the production loop moving.',
        onboarding: ProjectHomeOnboarding(
          complete: true,
          checklist: <ProjectHomeChecklistItem>[],
        ),
        styleBibleReady: true,
        cockpit: ProjectHomeCockpit(
          headline: 'Project Delta needs one strong execution push.',
          subheadline: 'Use the cockpit to jump straight into the blocker.',
          primaryAction: ProjectHomeAction(
            key: 'opaque_task_route',
            title: 'Check queued and failed jobs',
            detail: 'Look at the jobs that still block delivery.',
            targetStep: 'tasks',
            ctaLabel: 'Open task center',
            launchIntent: ProjectHomeLaunchIntent(action: 'open_tasks'),
          ),
          secondaryActions: <ProjectHomeAction>[
            ProjectHomeAction(
              key: 'opaque_asset_route',
              title: 'Clear candidate review',
              detail: 'Confirm the pending role matches before storyboard.',
              targetStep: 'assets',
              ctaLabel: 'Review candidates',
              launchIntent: ProjectHomeLaunchIntent(
                assetTarget: 'confirm_candidates',
              ),
            ),
            ProjectHomeAction(
              key: 'opaque_agent_route',
              title: 'Break the next storyboard pass',
              detail: 'Generate the shot breakdown from the script draft.',
              targetStep: 'storyboard',
              ctaLabel: 'Break storyboard',
              launchIntent: ProjectHomeLaunchIntent(
                agentKind: 'storyboard_breaker',
              ),
            ),
          ],
          metrics: <ProjectHomeMetric>[],
          starterTemplates: <ProjectHomeStarterTemplate>[],
        ),
      ),
      initialStep: StudioStep.script,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onOpenTasks: () => taskOpenCount += 1,
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (kind) async {
        agentKinds.add(kind);
      },
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/42/video',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open task center'));
    await tester.pump();
    await tester.tap(find.text('Review candidates'));
    await tester.pump();
    await tester.tap(find.text('Break storyboard'));
    await tester.pump();

    expect(taskOpenCount, 1);
    expect(assetTargets, hasLength(1));
    expect(
      assetTargets.single.kind,
      ProjectStudioAssetEditorTargetKind.confirmCandidates,
    );
    expect(assetTargets.single.notice, contains('Confirm the pending'));
    expect(agentKinds, <String>['storyboard_breaker']);
  });

  testWidgets('cockpit actions without launch intents use target step only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'script',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final agentKinds = <String>[];
    final stepChanges = <StudioStep>[];
    var taskOpenCount = 0;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      home: ProjectHome(
        project: const ProjectRow(
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
        stats: const ProjectStats(
          scriptCount: 1,
          storyboardCount: 1,
          roleCount: 1,
          novelCount: 0,
          videoCount: 0,
        ),
        readinessScore: 58,
        readinessSummary: 'Unknown actions should stay conservative.',
        onboarding: const ProjectHomeOnboarding(
          complete: true,
          checklist: <ProjectHomeChecklistItem>[],
        ),
        styleBibleReady: true,
        cockpit: const ProjectHomeCockpit(
          headline: 'Keep action routes conservative without explicit intent.',
          subheadline:
              'Actions without launch intents should stay conservative.',
          primaryAction: ProjectHomeAction(
            key: 'unknown_assetish_route',
            title: 'Role-library sounding copy',
            detail:
                'Mentions candidate review, but should stay on deliver only.',
            targetStep: 'deliver',
            ctaLabel: 'Stay on deliver',
          ),
          secondaryActions: <ProjectHomeAction>[],
          metrics: <ProjectHomeMetric>[],
          starterTemplates: <ProjectHomeStarterTemplate>[],
        ),
      ),
      initialStep: StudioStep.script,
      onExit: () {},
      onStepChanged: stepChanges.add,
      onOpenAgentDrawer: () {},
      onOpenTasks: () => taskOpenCount += 1,
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (kind) async {
        agentKinds.add(kind);
      },
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stay on deliver'));
    await tester.pump();

    expect(taskOpenCount, 0);
    expect(assetTargets, isEmpty);
    expect(agentKinds, isEmpty);
    expect(stepChanges, contains(StudioStep.deliver));
    expect(find.text('body-deliver'), findsOneWidget);
  });

  testWidgets('explicit cockpit launch intents override opaque action keys', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'script',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final agentKinds = <String>[];
    final stepChanges = <StudioStep>[];
    var taskOpenCount = 0;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      home: ProjectHome(
        project: const ProjectRow(
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
        stats: const ProjectStats(
          scriptCount: 1,
          storyboardCount: 1,
          roleCount: 1,
          novelCount: 0,
          videoCount: 0,
        ),
        readinessScore: 66,
        readinessSummary: 'Explicit intents should win.',
        onboarding: const ProjectHomeOnboarding(
          complete: true,
          checklist: <ProjectHomeChecklistItem>[],
        ),
        styleBibleReady: true,
        cockpit: const ProjectHomeCockpit(
          headline: 'Project Delta can now listen to payload intent.',
          subheadline:
              'The payload should drive task, asset, and starter routes.',
          primaryAction: ProjectHomeAction(
            key: 'definitely_not_tasks',
            title: 'Open task center via intent',
            detail: 'Use the server-provided route.',
            targetStep: 'script',
            ctaLabel: 'Open task center',
            launchIntent: ProjectHomeLaunchIntent(action: 'open_tasks'),
          ),
          secondaryActions: <ProjectHomeAction>[],
          metrics: <ProjectHomeMetric>[
            ProjectHomeMetric(
              key: 'not_an_asset_metric',
              label: 'Candidate review',
              value: '3',
              detail: 'This should still open candidate review.',
              launchIntent: ProjectHomeLaunchIntent(
                assetTarget: 'confirm_candidates',
              ),
            ),
          ],
          starterTemplates: <ProjectHomeStarterTemplate>[
            ProjectHomeStarterTemplate(
              key: 'opaque_server_route',
              title: 'Sample route',
              detail: 'Take the explicit starter route.',
              targetStep: 'script',
              ctaLabel: 'Run sample route',
              launchIntent: ProjectHomeLaunchIntent(
                targetStep: 'video',
                agentKind: 'grid_prompt_generator',
              ),
            ),
          ],
        ),
      ),
      initialStep: StudioStep.script,
      onExit: () {},
      onStepChanged: stepChanges.add,
      onOpenAgentDrawer: () {},
      onOpenTasks: () => taskOpenCount += 1,
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (kind) async {
        agentKinds.add(kind);
      },
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/42/video',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open task center'));
    await tester.pump();

    final metricCard = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Candidate review'),
        matching: find.byType(InkWell),
      ),
    );
    metricCard.onTap!.call();
    await tester.pump();

    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Run sample route').last,
        )
        .onPressed!
        .call();
    await tester.pump();

    expect(taskOpenCount, 1);
    expect(assetTargets, hasLength(1));
    expect(
      assetTargets.single.kind,
      ProjectStudioAssetEditorTargetKind.confirmCandidates,
    );
    expect(agentKinds, <String>['grid_prompt_generator']);
    expect(stepChanges, contains(StudioStep.video));
  });

  testWidgets('cockpit metrics can drill into tasks and asset hub', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'script',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final stepChanges = <StudioStep>[];
    var taskOpenCount = 0;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      home: const ProjectHome(
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
          storyboardCount: 1,
          roleCount: 2,
          novelCount: 0,
          videoCount: 0,
        ),
        readinessScore: 54,
        readinessSummary: 'Still closing the core blockers.',
        onboarding: ProjectHomeOnboarding(
          complete: true,
          checklist: <ProjectHomeChecklistItem>[],
        ),
        styleBibleReady: true,
        cockpit: ProjectHomeCockpit(
          headline: 'Project Delta still has a couple of obvious blockers.',
          subheadline: 'Use the dashboard to jump straight into them.',
          primaryAction: ProjectHomeAction(
            key: 'review_storyboard',
            title: 'Review storyboard readiness',
            detail: 'Check the next stage after role work is closed.',
            targetStep: 'storyboard',
            ctaLabel: 'Check storyboard state',
          ),
          secondaryActions: <ProjectHomeAction>[],
          metrics: <ProjectHomeMetric>[
            ProjectHomeMetric(
              key: 'readiness',
              label: 'Project readiness',
              value: '54/100',
              detail: 'Use explicit payload intent to open storyboard.',
              launchIntent: ProjectHomeLaunchIntent(targetStep: 'storyboard'),
            ),
            ProjectHomeMetric(
              key: 'opaque_task_metric',
              label: 'Failed tasks',
              value: '2',
              detail: 'Two blocked jobs still need operator attention.',
              launchIntent: ProjectHomeLaunchIntent(action: 'open_tasks'),
            ),
            ProjectHomeMetric(
              key: 'opaque_asset_metric',
              label: 'Role assets',
              value: '5',
              detail: 'Open the asset hub and verify reuse before storyboard.',
              launchIntent: ProjectHomeLaunchIntent(
                assetTarget: 'link_roles_to_scripts',
              ),
            ),
            ProjectHomeMetric(
              key: 'unknown_blocker',
              label: 'Blocked items',
              value: '2',
              detail:
                  'Blocked copy alone should not infer a task-center route.',
            ),
          ],
          starterTemplates: <ProjectHomeStarterTemplate>[],
        ),
      ),
      initialStep: StudioStep.script,
      onExit: () {},
      onStepChanged: stepChanges.add,
      onOpenAgentDrawer: () {},
      onOpenTasks: () => taskOpenCount += 1,
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/42/video',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    final readinessMetric = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Project readiness'),
        matching: find.byType(InkWell),
      ),
    );
    readinessMetric.onTap!.call();
    await tester.pump();
    final failedTasksMetric = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Failed tasks'),
        matching: find.byType(InkWell),
      ),
    );
    failedTasksMetric.onTap!.call();
    await tester.pump();
    final roleAssetsMetric = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Role assets'),
        matching: find.byType(InkWell),
      ),
    );
    roleAssetsMetric.onTap!.call();
    await tester.pump();

    expect(taskOpenCount, 1);
    expect(assetTargets, hasLength(1));
    expect(
      assetTargets.single.kind,
      ProjectStudioAssetEditorTargetKind.reviewRoleReuse,
    );
    expect(assetTargets.single.notice, contains('verify reuse'));
    expect(stepChanges, contains(StudioStep.storyboard));
    expect(find.text('Open Board'), findsOneWidget);
    expect(find.text('Open tasks'), findsOneWidget);
    expect(find.text('Open asset hub'), findsOneWidget);
    expect(find.text('Open blocked items'), findsNothing);
  });

  testWidgets('metrics without launch intents do not synthesize CTAs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'script',
    });

    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      home: const ProjectHome(
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
          storyboardCount: 1,
          roleCount: 2,
          novelCount: 0,
          videoCount: 0,
        ),
        readinessScore: 51,
        readinessSummary: 'Metrics need explicit launch intents for CTAs.',
        onboarding: ProjectHomeOnboarding(
          complete: true,
          checklist: <ProjectHomeChecklistItem>[],
        ),
        styleBibleReady: true,
        cockpit: ProjectHomeCockpit(
          headline: 'Metrics without intents should stay inert.',
          subheadline: 'Candidate review needs explicit intent now.',
          primaryAction: ProjectHomeAction(
            key: 'review_storyboard',
            title: 'Review storyboard readiness',
            detail: 'Keep the studio pointed at the next stage.',
            targetStep: 'storyboard',
            ctaLabel: 'Check storyboard state',
          ),
          secondaryActions: <ProjectHomeAction>[],
          metrics: <ProjectHomeMetric>[
            ProjectHomeMetric(
              key: 'opaque_metric_without_intent',
              label: 'Candidate review',
              value: '3',
              detail: 'Missing launch intent should not create an asset CTA.',
            ),
          ],
          starterTemplates: <ProjectHomeStarterTemplate>[],
        ),
      ),
      initialStep: StudioStep.script,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Open asset hub'), findsNothing);
  });

  testWidgets('starter templates can launch sample, asset, and ops routes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'script',
    });

    final assetTargets = <ProjectStudioAssetEditorTarget>[];
    final agentKinds = <String>[];
    final stepChanges = <StudioStep>[];
    var taskOpenCount = 0;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      home: const ProjectHome(
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
          storyboardCount: 2,
          roleCount: 2,
          novelCount: 0,
          videoCount: 0,
        ),
        readinessScore: 63,
        readinessSummary: 'Use a route and keep momentum up.',
        onboarding: ProjectHomeOnboarding(
          complete: true,
          checklist: <ProjectHomeChecklistItem>[],
        ),
        styleBibleReady: true,
        cockpit: ProjectHomeCockpit(
          headline: 'Project Delta has three clean ways to move forward.',
          subheadline: 'Pick a route and jump straight into execution.',
          primaryAction: ProjectHomeAction(
            key: 'review_storyboard',
            title: 'Review storyboard readiness',
            detail: 'Keep the studio pointed at the next stage.',
            targetStep: 'storyboard',
            ctaLabel: 'Check storyboard state',
          ),
          secondaryActions: <ProjectHomeAction>[],
          metrics: <ProjectHomeMetric>[],
          starterTemplates: <ProjectHomeStarterTemplate>[
            ProjectHomeStarterTemplate(
              key: 'opaque_sample_route',
              title: 'Sample-first route',
              detail: 'Get the first clip moving before broadening scope.',
              targetStep: 'video',
              ctaLabel: 'Run sample route',
              launchIntent: ProjectHomeLaunchIntent(
                targetStep: 'video',
                agentKind: 'grid_prompt_generator',
              ),
            ),
            ProjectHomeStarterTemplate(
              key: 'opaque_role_route',
              title: 'Role library route',
              detail: 'Open the role library and close anchor gaps first.',
              targetStep: 'assets',
              ctaLabel: 'Open role route',
              launchIntent: ProjectHomeLaunchIntent(
                targetStep: 'assets',
                assetTarget: 'build_role_library',
              ),
            ),
            ProjectHomeStarterTemplate(
              key: 'opaque_ops_route',
              title: 'Ops triage route',
              detail: 'Clear failed jobs before starting another render pass.',
              targetStep: 'tasks',
              ctaLabel: 'Triage jobs',
              launchIntent: ProjectHomeLaunchIntent(action: 'open_tasks'),
            ),
          ],
        ),
      ),
      initialStep: StudioStep.script,
      onExit: () {},
      onStepChanged: stepChanges.add,
      onOpenAgentDrawer: () {},
      onOpenTasks: () => taskOpenCount += 1,
      onOpenAssetEditor: assetTargets.add,
      onRunHarnessAgent: (kind) async {
        agentKinds.add(kind);
      },
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    late GoRouter router;
    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/42/video',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouterApp(router));
    await tester.pumpAndSettle();

    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Run sample route').last,
        )
        .onPressed!
        .call();
    await tester.pump();
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Open role route').last,
        )
        .onPressed!
        .call();
    await tester.pump();
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Triage jobs').last)
        .onPressed!
        .call();
    await tester.pump();
    expect(agentKinds, <String>['grid_prompt_generator']);
    expect(assetTargets, hasLength(1));
    expect(
      assetTargets.single.kind,
      ProjectStudioAssetEditorTargetKind.buildRoleLibrary,
    );
    expect(taskOpenCount, 1);
    expect(stepChanges, contains(StudioStep.video));
    expect(find.text('body-video'), findsWidgets);
  });

  testWidgets(
    'project studio cockpit keeps metrics and starter routes in one aligned grid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final host = ProjectStudioHost(
        projectNumericId: 42,
        projectUuid: 'project-42',
        projectName: 'Project Delta',
        accessToken: null,
        home: const ProjectHome(
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
            storyboardCount: 2,
            roleCount: 2,
            novelCount: 0,
            videoCount: 0,
          ),
          readinessScore: 63,
          readinessSummary: 'Use a route and keep momentum up.',
          onboarding: ProjectHomeOnboarding(
            complete: true,
            checklist: <ProjectHomeChecklistItem>[],
          ),
          styleBibleReady: true,
          cockpit: ProjectHomeCockpit(
            headline: 'Project Delta has clear next steps.',
            subheadline: 'Keep the cockpit cards in one consistent grid.',
            primaryAction: ProjectHomeAction(
              key: 'review_storyboard',
              title: 'Review storyboard readiness',
              detail: 'Keep the studio pointed at the next stage.',
              targetStep: 'storyboard',
              ctaLabel: 'Check storyboard state',
            ),
            secondaryActions: <ProjectHomeAction>[],
            metrics: <ProjectHomeMetric>[
              ProjectHomeMetric(
                key: 'metric_a',
                label: 'Metric A',
                value: '1',
                detail: 'One',
              ),
              ProjectHomeMetric(
                key: 'metric_b',
                label: 'Metric B',
                value: '2',
                detail: 'Two',
              ),
              ProjectHomeMetric(
                key: 'metric_c',
                label: 'Metric C',
                value: '3',
                detail: 'Three',
              ),
              ProjectHomeMetric(
                key: 'metric_d',
                label: 'Metric D',
                value: '4',
                detail: 'Four',
              ),
            ],
            starterTemplates: <ProjectHomeStarterTemplate>[
              ProjectHomeStarterTemplate(
                key: 'route_a',
                title: 'Route A',
                detail: 'Route one',
                targetStep: 'video',
                ctaLabel: 'Run route A',
              ),
              ProjectHomeStarterTemplate(
                key: 'route_b',
                title: 'Route B',
                detail: 'Route two',
                targetStep: 'assets',
                ctaLabel: 'Run route B',
              ),
              ProjectHomeStarterTemplate(
                key: 'route_c',
                title: 'Route C',
                detail: 'Route three',
                targetStep: 'tasks',
                ctaLabel: 'Run route C',
              ),
            ],
          ),
        ),
        initialStep: StudioStep.script,
        onExit: () {},
        onStepChanged: (_) {},
        onOpenAgentDrawer: () {},
        onRunHarnessAgent: (_) async {},
        buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
      );

      await tester.pumpWidget(_wrapApp(child: ProjectStudioPage(host: host)));
      await tester.pumpAndSettle();

      final metricX = tester.getTopLeft(find.text('Metric A')).dx;
      final starterX = tester.getTopLeft(find.text('Route A')).dx;
      final metricY = tester.getTopLeft(find.text('Metric A')).dy;
      final starterY = tester.getTopLeft(find.text('Route A')).dy;

      expect((metricX - starterX).abs(), lessThan(24));
      expect(starterY, greaterThan(metricY));
    },
  );
}
