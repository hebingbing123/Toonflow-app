import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
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

    expect(find.text('打开任务工作台'), findsOneWidget);
    expect(find.text('1 个项目 · #9 古风短剧'), findsOneWidget);
    expect(
      find.text('1 条任务 · #101 asset.generate.image:queued'),
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

    await tester.tap(find.text('打开任务工作台'));
    await tester.pumpAndSettle();

    expect(find.text('任务工作台'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });
}
