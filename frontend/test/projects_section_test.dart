import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/projects/controller.dart';
import 'package:openflow_app/projects/section.dart';
import 'package:openflow_app/rust_api.dart';

ProjectsController buildController({
  List<ProjectRow>? projects,
  List<ArtStyleRow>? artStyles,
  String? projectsSummaryLine,
  String? artStylesLine,
  String? agentMemoryBody,
}) {
  final controller = ProjectsController(
    accessTokenProvider: () => 'token',
    onErrorChanged: (_) {},
  );
  controller.projects = projects;
  controller.artStyles = artStyles;
  controller.projectsSummaryLine = projectsSummaryLine;
  controller.artStylesLine = artStylesLine;
  controller.agentMemoryBody = agentMemoryBody;
  return controller;
}

Widget buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('projects section exposes art styles workbench entry', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
      projects: const <ProjectRow>[],
      artStyles: const [
        ArtStyleRow(
          id: 'style-1',
          numericId: 11,
          name: '水墨古风',
          label: 'ink',
          prompt: 'soft ink wash',
          fileUrl: '/api/v1/art-styles/numeric/11/cover',
        ),
      ],
      projectsSummaryLine: 'projects=0',
      artStylesLine: 'total=1',
    );
    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
          accessToken: 'token',
          controller: controller,
          onOpenProjectDetail: (_) {},
          onOpenTeamWorkspaces: () {},
        ),
      ),
    );

    expect(find.text('打开画风工作台'), findsOneWidget);
    expect(find.text('打开创作手册工作台'), findsOneWidget);
    expect(find.text('打开记忆工作台'), findsOneWidget);
    expect(find.text('1 条画风'), findsOneWidget);
    expect(find.text('水墨古风'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('art styles workbench dialog shows seeded controls', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
      projects: const <ProjectRow>[],
      artStyles: const [
        ArtStyleRow(
          id: 'style-1',
          numericId: 11,
          name: '水墨古风',
          label: 'ink',
          prompt: 'soft ink wash',
          fileUrl: '/api/v1/art-styles/numeric/11/cover',
        ),
      ],
      artStylesLine: 'total=1',
    );
    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
            accessToken: 'token',
            controller: controller,
            onOpenProjectDetail: (_) {},
            onOpenTeamWorkspaces: () {},
        ),
      ),
    );

    await tester.tap(find.text('打开画风工作台'));
    await tester.pumpAndSettle();

    expect(find.text('画风工作台'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    controller.dispose();
  });

  testWidgets('projects section opens creative manuals workbench', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
      projects: const <ProjectRow>[],
      artStyles: const <ArtStyleRow>[],
    );
    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
            accessToken: 'token',
            controller: controller,
            onOpenProjectDetail: (_) {},
            onOpenTeamWorkspaces: () {},
        ),
      ),
    );

    await tester.tap(find.text('打开创作手册工作台'));
    await tester.pumpAndSettle();

    expect(find.text('创作手册工作台'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    controller.dispose();
  });

  testWidgets('projects section opens project creation brief dialog', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
      projects: const <ProjectRow>[],
      artStyles: const <ArtStyleRow>[],
    );
    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
            accessToken: 'token',
            controller: controller,
            onOpenProjectDetail: (_) {},
            onOpenTeamWorkspaces: () {},
        ),
      ),
    );

    await tester.tap(find.text('新建空项目'));
    await tester.pumpAndSettle();

    expect(find.text('新建项目'), findsOneWidget);
    expect(find.widgetWithText(TextField, '项目名'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Premise'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Brand name'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('projects section opens agent memory workbench', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
      projects: const [
        ProjectRow(
          id: 'project-1',
          numericId: 11,
          name: '项目一',
          createTimeMs: 1,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ],
      artStyles: const <ArtStyleRow>[],
    );
    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
            accessToken: 'token',
            controller: controller,
            onOpenProjectDetail: (_) {},
            onOpenTeamWorkspaces: () {},
        ),
      ),
    );

    await tester.tap(find.text('打开记忆工作台'));
    await tester.pumpAndSettle();

    expect(find.text('Agent 记忆工作台'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    controller.dispose();
  });

  testWidgets('projects section shows enterprise empty-state guidance', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
      projects: const <ProjectRow>[],
      artStyles: const <ArtStyleRow>[],
    );
    var openedTeamWorkspaces = 0;
    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
            accessToken: 'token',
            controller: controller,
            currentWorkspaceName: 'Team Alpha',
            currentWorkspaceType: 'enterprise',
            onOpenProjectDetail: (_) {},
            onOpenTeamWorkspaces: () => openedTeamWorkspaces++,
        ),
      ),
    );

    expect(find.text('当前团队空间还没有项目'), findsOneWidget);
    expect(find.textContaining('Team Alpha'), findsOneWidget);
    expect(find.text('先创建空项目'), findsOneWidget);
    expect(find.text('打开团队工作区'), findsOneWidget);

    await tester.tap(find.text('打开团队工作区'));
    await tester.pump();
    expect(openedTeamWorkspaces, 1);
    controller.dispose();
  });
}
