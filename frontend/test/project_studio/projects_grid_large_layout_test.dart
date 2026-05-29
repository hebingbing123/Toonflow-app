import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/projects_grid_view.dart';
import 'package:openflow_app/rust_api.dart';

List<ProjectRow> _sampleProjects(int count) {
  return List<ProjectRow>.generate(
    count,
    (index) => ProjectRow(
      id: 'project-$index',
      numericId: index,
      name: 'E2E audit seed $index',
      projectAccessMode: 'inherited',
      projectAccessRole: 'member',
    ),
    growable: false,
  );
}

void main() {
  testWidgets('20-card sliver grid layout pumps without flex overflow', (
    WidgetTester tester,
  ) async {
    final overflowErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') ||
          text.contains('RenderFlex') && text.contains('overflow')) {
        overflowErrors.add(details);
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1280,
              height: 900,
              child: CustomScrollView(
                slivers: <Widget>[
                  ProjectsGridView(
                    asSliver: true,
                    contentWidth: 1280,
                    projects: _sampleProjects(20),
                    onOpenProject: (_) {},
                    progressForProject: (project) => project.numericId % 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(overflowErrors, isEmpty);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('E2E audit seed 0'), findsOneWidget);
    // SliverGrid virtualizes — later cards require scroll; ensure delegate count.
    expect(
      tester.widgetList(find.byType(RepaintBoundary)).length,
      greaterThanOrEqualTo(1),
    );
  });

  testWidgets('bounded split grid uses scrollable GridView not shrinkWrap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 900,
              height: 700,
              child: ProjectsGridView(
                projects: _sampleProjects(12),
                boundedMaxHeight: 400,
                contentWidth: 600,
                onOpenProject: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.shrinkWrap, isFalse);
    expect(grid.physics, isNot(const NeverScrollableScrollPhysics()));
  });
}
