import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/jobs/section_view.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/l10n/studio_code_labels.dart';
import 'package:openflow_app/platform/studio_load_state.dart';
import 'package:openflow_app/rust_api.dart';

import 'support/studio_collapsible_filter_test_support.dart';

final AppLocalizationsZh _zhL10n = AppLocalizationsZh();

String _jobRowTitle(String status) =>
    studioJobListTitle(_zhL10n, 'flutter.probe', status);

void noop() {}

JobRow buildJob({
  required String id,
  required String status,
  String? claimedBy,
  String? errorMessage,
}) {
  return JobRow(
    numericTaskId: 7,
    id: id,
    ownerUserId: 'user-1',
    kind: 'flutter.probe',
    status: status,
    payload: const <String, dynamic>{'probe': true},
    errorMessage: errorMessage,
    claimedBy: claimedBy,
    createdAt: '2026-04-14T08:00:00Z',
    updatedAt: '2026-04-14T08:00:00Z',
  );
}

JobsSectionViewModel buildModel({
  required TextEditingController jobIdController,
  bool loadingJobs = false,
  bool loadingJobKinds = false,
  bool loadingJobKindSummary = false,
  bool loadingJobStatusSummary = false,
  bool creatingJob = false,
  bool loadingJobById = false,
  List<JobRow>? jobs,
  String? jobByIdLine = 'job-1 · failed',
  String? jobKindsLine = 'flutter.probe, storyboard.generate',
  String? jobKindSummaryLine = 'flutter.probe=1',
  String? jobStatusSummaryLine = 'failed=1',
  String? cancellingJobId,
  String? retryingJobId,
  StudioLoadState jobsLoadState = StudioLoadState.initial,
  Object? jobsLastError,
}) {
  return JobsSectionViewModel(
    loadingJobs: loadingJobs,
    loadingJobKinds: loadingJobKinds,
    loadingJobKindSummary: loadingJobKindSummary,
    loadingJobStatusSummary: loadingJobStatusSummary,
    creatingJob: creatingJob,
    loadingJobById: loadingJobById,
    jobIdController: jobIdController,
    jobsLoadState: jobsLoadState,
    jobsLastError: jobsLastError,
    jobs:
        jobs ??
        <JobRow>[
          buildJob(
            id: 'job-1',
            status: 'failed',
            errorMessage: 'provider timeout',
          ),
          buildJob(id: 'job-2', status: 'queued', claimedBy: 'worker-a'),
        ],
    jobByIdLine: jobByIdLine,
    jobKindsLine: jobKindsLine,
    jobKindSummaryLine: jobKindSummaryLine,
    jobStatusSummaryLine: jobStatusSummaryLine,
    cancellingJobId: cancellingJobId,
    retryingJobId: retryingJobId,
  );
}

JobsSectionViewCallbacks buildCallbacks({
  ValueChanged<String>? onJobIdChanged,
  VoidCallback? onLoadJobs = noop,
  VoidCallback? onLoadJobsKindFlutterProbe = noop,
  VoidCallback? onLoadJobsStatusFailed = noop,
  VoidCallback? onLoadJobsKindProbeStatusQueued = noop,
  VoidCallback? onLoadJobKinds = noop,
  VoidCallback? onLoadJobKindSummary = noop,
  VoidCallback? onLoadJobStatusSummary = noop,
  VoidCallback? onCreateProbeJob = noop,
  VoidCallback? onFetchJobById = noop,
  ValueChanged<JobRow>? onSelectJob,
  ValueChanged<JobRow>? onRetryFailedJob,
  ValueChanged<JobRow>? onCancelQueuedJob,
}) {
  return JobsSectionViewCallbacks(
    onJobIdChanged: onJobIdChanged ?? (_) {},
    onLoadJobs: onLoadJobs,
    onLoadJobsKindFlutterProbe: onLoadJobsKindFlutterProbe,
    onLoadJobsStatusFailed: onLoadJobsStatusFailed,
    onLoadJobsKindProbeStatusQueued: onLoadJobsKindProbeStatusQueued,
    onLoadJobKinds: onLoadJobKinds,
    onLoadJobKindSummary: onLoadJobKindSummary,
    onLoadJobStatusSummary: onLoadJobStatusSummary,
    onCreateProbeJob: onCreateProbeJob,
    onFetchJobById: onFetchJobById,
    onSelectJob: onSelectJob ?? (_) {},
    onRetryFailedJob: onRetryFailedJob ?? (_) {},
    onCancelQueuedJob: onCancelQueuedJob ?? (_) {},
  );
}

void main() {
  late TextEditingController jobIdController;

  setUp(() {
    jobIdController = TextEditingController(text: 'job-1');
  });

  tearDown(() {
    jobIdController.dispose();
  });

  testWidgets('jobs section view renders summaries and rows', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: JobsSectionView(
            model: buildModel(jobIdController: jobIdController),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('任务作业'), findsOneWidget);
    expect(find.text('查看作业详情'), findsOneWidget);
    expect(find.text('作业详情：job-1 · failed'), findsOneWidget);
    expect(
      find.text('作业类型：flutter.probe, storyboard.generate'),
      findsOneWidget,
    );
    expect(find.text('类型汇总：flutter.probe=1'), findsOneWidget);
    expect(find.text('状态汇总：failed=1'), findsOneWidget);
    expect(find.text('2 条作业'), findsOneWidget);
    expect(find.widgetWithText(ListTile, _jobRowTitle('failed')), findsOneWidget);
    expect(find.widgetWithText(ListTile, _jobRowTitle('queued')), findsOneWidget);
    expect(find.textContaining('失败原因：provider timeout'), findsOneWidget);
    expect(find.textContaining('认领者：worker-a'), findsOneWidget);
    expect(find.widgetWithText(TextButton, _zhL10n.jobsRetry), findsOneWidget);
    expect(find.widgetWithText(TextButton, _zhL10n.jobsCancel), findsOneWidget);
  });

  testWidgets('jobs section view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: JobsSectionView(
            model: buildModel(
              jobIdController: jobIdController,
              loadingJobs: true,
              loadingJobKinds: true,
              loadingJobKindSummary: true,
              loadingJobStatusSummary: true,
              creatingJob: true,
              loadingJobById: true,
              retryingJobId: 'job-1',
              cancellingJobId: 'job-2',
            ),
            callbacks: buildCallbacks(
              onLoadJobs: null,
              onLoadJobsKindFlutterProbe: null,
              onLoadJobsStatusFailed: null,
              onLoadJobsKindProbeStatusQueued: null,
              onLoadJobKinds: null,
              onLoadJobKindSummary: null,
              onLoadJobStatusSummary: null,
              onCreateProbeJob: null,
              onFetchJobById: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<ButtonStyleButton>(find.byType(ButtonStyleButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );
    expect(find.text('…'), findsWidgets);
  });

  testWidgets('jobs section view forwards row actions', (
    WidgetTester tester,
  ) async {
    JobRow? selectedJob;
    JobRow? retriedJob;
    JobRow? cancelledJob;

    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: JobsSectionView(
            model: buildModel(jobIdController: jobIdController),
            callbacks: buildCallbacks(
              onSelectJob: (job) => selectedJob = job,
              onRetryFailedJob: (job) => retriedJob = job,
              onCancelQueuedJob: (job) => cancelledJob = job,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, _jobRowTitle('failed')));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _zhL10n.jobsRetry));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _zhL10n.jobsCancel));
    await tester.pump();

    expect(selectedJob?.id, 'job-1');
    expect(retriedJob?.id, 'job-1');
    expect(cancelledJob?.id, 'job-2');
  });

  testWidgets('jobs section view only exposes retry for failed jobs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final model = buildModel(
      jobIdController: jobIdController,
      jobs: <JobRow>[
        buildJob(id: 'job-failed', status: 'failed', errorMessage: 'timeout'),
        buildJob(id: 'job-running', status: 'running', claimedBy: 'worker-a'),
        buildJob(id: 'job-success', status: 'succeeded'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: JobsSectionView(
            model: model,
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, _jobRowTitle('failed')), findsOneWidget);
    expect(find.widgetWithText(ListTile, _jobRowTitle('running')), findsOneWidget);
    expect(find.widgetWithText(ListTile, _jobRowTitle('succeeded')), findsOneWidget);
    expect(find.widgetWithText(TextButton, _zhL10n.jobsRetry), findsOneWidget);
    expect(find.widgetWithText(TextButton, _zhL10n.jobsCancel), findsOneWidget);
  });

  testWidgets('product studio hides flutter.probe regression panel', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: JobsSectionView(
            studioPresentation: true,
            model: buildModel(jobIdController: jobIdController),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    await tester.pump();
    await expandStudioCollapsibleFilterPanel(tester);

    expect(find.text(_zhL10n.jobsLoadList), findsOneWidget);
    expect(find.text('查看失败作业'), findsOneWidget);
    expect(
      find.text('查看作业列表、状态汇总，并按 ID 打开单条执行记录。'),
      findsOneWidget,
    );
    expect(find.text('开发探针（Harness）'), findsNothing);
    expect(find.text('创建 probe 作业'), findsNothing);
    expect(find.text('查看作业详情'), findsNothing);
    expect(find.widgetWithText(ListTile, 'flutter.probe · failed'), findsNothing);
  });
}
