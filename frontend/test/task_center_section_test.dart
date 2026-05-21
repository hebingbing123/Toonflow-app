import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/platform/studio_load_state.dart';
import 'package:openflow_app/task_center/section.dart';
import 'package:openflow_app/rust_api.dart';

Widget _taskCenterTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  final zh = AppLocalizationsZh();

  testWidgets('task center exposes workbench entry and summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _taskCenterTestApp(
        TaskCenterSection(
          accessToken: 'token',
          initialProjectNumericId: 9,
          initialProjectUuid: '550e8400-e29b-41d4-a716-446655440009',
          loadingTaskProjects: false,
          loadingTaskCategories: false,
          loadingTaskApi: false,
          loadingTaskDetailsByNumericId: false,
          loadingTaskDetailsUuid: false,
          taskDetailJobIdController: TextEditingController(),
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
          taskDetailNumericIdLine: null,
          taskDetailUuidLine: null,
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

    expect(find.text(zh.taskCenterOpenWorkbench), findsOneWidget);
    expect(find.text(zh.taskCenterCompatibilityCheck), findsNothing);
    expect(
      find.text(zh.taskCenterProjectsSummary(1, '#9 古风短剧', '')),
      findsOneWidget,
    );
    expect(
      find.text(
        zh.taskCenterJobsSummary(
          1,
          '#101 asset.generate.image:queued/${zh.taskCenterPhaseImage}',
          '',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('task center workbench dialog shows seeded controls', (
    WidgetTester tester,
  ) async {
    final detailController = TextEditingController();
    addTearDown(detailController.dispose);

    await tester.pumpWidget(
      _taskCenterTestApp(
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

    await tester.tap(find.text(zh.taskCenterOpenWorkbench));
    await tester.pumpAndSettle();

    expect(find.text(zh.taskCenterWorkbenchTitle), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('product studio hides legacy compatibility probes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _taskCenterTestApp(
        TaskCenterSection(
          studioPresentation: true,
          accessToken: 'token',
          initialProjectNumericId: null,
          initialProjectUuid: null,
          loadingTaskProjects: false,
          loadingTaskCategories: false,
          loadingTaskApi: false,
          loadingTaskDetailsByNumericId: false,
          loadingTaskDetailsUuid: false,
          taskDetailJobIdController: TextEditingController(),
          taskProjects: null,
          taskCategoriesLine: null,
          taskApiSummaryLine: null,
          taskDetailNumericIdLine: null,
          taskDetailUuidLine: null,
          taskApiJobs: null,
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

    expect(find.text(zh.taskCenterOpenWorkbench), findsOneWidget);
    expect(find.text(zh.taskCenterCompatibilityCheck), findsNothing);
  });

  testWidgets('product studio autoloads task summary on first frame', (
    WidgetTester tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      _taskCenterTestApp(
        TaskCenterSection(
          studioPresentation: true,
          accessToken: 'token',
          initialProjectNumericId: null,
          initialProjectUuid: null,
          loadingTaskProjects: false,
          loadingTaskCategories: false,
          loadingTaskApi: false,
          loadingTaskDetailsByNumericId: false,
          loadingTaskDetailsUuid: false,
          taskDetailJobIdController: TextEditingController(),
          taskProjects: null,
          taskCategoriesLine: null,
          taskApiSummaryLine: null,
          taskDetailNumericIdLine: null,
          taskDetailUuidLine: null,
          taskApiJobs: null,
          taskApiLoadState: StudioLoadState.initial,
          onTaskDetailJobIdChanged: (_) {},
          onLoadTaskProjects: () {},
          onLoadTaskCategories: () {},
          onLoadTaskApi: () => loadCount++,
          onProbeTaskDetailByNumericId: () {},
          onProbeTaskDetailUuid: () {},
          onSelectTaskJob: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(loadCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product studio shows loaded-empty state with bottom count', (
    WidgetTester tester,
  ) async {
    var loadRequested = false;
    await tester.pumpWidget(
      _taskCenterTestApp(
        TaskCenterSection(
          studioPresentation: true,
          accessToken: 'token',
          initialProjectNumericId: null,
          initialProjectUuid: null,
          loadingTaskProjects: false,
          loadingTaskCategories: false,
          loadingTaskApi: false,
          loadingTaskDetailsByNumericId: false,
          loadingTaskDetailsUuid: false,
          taskDetailJobIdController: TextEditingController(),
          taskProjects: const [],
          taskCategoriesLine: null,
          taskApiSummaryLine: 'rows=0',
          taskDetailNumericIdLine: null,
          taskDetailUuidLine: null,
          taskApiJobs: const [],
          taskApiLoadState: StudioLoadState.success,
          onTaskDetailJobIdChanged: (_) {},
          onLoadTaskProjects: () {},
          onLoadTaskCategories: () {},
          onLoadTaskApi: () => loadRequested = true,
          onProbeTaskDetailByNumericId: () {},
          onProbeTaskDetailUuid: () {},
          onSelectTaskJob: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text(zh.taskCenterJobsEmpty), findsOneWidget);
    expect(find.text(zh.taskCenterJobsCount(0)), findsOneWidget);
    expect(find.text(zh.taskCenterRefreshSummary), findsWidgets);
    expect(find.text(zh.taskCenterOpenWorkbench), findsOneWidget);
    expect(loadRequested, isFalse);
  });
}
