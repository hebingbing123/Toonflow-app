import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
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
    l10nProvider: () => null,
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
  final zh = AppLocalizationsZh();

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

    expect(find.text(zh.projectsOpenArtStylesWorkbench), findsOneWidget);
    expect(find.text(zh.projectsOpenCreativeManualsWorkbench), findsOneWidget);
    expect(find.text(zh.projectsOpenAgentMemoryWorkbench), findsOneWidget);
    expect(find.text(zh.projectsArtStyleCount(1)), findsOneWidget);
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

    await tester.tap(find.text(zh.projectsOpenArtStylesWorkbench));
    await tester.pumpAndSettle();

    expect(find.text(zh.projectsArtWorkbenchTitle), findsOneWidget);
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

    await tester.tap(find.text(zh.projectsOpenCreativeManualsWorkbench));
    await tester.pumpAndSettle();

    expect(find.text(zh.projectsCreativeManualTitle), findsOneWidget);
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

    await tester.tap(find.text(zh.projectsCreateEmptyProject));
    await tester.pumpAndSettle();

    expect(find.text(zh.projectsDialogCreateTitle), findsOneWidget);
    expect(find.widgetWithText(TextField, zh.projectsDialogFieldName), findsOneWidget);
    expect(find.widgetWithText(TextField, zh.projectsDialogFieldPremise), findsOneWidget);
    expect(find.widgetWithText(TextField, zh.projectsDialogFieldBrandName), findsOneWidget);
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

    await tester.tap(find.text(zh.projectsOpenAgentMemoryWorkbench));
    await tester.pumpAndSettle();

    expect(find.text(zh.agentMemoryWorkbenchTitle), findsOneWidget);
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

    expect(find.text(zh.projectsEnterpriseEmptyTitle), findsOneWidget);
    expect(find.textContaining('Team Alpha'), findsOneWidget);
    expect(find.text(zh.projectsCreateFirstEmpty), findsOneWidget);
    expect(find.text(zh.projectsOpenTeamWorkspaces), findsOneWidget);

    await tester.tap(find.text(zh.projectsOpenTeamWorkspaces));
    await tester.pump();
    expect(openedTeamWorkspaces, 1);
    controller.dispose();
  });

  testWidgets('product presentation lets users select a project from home', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = buildController(
      projects: const [
        ProjectRow(
          id: 'project-1',
          workspaceId: 'workspace-1',
          numericId: 11,
          name: '项目一',
          intro: '继续制作',
          createTimeMs: 1,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ],
      artStyles: const <ArtStyleRow>[],
    );
    ProjectRow? selectedProject;
    ProjectRow? openedProject;
    await tester.pumpWidget(
      buildTestApp(
        ProjectsSection(
          accessToken: null,
          controller: controller,
          productPresentation: true,
          currentProjectNumericId: null,
          onOpenProjectDetail: (_) {},
          onSelectProjectScope: (row) async {
            selectedProject = row;
          },
          onOpenProjectStudio: (row) {
            openedProject = row;
          },
          onOpenTeamWorkspaces: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.studioPipelineSelectProjectFirst), findsOneWidget);

    await tester.tap(find.text('项目一').first);
    await tester.pumpAndSettle();

    expect(selectedProject?.numericId, 11);
    expect(openedProject, isNull);

    await tester.ensureVisible(find.byKey(const Key('project_enter_studio_11')));
    await tester.tap(find.byKey(const Key('project_enter_studio_11')));
    await tester.pumpAndSettle();

    expect(openedProject?.numericId, 11);
    controller.dispose();
  });
}
