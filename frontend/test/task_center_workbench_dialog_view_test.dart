import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/task_center/workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

TaskCenterWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController pageCtrl,
  required TextEditingController limitCtrl,
  required TextEditingController stateCtrl,
  required TextEditingController taskClassCtrl,
  required TextEditingController projectIdCtrl,
  required TextEditingController numericTaskIdCtrl,
  required TextEditingController uuidCtrl,
  List<TaskCenterTaskClassRow> categories = const <TaskCenterTaskClassRow>[
    TaskCenterTaskClassRow(taskClass: 'storyboard'),
    TaskCenterTaskClassRow(taskClass: 'render'),
  ],
  List<JobRow> jobs = const <JobRow>[
    JobRow(
      numericTaskId: 11,
      id: 'job-11',
      ownerUserId: 'user-1',
      kind: 'storyboard',
      status: 'failed',
      payload: <String, dynamic>{'project_id': 7},
      errorMessage: 'provider timeout',
      createdAt: '2026-04-14T12:00:00Z',
      updatedAt: '2026-04-14T12:05:00Z',
    ),
  ],
  bool loadingProjects = false,
  bool loadingCategories = false,
  bool loadingTasks = false,
  bool loadingNumericIdTaskDetail = false,
  bool loadingUuidDetails = false,
  bool liveUpdatesConnected = true,
  String? retryingJobId,
  String? cancellingJobId,
  String? categoriesSummary = '分类 2 个 · storyboard, render',
  String? numericIdTaskDetailText,
  String? uuidDetails,
  String? statusLine = '已刷新 1 条任务。',
}) {
  return TaskCenterWorkbenchDialogViewModel(
    projectSummary: '项目 1 个 · #7 春季短剧',
    jobSummary: '任务 1 条 · #11 storyboard:failed',
    pageCtrl: pageCtrl,
    limitCtrl: limitCtrl,
    stateCtrl: stateCtrl,
    taskClassCtrl: taskClassCtrl,
    projectIdCtrl: projectIdCtrl,
    numericTaskIdCtrl: numericTaskIdCtrl,
    uuidCtrl: uuidCtrl,
    categories: categories,
    jobs: jobs,
    categoriesSummary: categoriesSummary,
    numericIdTaskDetailText:
        numericIdTaskDetailText ?? '#11 · storyboard · failed · uuid=job-11',
    uuidDetails: uuidDetails ?? '#11 · storyboard · failed · uuid=job-11',
    statusLine: statusLine,
    loadingProjects: loadingProjects,
    loadingCategories: loadingCategories,
    loadingTasks: loadingTasks,
    loadingNumericIdTaskDetail: loadingNumericIdTaskDetail,
    loadingUuidDetails: loadingUuidDetails,
    retryingJobId: retryingJobId,
    cancellingJobId: cancellingJobId,
    liveUpdatesConnected: liveUpdatesConnected,
  );
}

TaskCenterWorkbenchDialogViewCallbacks buildDialogCallbacks({
  VoidCallback? onLoadProjects = noop,
  VoidCallback? onLoadCategories = noop,
  VoidCallback? onLoadTasks = noop,
  VoidCallback? onLoadNumericIdTaskDetail = noop,
  VoidCallback? onLoadUuidDetails = noop,
  ValueChanged<String>? onPickCategory,
  ValueChanged<JobRow>? onPickJob,
  ValueChanged<JobRow>? onRetryFailedJob,
  ValueChanged<JobRow>? onCancelQueuedJob,
  VoidCallback? onClose = noop,
}) {
  return TaskCenterWorkbenchDialogViewCallbacks(
    onLoadProjects: onLoadProjects ?? noop,
    onLoadCategories: onLoadCategories ?? noop,
    onLoadTasks: onLoadTasks ?? noop,
    onLoadNumericIdTaskDetail: onLoadNumericIdTaskDetail ?? noop,
    onLoadUuidDetails: onLoadUuidDetails ?? noop,
    onPickCategory: onPickCategory ?? (_) {},
    onPickJob: onPickJob ?? (_) {},
    onRetryFailedJob: onRetryFailedJob ?? (_) {},
    onCancelQueuedJob: onCancelQueuedJob ?? (_) {},
    onClose: onClose ?? noop,
  );
}

void main() {
  late TextEditingController pageCtrl;
  late TextEditingController limitCtrl;
  late TextEditingController stateCtrl;
  late TextEditingController taskClassCtrl;
  late TextEditingController projectIdCtrl;
  late TextEditingController numericTaskIdCtrl;
  late TextEditingController uuidCtrl;

  setUp(() {
    pageCtrl = TextEditingController(text: '1');
    limitCtrl = TextEditingController(text: '10');
    stateCtrl = TextEditingController(text: 'queued');
    taskClassCtrl = TextEditingController();
    projectIdCtrl = TextEditingController(text: '7');
    numericTaskIdCtrl = TextEditingController(text: '11');
    uuidCtrl = TextEditingController(text: 'job-11');
  });

  tearDown(() {
    pageCtrl.dispose();
    limitCtrl.dispose();
    stateCtrl.dispose();
    taskClassCtrl.dispose();
    projectIdCtrl.dispose();
    numericTaskIdCtrl.dispose();
    uuidCtrl.dispose();
  });

  testWidgets('task center workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCenterWorkbenchDialogView(
            model: buildDialogModel(
              pageCtrl: pageCtrl,
              limitCtrl: limitCtrl,
              stateCtrl: stateCtrl,
              taskClassCtrl: taskClassCtrl,
              projectIdCtrl: projectIdCtrl,
              numericTaskIdCtrl: numericTaskIdCtrl,
              uuidCtrl: uuidCtrl,
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('任务工作台'), findsOneWidget);
    expect(find.text('刷新任务项目'), findsOneWidget);
    expect(find.text('按筛选加载任务'), findsOneWidget);
    expect(find.textContaining('当前已接入实时任务更新'), findsOneWidget);
    expect(find.text('项目 1 个 · #7 春季短剧'), findsOneWidget);
    expect(find.text('分类 2 个 · storyboard, render'), findsOneWidget);
    expect(find.text('1 条任务'), findsOneWidget);
    expect(find.text('任务详情'), findsOneWidget);
    expect(find.textContaining('#11 · job-11'), findsOneWidget);
    expect(find.text('状态：已刷新 1 条任务。'), findsOneWidget);
  });

  testWidgets('task center workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCenterWorkbenchDialogView(
            model: buildDialogModel(
              pageCtrl: pageCtrl,
              limitCtrl: limitCtrl,
              stateCtrl: stateCtrl,
              taskClassCtrl: taskClassCtrl,
              projectIdCtrl: projectIdCtrl,
              numericTaskIdCtrl: numericTaskIdCtrl,
              uuidCtrl: uuidCtrl,
              loadingProjects: true,
              loadingCategories: true,
              loadingTasks: true,
              loadingNumericIdTaskDetail: true,
              loadingUuidDetails: true,
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(buttons.every((button) => button.onPressed == null), isTrue);
  });

  testWidgets('task center workbench view forwards category and job picks', (
    WidgetTester tester,
  ) async {
    String? pickedCategory;
    JobRow? pickedJob;
    JobRow? retriedJob;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCenterWorkbenchDialogView(
            model: buildDialogModel(
              pageCtrl: pageCtrl,
              limitCtrl: limitCtrl,
              stateCtrl: stateCtrl,
              taskClassCtrl: taskClassCtrl,
              projectIdCtrl: projectIdCtrl,
              numericTaskIdCtrl: numericTaskIdCtrl,
              uuidCtrl: uuidCtrl,
            ),
            callbacks: buildDialogCallbacks(
              onPickCategory: (value) => pickedCategory = value,
              onPickJob: (job) => pickedJob = job,
              onRetryFailedJob: (job) => retriedJob = job,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.widgetWithText(ActionChip, 'storyboard'));
    await tester.tap(find.widgetWithText(ActionChip, 'storyboard'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
    await tester.tap(find.widgetWithText(TextButton, '重试'));
    await tester.pump();
    await tester.ensureVisible(find.byType(ListTile).first);
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();

    expect(pickedCategory, 'storyboard');
    expect(pickedJob?.numericTaskId, 11);
    expect(pickedJob?.id, 'job-11');
    expect(retriedJob?.id, 'job-11');
  });
}

void noop() {}
