import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_skeleton.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/platform/studio_load_state.dart';
import 'package:openflow_app/rust_api/core.dart';
import 'package:openflow_app/task_center/section.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('task center loading shows skeleton via StudioAsyncDataView', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TaskCenterSection(
          studioPresentation: true,
          accessToken: 'token',
          initialProjectNumericId: null,
          initialProjectUuid: null,
          loadingTaskProjects: false,
          loadingTaskCategories: false,
          loadingTaskApi: true,
          loadingTaskDetailsByNumericId: false,
          loadingTaskDetailsUuid: false,
          taskDetailJobIdController: TextEditingController(),
          taskProjects: null,
          taskCategoriesLine: null,
          taskApiSummaryLine: null,
          taskDetailNumericIdLine: null,
          taskDetailUuidLine: null,
          taskApiJobs: null,
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
    await tester.pump();

    expect(find.byType(StudioAsyncDataView), findsOneWidget);
    expect(find.byType(StudioSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('task center error uses loadFailed inside async view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
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
          taskApiLoadState: StudioLoadState.error,
          taskApiLastError: RustApiException('tasks_unavailable', statusCode: 503),
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

    expect(find.byType(StudioAsyncDataView), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
