import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/platform/studio_load_state.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/quality_reviews/previews.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/rust_api/core.dart';
import 'package:openflow_app/task_center/section.dart';

import '../support/studio_golden_app.dart';
import '../support/ui_gallery_capture.dart';

/// Wave-1 widget goldens under [test/goldens/ui_gallery/].
void main() {
  const gallerySize = Size(720, 480);

  testWidgets('projects_empty golden', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: gallerySize,
        child: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return StudioEmptyState(
              title: l10n.studioProjectsEmptyTitle,
              subtitle: l10n.studioProjectsEmptySubtitle,
              icon: Icons.folder_open_outlined,
              actionLabel: l10n.studioCreateProject,
              onAction: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StudioEmptyState),
      matchesGoldenFile(goldenPathForScenario('projects_empty')),
    );
  });

  testWidgets('quality_empty golden', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: gallerySize,
        child: SingleChildScrollView(
          child: QualityReviewsOpsDashboardPreview(
            mutedColor: Colors.grey,
            dashboardSummary: null,
            refreshControlsEnabled: true,
            refreshSummary: null,
            dashboardLoadState: StudioLoadState.initial,
            qualityStatsRows: null,
            stageGradeRows: null,
            scopeInsightRows: null,
            tokenEfficiencyRows: null,
            badCaseStats: null,
            onRefreshDashboard: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StudioEmptyState),
      matchesGoldenFile(goldenPathForScenario('quality_empty')),
    );
  });

  testWidgets('tasks_empty golden', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: gallerySize,
        child: TaskCenterSection(
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
          taskApiJobs: const <JobRow>[],
          taskApiLoadState: StudioLoadState.success,
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

    await expectLater(
      find.byType(StudioEmptyState),
      matchesGoldenFile(goldenPathForScenario('tasks_empty')),
    );
  });

  testWidgets('api_error_callout golden', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(520, 160),
        child: StudioApiErrorCallout(
          error: RustApiException('service_unavailable', statusCode: 503),
          onRetry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StudioApiErrorCallout),
      matchesGoldenFile(goldenPathForScenario('api_error_callout')),
    );
  });
}
