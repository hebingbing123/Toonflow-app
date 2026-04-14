import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/jobs/section_view.dart';
import 'package:toonflow_app/rust_api.dart';

void noop() {}

JobRow buildJob({
  required String id,
  required String status,
  String? claimedBy,
}) {
  return JobRow(
    numericTaskId: 7,
    id: id,
    ownerUserId: 'user-1',
    kind: 'flutter.probe',
    status: status,
    payload: const <String, dynamic>{'probe': true},
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
}) {
  return JobsSectionViewModel(
    loadingJobs: loadingJobs,
    loadingJobKinds: loadingJobKinds,
    loadingJobKindSummary: loadingJobKindSummary,
    loadingJobStatusSummary: loadingJobStatusSummary,
    creatingJob: creatingJob,
    loadingJobById: loadingJobById,
    jobIdController: jobIdController,
    jobs:
        jobs ??
        <JobRow>[
          buildJob(id: 'job-1', status: 'failed'),
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobsSectionView(
            model: buildModel(jobIdController: jobIdController),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

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
    expect(
      find.widgetWithText(ListTile, 'flutter.probe · failed'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, 'flutter.probe · queued'),
      findsOneWidget,
    );
    expect(find.textContaining('claimed_by=worker-a'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
  });

  testWidgets('jobs section view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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

    await tester.pumpWidget(
      MaterialApp(
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

    await tester.tap(find.widgetWithText(ListTile, 'flutter.probe · failed'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '重试'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pump();

    expect(selectedJob?.id, 'job-1');
    expect(retriedJob?.id, 'job-1');
    expect(cancelledJob?.id, 'job-2');
  });
}
