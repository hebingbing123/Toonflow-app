import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
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

/// Wave-1 scenario `tasks_api_error`.
void main() {
  testWidgets('studio task center shows loadFailed with retry', (
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

    expect(find.byType(StudioEmptyState), findsWidgets);
    expect(find.text('重试'), findsOneWidget);
    expect(find.textContaining('uuid='), findsNothing);
    expectNoBenignQueuedExceptions(tester);
  });
}
