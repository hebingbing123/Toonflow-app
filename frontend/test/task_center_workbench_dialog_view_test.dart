import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/task_center/workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

Widget _appWithZh({required Widget child}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: Scaffold(body: child),
);

TaskCenterWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController pageCtrl,
  required TextEditingController limitCtrl,
  required TextEditingController stateCtrl,
  required TextEditingController taskClassCtrl,
  required TextEditingController projectIdCtrl,
  required TextEditingController projectUuidCtrl,
  required TextEditingController numericTaskIdCtrl,
  required TextEditingController uuidCtrl,
  TextEditingController? productionPhaseCtrl,
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
  String? categoriesSummary = '2 个分类 · storyboard, render',
  String? numericIdTaskDetailText,
  String? uuidDetails,
  String? statusLine = '已刷新 1 条任务。',
}) {
  return TaskCenterWorkbenchDialogViewModel(
    projectSummary: '1 个项目 · #7 春季短剧',
    jobSummary: '1 条任务 · #11 storyboard:failed',
    pageCtrl: pageCtrl,
    limitCtrl: limitCtrl,
    stateCtrl: stateCtrl,
    taskClassCtrl: taskClassCtrl,
    projectIdCtrl: projectIdCtrl,
    projectUuidCtrl: projectUuidCtrl,
    numericTaskIdCtrl: numericTaskIdCtrl,
    uuidCtrl: uuidCtrl,
    productionPhaseCtrl: productionPhaseCtrl ?? TextEditingController(),
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
  ValueChanged<JobRow>? onCompensateWritebackJob,
  ValueChanged<String>? onPickProductionPhase,
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
    onCompensateWritebackJob: onCompensateWritebackJob,
    onPickProductionPhase: onPickProductionPhase ?? (_) {},
    onClose: onClose ?? noop,
  );
}

void main() {
  final zh = AppLocalizationsZh();
  late TextEditingController pageCtrl;
  late TextEditingController limitCtrl;
  late TextEditingController stateCtrl;
  late TextEditingController taskClassCtrl;
  late TextEditingController projectIdCtrl;
  late TextEditingController projectUuidCtrl;
  late TextEditingController numericTaskIdCtrl;
  late TextEditingController uuidCtrl;

  setUp(() {
    pageCtrl = TextEditingController(text: '1');
    limitCtrl = TextEditingController(text: '10');
    stateCtrl = TextEditingController(text: 'queued');
    taskClassCtrl = TextEditingController();
    projectIdCtrl = TextEditingController(text: '7');
    projectUuidCtrl = TextEditingController(
      text: '550e8400-e29b-41d4-a716-446655440007',
    );
    numericTaskIdCtrl = TextEditingController(text: '11');
    uuidCtrl = TextEditingController(text: 'job-11');
  });

  tearDown(() {
    pageCtrl.dispose();
    limitCtrl.dispose();
    stateCtrl.dispose();
    taskClassCtrl.dispose();
    projectIdCtrl.dispose();
    projectUuidCtrl.dispose();
    numericTaskIdCtrl.dispose();
    uuidCtrl.dispose();
  });

  testWidgets('task center workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWithZh(
        child: TaskCenterWorkbenchDialogView(
          model: buildDialogModel(
            pageCtrl: pageCtrl,
            limitCtrl: limitCtrl,
            stateCtrl: stateCtrl,
            taskClassCtrl: taskClassCtrl,
            projectIdCtrl: projectIdCtrl,
            projectUuidCtrl: projectUuidCtrl,
            numericTaskIdCtrl: numericTaskIdCtrl,
            uuidCtrl: uuidCtrl,
          ),
          callbacks: buildDialogCallbacks(),
        ),
      ),
    );

    expect(find.text(zh.taskCenterWorkbenchTitle), findsOneWidget);
    expect(find.text(zh.taskCenterReloadTaskProjects), findsOneWidget);
    expect(find.text(zh.taskCenterLoadTasksByFilters), findsOneWidget);
    expect(
      find.textContaining(zh.taskCenterWorkbenchRealtimeConnected.trim()),
      findsOneWidget,
    );
    expect(find.text('1 个项目 · #7 春季短剧'), findsOneWidget);
    expect(find.text('2 个分类 · storyboard, render'), findsOneWidget);
    expect(find.text('1 条任务'), findsOneWidget);
    expect(find.text(zh.taskCenterFieldProjectUuidOptional), findsOneWidget);
    expect(find.text(zh.taskCenterTaskDetailsSection), findsOneWidget);
    expect(find.textContaining('#11 · job-11'), findsOneWidget);
    expect(find.text('状态：已刷新 1 条任务。'), findsOneWidget);
  });

  testWidgets('task center workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWithZh(
        child: TaskCenterWorkbenchDialogView(
          model: buildDialogModel(
            pageCtrl: pageCtrl,
            limitCtrl: limitCtrl,
            stateCtrl: stateCtrl,
            taskClassCtrl: taskClassCtrl,
            projectIdCtrl: projectIdCtrl,
            projectUuidCtrl: projectUuidCtrl,
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
      _appWithZh(
        child: TaskCenterWorkbenchDialogView(
          model: buildDialogModel(
            pageCtrl: pageCtrl,
            limitCtrl: limitCtrl,
            stateCtrl: stateCtrl,
            taskClassCtrl: taskClassCtrl,
            projectIdCtrl: projectIdCtrl,
            projectUuidCtrl: projectUuidCtrl,
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
    );

    await tester.ensureVisible(find.widgetWithText(ActionChip, 'storyboard'));
    await tester.tap(find.widgetWithText(ActionChip, 'storyboard'));
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(TextButton, zh.taskCenterRetry),
    );
    await tester.tap(find.widgetWithText(TextButton, zh.taskCenterRetry));
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
