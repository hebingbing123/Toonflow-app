import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/task_center/section.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  testWidgets('task center exposes workbench entry and summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCenterSection(
            accessToken: 'token',
            loadingTaskProjects: false,
            loadingTaskCategories: false,
            loadingTaskApi: false,
            loadingTaskDetailsLegacy: false,
            loadingTaskDetailsUuid: false,
            taskDetailJobIdController: TextEditingController(),
            taskProjects: const [LegacyTasksProjectItem(numericId: 9, name: '古风短剧')],
            taskCategoriesLine:
                '分类 2 个 · asset.generate.image, script.export.zip',
            taskApiSummaryLine: 'page=1 limit=10 · total=1 · page_rows=1',
            taskDetailLegacyLine: null,
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
            onProbeTaskDetailLegacy: () {},
            onProbeTaskDetailUuid: () {},
            onSelectTaskJob: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('打开任务工作台'), findsOneWidget);
    expect(find.text('项目 1 个 · #9 古风短剧'), findsOneWidget);
    expect(
      find.text('任务 1 条 · #101 asset.generate.image:queued'),
      findsOneWidget,
    );
  });

  testWidgets('task center workbench dialog shows seeded controls', (
    WidgetTester tester,
  ) async {
    final detailController = TextEditingController();
    addTearDown(detailController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCenterSection(
            accessToken: 'token',
            loadingTaskProjects: false,
            loadingTaskCategories: false,
            loadingTaskApi: false,
            loadingTaskDetailsLegacy: false,
            loadingTaskDetailsUuid: false,
            taskDetailJobIdController: detailController,
            taskProjects: const [LegacyTasksProjectItem(numericId: 9, name: '古风短剧')],
            taskCategoriesLine:
                '分类 2 个 · asset.generate.image, script.export.zip',
            taskApiSummaryLine: 'page=1 limit=10 · total=1 · page_rows=1',
            taskDetailLegacyLine:
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
            onProbeTaskDetailLegacy: () {},
            onProbeTaskDetailUuid: () {},
            onSelectTaskJob: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开任务工作台'));
    await tester.pumpAndSettle();

    expect(find.text('任务工作台'), findsOneWidget);
    expect(find.text('筛选与列表'), findsOneWidget);
    expect(find.text('任务详情'), findsOneWidget);
    expect(find.text('刷新任务项目'), findsOneWidget);
    expect(find.text('按筛选加载任务'), findsOneWidget);
    expect(find.text('读取 legacy 详情'), findsOneWidget);
    expect(find.text('读取 UUID 详情'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1'), findsWidgets);
    expect(
      find.textContaining(
        'Legacy 详情：#101 · asset.generate.image · queued · uuid=job-101',
      ),
      findsNWidgets(2),
    );
  });
}
