import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/components/studio_skeleton.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/jobs/section_view.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/platform/studio_load_state.dart';
import 'package:openflow_app/rust_api/core.dart';

/// Wave-1 `jobs_default` studio error path.
void main() {
  testWidgets('jobs studio presentation shows API error callout', (
    WidgetTester tester,
  ) async {
    final jobIdController = TextEditingController();
    addTearDown(jobIdController.dispose);

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
        home: Scaffold(
          body: JobsSectionView(
            studioPresentation: true,
            model: JobsSectionViewModel(
              loadingJobs: false,
              loadingJobKinds: false,
              loadingJobKindSummary: false,
              loadingJobStatusSummary: false,
              creatingJob: false,
              loadingJobById: false,
              jobIdController: jobIdController,
              jobs: null,
              jobsLoadState: StudioLoadState.error,
              jobsLastError: RustApiException('jobs_unavailable', statusCode: 503),
              jobByIdLine: null,
              jobKindsLine: null,
              jobKindSummaryLine: null,
              jobStatusSummaryLine: null,
              cancellingJobId: null,
              retryingJobId: null,
            ),
            callbacks: JobsSectionViewCallbacks(
              onJobIdChanged: (_) {},
              onLoadJobs: () {},
              onLoadJobsKindFlutterProbe: () {},
              onLoadJobsStatusFailed: () {},
              onLoadJobsKindProbeStatusQueued: () {},
              onLoadJobKinds: () {},
              onLoadJobKindSummary: () {},
              onLoadJobStatusSummary: () {},
              onCreateProbeJob: () {},
              onFetchJobById: () {},
              onSelectJob: (_) {},
              onRetryFailedJob: (_) {},
              onCancelQueuedJob: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudioApiErrorCallout), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('jobs studio presentation shows skeleton while loading', (
    WidgetTester tester,
  ) async {
    final jobIdController = TextEditingController();
    addTearDown(jobIdController.dispose);

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
        home: Scaffold(
          body: JobsSectionView(
            studioPresentation: true,
            model: JobsSectionViewModel(
              loadingJobs: false,
              loadingJobKinds: false,
              loadingJobKindSummary: false,
              loadingJobStatusSummary: false,
              creatingJob: false,
              loadingJobById: false,
              jobIdController: jobIdController,
              jobs: null,
              jobsLoadState: StudioLoadState.loading,
              jobByIdLine: null,
              jobKindsLine: null,
              jobKindSummaryLine: null,
              jobStatusSummaryLine: null,
              cancellingJobId: null,
              retryingJobId: null,
            ),
            callbacks: JobsSectionViewCallbacks(
              onJobIdChanged: (_) {},
              onLoadJobs: () {},
              onLoadJobsKindFlutterProbe: () {},
              onLoadJobsStatusFailed: () {},
              onLoadJobsKindProbeStatusQueued: () {},
              onLoadJobKinds: () {},
              onLoadJobKindSummary: () {},
              onLoadJobStatusSummary: () {},
              onCreateProbeJob: () {},
              onFetchJobById: () {},
              onSelectJob: (_) {},
              onRetryFailedJob: (_) {},
              onCancelQueuedJob: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StudioSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expectNoBenignQueuedExceptions(tester);
  });
}
