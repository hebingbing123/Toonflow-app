import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/account/controller.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/auth/controller.dart';
import 'package:openflow_app/benchmark/section.dart';
import 'package:openflow_app/content_compliance/controller.dart';
import 'package:openflow_app/content_compliance/section.dart';
import 'package:openflow_app/design_system/components/openflow_brand.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/design_system/glass.dart';
import 'package:openflow_app/design_system/ix/studio_job_tray.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/global_search/global_search_bar.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/jobs/controller.dart';
import 'package:openflow_app/jobs/section.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/login_page.dart';
import 'package:openflow_app/product_shell/settings_hub_page.dart';
import 'package:openflow_app/product_shell/studio_app_bar_actions.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/projects/controller.dart';
import 'package:openflow_app/projects/section.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/quality_reviews/section.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:openflow_app/shell/platform_short_drama_pipeline_strip.dart';
import 'package:openflow_app/task_center/section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  const screenshotSize = Size(1440, 960);
  final outputDir = '${Directory.current.path}/build/desktop_layouts';

  AuthController buildAuthController() {
    return AuthController(
      onErrorChanged: (_) {},
      onSignedOut: () async {},
      l10nProvider: () => null,
    );
  }

  ProjectsController buildProjectsController() {
    final controller = ProjectsController(
      accessTokenProvider: () => 'token',
      onErrorChanged: (_) {},
      l10nProvider: () => null,
    );
    controller.projects = const <ProjectRow>[
      ProjectRow(
        id: 'project-1',
        numericId: 11,
        name: '项目一',
        createTimeMs: 1,
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
    ];
    controller.artStyles = const <ArtStyleRow>[
      ArtStyleRow(
        id: 'style-1',
        numericId: 11,
        name: '水墨古风',
        label: 'ink',
        prompt: 'soft ink wash',
        fileUrl: '/api/v1/art-styles/numeric/11/cover',
      ),
    ];
    controller.projectsSummaryLine = 'projects=1';
    controller.artStylesLine = 'total=1';
    return controller;
  }

  QualityReviewsController buildQualityController() {
    final controller = QualityReviewsController(
      accessTokenProvider: () => 'token',
      onErrorChanged: (_) {},
    );
    controller.qualityReviews = const <QualityReview>[
      QualityReview(
        id: 'r1',
        createdAt: '2026-04-10T00:00:00Z',
        updatedAt: '2026-04-10T00:00:00Z',
        userId: 'u1',
        targetType: 'output',
        source: 'manual',
        overallScore: 82,
        isBadCase: false,
      ),
    ];
    controller.qualityStatsLine = 'output: total=1, pass=100%';
    controller.qualityStagePassRateLine = '2026-04-10 output:100%';
    controller.qualityReviewByIdLine = 'r1 · output · manual';
    return controller;
  }

  JobsController buildJobsController() {
    final controller = JobsController(
      accessTokenProvider: () => 'token',
      onErrorChanged: (_) {},
      l10nProvider: () => null,
    );
    controller.jobs = const <JobRow>[
      JobRow(
        numericTaskId: 201,
        id: 'job-201',
        ownerUserId: 'user-1',
        kind: 'flutter.probe',
        status: 'queued',
        payload: <String, dynamic>{'workspace_id': 'workspace-beta'},
        createdAt: '2026-05-12T00:00:00Z',
        updatedAt: '2026-05-12T00:01:00Z',
      ),
      JobRow(
        numericTaskId: 202,
        id: 'job-202',
        ownerUserId: 'user-2',
        kind: 'render.completed',
        status: 'failed',
        payload: <String, dynamic>{'project_numeric_id': 11},
        createdAt: '2026-05-12T00:02:00Z',
        updatedAt: '2026-05-12T00:03:00Z',
      ),
    ];
    controller.jobKindsLine = 'flutter.probe, render.completed';
    controller.jobKindSummaryLine = 'flutter.probe(1), render.completed(1)';
    controller.jobStatusSummaryLine = 'queued(1), failed(1)';
    controller.jobByIdLine = '#202 · render.completed · failed · uuid=job-202';
    controller.jobIdController.text = 'job-202';
    return controller;
  }

  AccountController buildAccountController() {
    return AccountController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => null,
    );
  }

  ApiKeysController buildApiKeysController() {
    return ApiKeysController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => null,
    );
  }

  ContentComplianceQueueResponseV1 buildQueueWithSingleAlert(String stage) {
    return ContentComplianceQueueResponseV1.fromJson(<String, dynamic>{
      'summary': <String, dynamic>{
        'pending': 0,
        'claimed': 0,
        'resolved': 0,
        'dismissed': 0,
        'critical': 0,
        'high': 0,
      },
      'sla': <String, dynamic>{
        'openOver24h': 0,
        'openOver72h': 0,
        'claimedOver24h': 0,
        'unclaimedCritical': 0,
        'oldestOpenAgeHours': 0,
      },
      'capacity': <String, dynamic>{
        'reviewerCapacityLimit': 12,
        'overloadedReviewerCount': 1,
        'overloadedClaimedCount': 2,
      },
      'alerts': <dynamic>[
        <String, dynamic>{
          'level': stage == 'critical_unclaimed' ? 'critical' : 'high',
          'stage': stage,
          'count': 2,
          'title': '测试提醒',
          'message': '测试提醒正文',
        },
      ],
      'workspaceSummaries': <dynamic>[],
      'ownerSummaries': <dynamic>[],
      'escalationSummaries': <dynamic>[],
      'items': <dynamic>[
        <String, dynamic>{
          'id': 'f2a0f70a-3ef3-44f1-9dbe-947eb41976c1',
          'reporterUserId': 'd4011e94-6042-4f7a-b35d-02268389f815',
          'reporterEmail': 'reporter@example.com',
          'targetType': 'project',
          'targetId': '8d4d0366-843f-4e4e-a5b6-a6602a2950cb',
          'workspaceId': null,
          'workspaceName': null,
          'projectId': null,
          'projectName': null,
          'category': 'safety',
          'severity': stage == 'critical_unclaimed' ? 'critical' : 'high',
          'status': stage == 'critical_unclaimed' ? 'pending' : 'claimed',
          'escalationStage': stage,
          'detail': 'test',
          'claimedByLabel': stage == 'critical_unclaimed' ? null : 'reviewer_a',
          'claimedAt': null,
          'resolutionLabel': null,
          'resolutionNote': null,
          'resolvedAt': null,
          'createdAt': '2026-05-10T00:00:00Z',
        },
      ],
    });
  }

  Widget buildShotApp({required Key repaintKey, required Widget child}) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, child) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: child ?? const SizedBox(),
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: repaintKey,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }

  Widget buildProductShellChromePreview() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final tokens = StudioTokens.of(context);
        return ColoredBox(
          color: tokens.bgBase,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StudioGlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 72,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              const OpenFlowBrandMark(
                                size: 36,
                                borderRadius: 10,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'OpenFlow',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '项目总览',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const StudioJobTray(),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: GlobalSearchBar(
                            accessToken: 'token',
                            currentWorkspaceName: '默认工作区',
                            currentWorkspaceId: 'workspace-1',
                            onNavigateToResults:
                                (
                                  query, {
                                  initialResultTypes = const <ResultType>[],
                                  initialTimeFrom,
                                  initialTimeTo,
                                }) {
                                  expect(query, isA<String>());
                                },
                          ),
                        ),
                        const SizedBox(width: 8),
                        StudioAppBarActions(
                          selectedPane: ProductWorkspacePane.projects,
                          unreadNotifications: 5,
                          onSelectPane: (_) {},
                        ),
                        IconButton(
                          tooltip: l10n.productShellMoreMenu,
                          onPressed: () {},
                          icon: const Icon(Icons.apps_outlined),
                        ),
                        PopupMenuButton<String>(
                          tooltip: l10n.localeSectionTitle,
                          icon: const Icon(Icons.language_outlined),
                          itemBuilder: (ctx) =>
                              const <PopupMenuEntry<String>>[],
                        ),
                        IconButton(
                          tooltip: l10n.authSignOut,
                          onPressed: () {},
                          icon: const Icon(Icons.logout_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PlatformShortDramaPipelineStrip(
                  onSelectPane: (_) {},
                  jobsPaneEnabled: true,
                  qualityPaneEnabled: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  OutboundWebhookListResponseV1 buildHelpHubWebhookList() {
    return const OutboundWebhookListResponseV1(
      items: <OutboundWebhookListItemV1>[
        OutboundWebhookListItemV1(
          id: 'wh_alpha',
          url: 'https://hooks.example.com/a/really/long/webhook/path/alpha',
          createdAt: '2026-05-01T12:00:00Z',
          updatedAt: '2026-05-01T12:30:00Z',
          workspaceId: 'workspace-alpha',
          eventTypes: <String>['billing.invoice.paid', 'render.completed'],
        ),
        OutboundWebhookListItemV1(
          id: 'wh_beta',
          url: 'https://hooks.example.com/a/really/long/webhook/path/beta',
          createdAt: '2026-05-02T08:15:00Z',
          workspaceId: 'workspace-beta',
          eventTypes: <String>['publish.completed'],
          enabled: false,
        ),
      ],
    );
  }

  OutboundWebhookCreatedResponseV1 buildHelpHubLatestCreatedWebhook() {
    return const OutboundWebhookCreatedResponseV1(
      id: 'wh_alpha',
      url: 'https://hooks.example.com/a/really/long/webhook/path/alpha',
      secret: 'whsec_alpha_secret_value',
    );
  }

  BillingWebhookEventsResponseV1 buildHelpHubBillingEventsPage() {
    return BillingWebhookEventsResponseV1(
      items: <BillingWebhookEventItemV1>[
        BillingWebhookEventItemV1(
          id: 101,
          providerEventId: 'evt_101',
          provider: 'stripe',
          rawEventId: 'raw_evt_101',
          eventType: 'invoice.paid',
          eventCreatedAt: DateTime.utc(2026, 5, 1, 12),
          isInformationalEvent: false,
          createdAt: DateTime.utc(2026, 5, 1, 12, 1),
        ),
        BillingWebhookEventItemV1(
          id: 102,
          providerEventId: 'evt_102',
          provider: 'stripe',
          rawEventId: 'raw_evt_102',
          eventType: 'customer.subscription.updated',
          eventCreatedAt: DateTime.utc(2026, 5, 1, 12, 30),
          isInformationalEvent: true,
          createdAt: DateTime.utc(2026, 5, 1, 12, 31),
        ),
      ],
      total: 3,
      limit: 25,
      offset: 0,
      hasMore: true,
      nextOffset: 2,
    );
  }

  Map<String, OutboundWebhookDeliveryListResponseV1>
  buildHelpHubWebhookDeliveries() {
    return const <String, OutboundWebhookDeliveryListResponseV1>{
      'wh_alpha': OutboundWebhookDeliveryListResponseV1(
        items: <OutboundWebhookDeliveryItemV1>[
          OutboundWebhookDeliveryItemV1(
            id: 'del_1',
            eventType: 'billing.invoice.paid',
            status: 'delivered',
            httpStatus: 200,
            error: null,
            retryCount: 0,
            createdAt: '2026-05-01T12:05:00Z',
            deliveredAt: '2026-05-01T12:05:01Z',
          ),
          OutboundWebhookDeliveryItemV1(
            id: 'del_2',
            eventType: 'render.completed',
            status: 'failed',
            httpStatus: 500,
            error: 'upstream timeout after retry',
            retryCount: 2,
            createdAt: '2026-05-01T12:06:00Z',
          ),
        ],
      ),
    };
  }

  Map<String, OutboundWebhookTestResponseV1>
  buildHelpHubWebhookLastTestResults() {
    return const <String, OutboundWebhookTestResponseV1>{
      'wh_alpha': OutboundWebhookTestResponseV1(
        delivered: false,
        httpStatus: 502,
        error: 'bad gateway',
      ),
    };
  }

  Widget buildUtilityShellPreview({
    required String initialLocation,
    ProductWorkspacePane? initialPane,
    OutboundWebhookListResponseV1? debugHelpHubWebhooks,
    OutboundWebhookCreatedResponseV1? debugHelpHubLatestCreatedWebhook,
    BillingWebhookEventsResponseV1? debugHelpHubBillingEventsPage,
    Map<String, OutboundWebhookDeliveryListResponseV1>?
    debugHelpHubWebhookDeliveries,
    Map<String, OutboundWebhookTestResponseV1>?
    debugHelpHubWebhookLastTestResults,
  }) {
    HomePage buildShellHome({ProductWorkspacePane? pane}) {
      return HomePage(
        shellMode: HomeShellMode.product,
        initialProductPane: pane ?? initialPane,
        debugAuthenticatedAccessToken: 'test-token',
        debugSkipSessionContextSync: true,
        debugSkipAuthListenerAttach: true,
        debugHelpHubWebhooks: buildHelpHubWebhookList(),
        debugHelpHubLatestCreatedWebhook: buildHelpHubLatestCreatedWebhook(),
        debugHelpHubBillingEventsPage: buildHelpHubBillingEventsPage(),
        debugHelpHubWebhookDeliveries: buildHelpHubWebhookDeliveries(),
        debugHelpHubWebhookLastTestResults:
            buildHelpHubWebhookLastTestResults(),
      );
    }

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => buildShellHome()),
        GoRoute(path: '/help', redirect: (context, state) => '/?pane=help'),
        GoRoute(
          path: '/settings/models',
          builder: (context, state) =>
              buildShellHome(pane: ProductWorkspacePane.platformConfig),
        ),
      ],
    );

    return MaterialApp.router(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, child) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: child ?? const SizedBox(),
      ),
      routerConfig: router,
    );
  }

  Future<void> captureShot(
    WidgetTester tester, {
    required String name,
    required Widget child,
    Future<void> Function(WidgetTester tester)? afterPump,
    Size surfaceSize = screenshotSize,
  }) async {
    final repaintKey = GlobalKey();
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildShotApp(repaintKey: repaintKey, child: child));
    await tester.pumpAndSettle();
    if (afterPump != null) {
      await afterPump(tester);
      await tester.pumpAndSettle();
    }

    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outputDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  }

  Future<void> captureAppShot(
    WidgetTester tester, {
    required String name,
    required Widget app,
    Future<void> Function(WidgetTester tester)? afterPump,
    Size surfaceSize = screenshotSize,
  }) async {
    final repaintKey = GlobalKey();
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: repaintKey,
        child: SizedBox.expand(child: app),
      ),
    );
    await tester.pumpAndSettle();
    if (afterPump != null) {
      await afterPump(tester);
      await tester.pumpAndSettle();
    }

    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outputDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  }

  testWidgets('capture desktop layout gallery', (WidgetTester tester) async {
    final authController = buildAuthController();
    final projectsController = buildProjectsController();
    final qualityController = buildQualityController();
    final accountController = buildAccountController();
    final apiKeysController = buildApiKeysController();
    final taskDetailController = TextEditingController();
    final complianceController =
        ContentComplianceController(
            accessTokenProvider: () => null,
            onErrorChanged: (_) {},
          )
          ..queueEnabledOverride = true
          ..skipAutoLoadQueueOnMount = true
          ..queue = buildQueueWithSingleAlert('critical_unclaimed');

    addTearDown(authController.dispose);
    addTearDown(projectsController.dispose);
    addTearDown(qualityController.dispose);
    addTearDown(accountController.dispose);
    addTearDown(apiKeysController.dispose);
    addTearDown(taskDetailController.dispose);
    addTearDown(complianceController.dispose);

    await captureShot(
      tester,
      name: '01_login',
      child: ProductLoginPage(
        authController: authController,
        errorMessage: null,
        onSignIn: () {},
        onSignUp: () {},
      ),
    );

    await captureShot(
      tester,
      name: '02_product_shell_chrome',
      child: buildProductShellChromePreview(),
    );

    await captureShot(
      tester,
      name: '02a_product_shell_chrome_regular',
      surfaceSize: const Size(1280, 900),
      child: buildProductShellChromePreview(),
    );

    await captureShot(
      tester,
      name: '02b_product_shell_chrome_wide',
      surfaceSize: const Size(1728, 1117),
      child: buildProductShellChromePreview(),
    );

    await captureShot(
      tester,
      name: '03_projects',
      child: ProjectsSection(
        accessToken: 'token',
        controller: projectsController,
        onOpenProjectDetail: (_) {},
        onOpenTeamWorkspaces: () {},
      ),
    );

    await captureShot(
      tester,
      name: '03a_projects_regular',
      surfaceSize: const Size(1280, 900),
      child: ProjectsSection(
        accessToken: 'token',
        controller: projectsController,
        onOpenProjectDetail: (_) {},
        onOpenTeamWorkspaces: () {},
      ),
    );

    await captureShot(
      tester,
      name: '03b_projects_wide',
      surfaceSize: const Size(1728, 1117),
      child: ProjectsSection(
        accessToken: 'token',
        controller: projectsController,
        onOpenProjectDetail: (_) {},
        onOpenTeamWorkspaces: () {},
      ),
    );

    await captureShot(
      tester,
      name: '04_task_center',
      child: SingleChildScrollView(
        child: TaskCenterSection(
          accessToken: 'token',
          initialProjectNumericId: 9,
          initialProjectUuid: '550e8400-e29b-41d4-a716-446655440009',
          loadingTaskProjects: false,
          loadingTaskCategories: false,
          loadingTaskApi: false,
          loadingTaskDetailsByNumericId: false,
          loadingTaskDetailsUuid: false,
          taskDetailJobIdController: taskDetailController,
          taskProjects: const <TaskCenterProjectItem>[
            TaskCenterProjectItem(
              numericId: 9,
              name: '古风短剧',
              projectUuid: '550e8400-e29b-41d4-a716-446655440009',
            ),
          ],
          taskCategoriesLine:
              '分类 2 个 · asset.generate.image, script.export.zip',
          taskApiSummaryLine: 'page=1 limit=10 · total=1 · page_rows=1',
          taskDetailNumericIdLine:
              '#101 · asset.generate.image · queued · uuid=job-101',
          taskDetailUuidLine:
              '#101 · asset.generate.image · queued · uuid=job-101',
          taskApiJobs: const <JobRow>[
            JobRow(
              numericTaskId: 101,
              id: 'job-101',
              ownerUserId: 'user-1',
              kind: 'asset.generate.image',
              status: 'queued',
              payload: <String, dynamic>{'project_numeric_id': 9},
              createdAt: '2026-04-10T00:00:00Z',
              updatedAt: '2026-04-10T00:01:00Z',
            ),
          ],
          onTaskDetailJobIdChanged: (_) {},
          onLoadTaskProjects: () {},
          onLoadTaskCategories: () {},
          onLoadTaskApi: () {},
          onProbeTaskDetailByNumericId: () {},
          onProbeTaskDetailUuid: () {},
          onSelectTaskJob: (_) {},
        ),
      ),
    );

    await captureShot(
      tester,
      name: '05_quality',
      child: QualityReviewsSection(
        accessToken: 'token',
        controller: qualityController,
        initialProjectNumericId: 9,
        platformConfig: PlatformConfigToggleSetV1.defaults,
      ),
    );

    await captureShot(
      tester,
      name: '06_settings_account',
      child: SettingsHubPage(
        accountController: accountController,
        apiKeysController: apiKeysController,
        accessToken: null,
        onAccountDeleted: (_) async {},
        onWorkspaceContextChanged: () async {},
      ),
    );

    await captureShot(
      tester,
      name: '07_settings_api',
      child: SettingsHubPage(
        accountController: accountController,
        apiKeysController: apiKeysController,
        accessToken: null,
        onAccountDeleted: (_) async {},
        onWorkspaceContextChanged: () async {},
      ),
      afterPump: (tester) async {
        await tester.tap(find.text('API 与模型'));
      },
    );

    await captureShot(
      tester,
      name: '08_settings_workspaces',
      child: SettingsHubPage(
        accountController: accountController,
        apiKeysController: apiKeysController,
        accessToken: null,
        onAccountDeleted: (_) async {},
        onWorkspaceContextChanged: () async {},
      ),
      afterPump: (tester) async {
        await tester.tap(find.text('工作区'));
      },
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await captureShot(
      tester,
      name: '09_content_compliance',
      child: SingleChildScrollView(
        child: ContentComplianceSection(controller: complianceController),
      ),
    );

    await captureAppShot(
      tester,
      name: '10_help_hub_laptop_top',
      surfaceSize: const Size(1366, 768),
      app: buildUtilityShellPreview(
        initialLocation: '/help',
        debugHelpHubWebhooks: buildHelpHubWebhookList(),
        debugHelpHubLatestCreatedWebhook: buildHelpHubLatestCreatedWebhook(),
        debugHelpHubBillingEventsPage: buildHelpHubBillingEventsPage(),
        debugHelpHubWebhookDeliveries: buildHelpHubWebhookDeliveries(),
        debugHelpHubWebhookLastTestResults:
            buildHelpHubWebhookLastTestResults(),
      ),
    );

    await captureAppShot(
      tester,
      name: '10a_help_hub_laptop_billing',
      surfaceSize: const Size(1366, 768),
      app: buildUtilityShellPreview(
        initialLocation: '/help',
        debugHelpHubWebhooks: buildHelpHubWebhookList(),
        debugHelpHubLatestCreatedWebhook: buildHelpHubLatestCreatedWebhook(),
        debugHelpHubBillingEventsPage: buildHelpHubBillingEventsPage(),
        debugHelpHubWebhookDeliveries: buildHelpHubWebhookDeliveries(),
        debugHelpHubWebhookLastTestResults:
            buildHelpHubWebhookLastTestResults(),
      ),
      afterPump: (tester) async {
        await tester.tapAt(const Offset(1100, 700));
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(1180, 700), const Offset(0, -900));
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(1180, 700), const Offset(0, -700));
      },
    );

    final jobsController = buildJobsController();
    addTearDown(jobsController.dispose);
    await captureShot(
      tester,
      name: '11_jobs',
      child: JobsSection(controller: jobsController, studioPresentation: true),
    );

    await captureShot(
      tester,
      name: '12_benchmark',
      child: const SingleChildScrollView(
        child: BenchmarkSection(accessToken: null),
      ),
    );

    await captureAppShot(
      tester,
      name: '13_platform_config_laptop',
      surfaceSize: const Size(1366, 768),
      app: buildUtilityShellPreview(initialLocation: '/settings/models'),
    );

    expect(File('$outputDir/01_login.png').existsSync(), isTrue);
    expect(File('$outputDir/10_help_hub_laptop_top.png').existsSync(), isTrue);
    expect(
      File('$outputDir/10a_help_hub_laptop_billing.png').existsSync(),
      isTrue,
    );
    expect(File('$outputDir/11_jobs.png').existsSync(), isTrue);
    expect(File('$outputDir/12_benchmark.png').existsSync(), isTrue);
    expect(
      File('$outputDir/13_platform_config_laptop.png').existsSync(),
      isTrue,
    );
  });
}
