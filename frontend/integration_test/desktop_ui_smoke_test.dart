import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/auth/controller.dart';
import 'package:openflow_app/content_compliance/controller.dart';
import 'package:openflow_app/content_compliance/section.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/account/controller.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/product_shell/login_page.dart';
import 'package:openflow_app/product_shell/settings_hub_page.dart';
import 'package:openflow_app/product_shell/studio_app_bar_actions.dart';
import 'package:openflow_app/product_shell/studio_shell_navigation.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/projects/controller.dart';
import 'package:openflow_app/projects/section.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/quality_reviews/section.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:openflow_app/shell/platform_short_drama_pipeline_strip.dart';
import 'package:openflow_app/task_center/section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  AuthController buildAuthController() {
    return AuthController(
      onErrorChanged: (_) {},
      onSignedOut: () async {},
      l10nProvider: () => null,
    );
  }

  Widget buildTestApp(Widget child) {
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
      home: Scaffold(body: child),
    );
  }

  Widget buildScrollableTestApp(Widget child) {
    return buildTestApp(SingleChildScrollView(child: child));
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

  testWidgets('desktop login page supports wide layout and actions', (
    WidgetTester tester,
  ) async {
    final authController = buildAuthController();
    addTearDown(authController.dispose);
    var signInTapped = 0;
    var signUpTapped = 0;

    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        theme: StudioTheme.build(),
        builder: (context, child) => Theme(
          data: studioAdaptiveDesktopTheme(context),
          child: child ?? const SizedBox(),
        ),
        home: ProductLoginPage(
          authController: authController,
          errorMessage: null,
          onSignIn: () => signInTapped++,
          onSignUp: () => signUpTapped++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('product-auth-submit')), findsOneWidget);
    expect(find.byKey(const Key('auth-mode-sign-up')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('product-auth-submit')));
    await tester.tap(find.byKey(const Key('product-auth-submit')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('auth-mode-sign-up')));
    await tester.tap(find.byKey(const Key('auth-mode-sign-up')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(2),
      authController.passwordController.text,
    );
    await tester.ensureVisible(find.byKey(const Key('product-auth-submit')));
    await tester.tap(find.byKey(const Key('product-auth-submit')));
    await tester.pumpAndSettle();

    expect(signInTapped, 1);
    expect(signUpTapped, 1);
  });

  testWidgets('desktop login page remains usable with compact width', (
    WidgetTester tester,
  ) async {
    final authController = buildAuthController();
    addTearDown(authController.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        theme: StudioTheme.build(),
        builder: (context, child) => Theme(
          data: studioAdaptiveDesktopTheme(context),
          child: child ?? const SizedBox(),
        ),
        home: ProductLoginPage(
          authController: authController,
          errorMessage: '账号或密码错误',
          onSignIn: () {},
          onSignUp: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('账号或密码错误'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('auth-mode-sign-up')));
    await tester.tap(find.byKey(const Key('auth-mode-sign-up')));
    await tester.pumpAndSettle();
    expect(find.text('确认密码'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop login page remains stable on wide screens', (
    WidgetTester tester,
  ) async {
    final authController = buildAuthController();
    addTearDown(authController.dispose);

    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        theme: StudioTheme.build(),
        builder: (context, child) => Theme(
          data: studioAdaptiveDesktopTheme(context),
          child: child ?? const SizedBox(),
        ),
        home: ProductLoginPage(
          authController: authController,
          errorMessage: null,
          onSignIn: () {},
          onSignUp: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 短剧工作室 — 从剧本到发布一站完成。'), findsOneWidget);
    expect(find.byKey(const Key('product-auth-submit')), findsOneWidget);
    expect(find.byKey(const Key('auth-mode-sign-up')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop pipeline strip responds to pane selection', (
    WidgetTester tester,
  ) async {
    ProductWorkspacePane? lastPane;

    await tester.pumpWidget(
      buildTestApp(
        PlatformShortDramaPipelineStrip(
          onSelectPane: (pane) => lastPane = pane,
          jobsPaneEnabled: true,
          qualityPaneEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilterChip).at(1));
    await tester.pumpAndSettle();
    expect(lastPane, ProductWorkspacePane.scriptWorkspace);

    await tester.tap(find.byType(FilterChip).last);
    await tester.pumpAndSettle();
    expect(lastPane, ProductWorkspacePane.shortVideoSpace);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop more menu keeps latest product areas grouped and reachable',
    (WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return FilledButton(
                onPressed: () {
                  showModalBottomSheet<ProductWorkspacePane>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) {
                      final destinations = studioShellSecondaryDestinations(
                        l10n,
                        jobsPaneEnabled: true,
                        qualityPaneEnabled: true,
                      );
                      return SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: destinations
                              .map(
                                (dest) => ListTile(
                                  leading: Icon(dest.icon),
                                  title: Text(dest.label(l10n)),
                                  onTap: () => Navigator.of(ctx).pop(dest.pane),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      );
                    },
                  );
                },
                child: const Text('打开更多菜单'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开更多菜单'));
      await tester.pumpAndSettle();

      expect(find.text('短视频 Space'), findsOneWidget);
      expect(find.text('脚本工作区'), findsOneWidget);
      expect(find.text('制作工作区'), findsOneWidget);
      expect(find.text('任务中心'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop secondary navigation keeps product areas grouped and reachable',
    (WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final destinations = studioShellSecondaryDestinations(
        l10n,
        jobsPaneEnabled: true,
        qualityPaneEnabled: true,
      );
      final labels = destinations.map((dest) => dest.label(l10n)).toList();

      expect(
        labels,
        containsAll(<String>[
          '短视频 Space',
          '脚本工作区',
          '制作工作区',
          '任务中心',
          '质量评审',
          '任务作业',
          '团队工作区',
          'API 密钥',
          '内容合规',
          '平台状态',
          '平台配置',
        ]),
      );
    },
  );

  testWidgets('desktop utility actions switch account help and notifications', (
    WidgetTester tester,
  ) async {
    ProductWorkspacePane? lastPane;

    await tester.pumpWidget(
      buildTestApp(
        StudioAppBarActions(
          selectedPane: ProductWorkspacePane.projects,
          unreadNotifications: 5,
          onSelectPane: (pane) => lastPane = pane,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('通知'), findsOneWidget);
    expect(find.byTooltip('账户与设置'), findsOneWidget);
    expect(find.byTooltip('帮助'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    expect(lastPane, ProductWorkspacePane.notifications);

    await tester.tap(find.byTooltip('账户与设置'));
    await tester.pumpAndSettle();
    expect(lastPane, ProductWorkspacePane.account);

    await tester.tap(find.byTooltip('帮助'));
    await tester.pumpAndSettle();
    expect(lastPane, ProductWorkspacePane.helpHub);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop projects section opens key workbenches', (
    WidgetTester tester,
  ) async {
    final controller = buildProjectsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
          accessToken: 'token',
          controller: controller,
          onOpenProjectDetail: (_) {},
          onOpenTeamWorkspaces: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('水墨古风'), findsOneWidget);
    await tester.tap(find.text('打开画风工作台'));
    await tester.pumpAndSettle();
    expect(find.text('画风工作台'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开创作手册工作台'));
    await tester.pumpAndSettle();
    expect(find.text('创作手册工作台'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop task center opens workbench', (
    WidgetTester tester,
  ) async {
    final detailController = TextEditingController();
    addTearDown(detailController.dispose);

    await tester.pumpWidget(
      buildScrollableTestApp(
        TaskCenterSection(
          accessToken: 'token',
          initialProjectNumericId: 9,
          initialProjectUuid: '550e8400-e29b-41d4-a716-446655440009',
          loadingTaskProjects: false,
          loadingTaskCategories: false,
          loadingTaskApi: false,
          loadingTaskDetailsByNumericId: false,
          loadingTaskDetailsUuid: false,
          taskDetailJobIdController: detailController,
          taskProjects: const [
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
          taskApiJobs: const [
            JobRow(
              numericTaskId: 101,
              id: 'job-101',
              ownerUserId: 'user-1',
              kind: 'asset.generate.image',
              status: 'queued',
              payload: {'project_numeric_id': 9},
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开任务工作台'));
    await tester.pumpAndSettle();
    expect(find.text('任务工作台'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop quality section opens workbench', (
    WidgetTester tester,
  ) async {
    final controller = buildQualityController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildTestApp(
        QualityReviewsSection(
          accessToken: 'token',
          controller: controller,
          initialProjectNumericId: 9,
          platformConfig: PlatformConfigToggleSetV1.defaults,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开质量工作台'));
    await tester.pumpAndSettle();
    expect(find.text('质量工作台'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop settings hub keeps account api keys and workspaces reachable',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final accountController = buildAccountController();
      final apiKeysController = buildApiKeysController();
      addTearDown(accountController.dispose);
      addTearDown(apiKeysController.dispose);

      await tester.pumpWidget(
        buildTestApp(
          SettingsHubPage(
            accountController: accountController,
            apiKeysController: apiKeysController,
            accessToken: null,
            onAccountDeleted: (_) async {},
            onWorkspaceContextChanged: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('账户、API 与工作区统一入口。'), findsOneWidget);
      expect(find.text('账户'), findsOneWidget);
      expect(find.text('API 与模型'), findsOneWidget);
      expect(find.text('工作区'), findsOneWidget);

      await tester.tap(find.text('API 与模型'));
      await tester.pumpAndSettle();
      expect(find.text('API 密钥'), findsOneWidget);

      await tester.tap(find.text('工作区'));
      await tester.pumpAndSettle();
      expect(find.text('登录后可管理企业工作区。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop content compliance persists top alert preference', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final controller =
        ContentComplianceController(
            accessTokenProvider: () => null,
            onErrorChanged: (_) {},
          )
          ..queueEnabledOverride = true
          ..skipAutoLoadQueueOnMount = true
          ..queue = buildQueueWithSingleAlert('critical_unclaimed');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildScrollableTestApp(ContentComplianceSection(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('contentComplianceTopAlertPrimary')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('仅选中待处理项'));
    await tester.tap(find.text('仅选中待处理项'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('contentComplianceTopAlertPrimary')),
        matching: find.text('仅选中待处理项'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
