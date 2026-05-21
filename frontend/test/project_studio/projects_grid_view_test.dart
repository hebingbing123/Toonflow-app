import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_studio/projects_grid_view.dart';
import 'package:openflow_app/rust_api.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 420,
        height: 320,
        child: child,
      ),
    ),
  );
}

const _sampleProject = ProjectRow(
  id: 'project-9',
  numericId: 9,
  name: '古风短剧',
  projectAccessMode: 'inherited',
  projectAccessRole: 'member',
);

void main() {
  final zh = AppLocalizationsZh();

  testWidgets('project card body selects scope without opening studio', (
    WidgetTester tester,
  ) async {
    var selected = 0;
    var opened = 0;

    await tester.pumpWidget(
      _wrap(
        ProjectsGridView(
          projects: const [_sampleProject],
          currentProjectNumericId: null,
          onSelectProject: (_) async {
            selected++;
          },
          onOpenProject: (_) {
            opened++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('project_select_scope_9')));
    await tester.pump();

    expect(selected, 1);
    expect(opened, 0);
    expect(find.text(zh.studioProjectCardTapToSelect), findsOneWidget);
  });

  testWidgets('project card enter-studio button opens studio only', (
    WidgetTester tester,
  ) async {
    var selected = 0;
    var opened = 0;

    await tester.pumpWidget(
      _wrap(
        ProjectsGridView(
          projects: const [_sampleProject],
          onSelectProject: (_) async {
            selected++;
          },
          onOpenProject: (_) {
            opened++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('project_enter_studio_9')));
    await tester.pump();

    expect(selected, 0);
    expect(opened, 1);
  });

  testWidgets('project card without scope selector opens studio from body tap', (
    WidgetTester tester,
  ) async {
    var opened = 0;

    await tester.pumpWidget(
      _wrap(
        ProjectsGridView(
          projects: const [_sampleProject],
          onOpenProject: (_) {
            opened++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('project_select_scope_9')));
    await tester.pump();

    expect(opened, 1);
    expect(find.text(zh.studioProjectCardTapToSelect), findsNothing);
  });
}
