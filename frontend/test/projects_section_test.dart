import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/projects_section.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  testWidgets('projects section exposes art styles workbench entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectsSection(
            accessToken: 'token',
            loadingProjects: false,
            loadingProjectsSummary: false,
            loadingArtStyles: false,
            creatingProject: false,
            loadingAgentMemory: false,
            projects: const <ProjectRow>[],
            artStyles: const [
              ArtStyleRow(
                id: 'style-1',
                legacyId: 11,
                name: '水墨古风',
                label: 'ink',
                prompt: 'soft ink wash',
                fileUrl: '/api/v1/art-styles/legacy/11/cover',
              ),
            ],
            projectsSummaryLine: 'projects=0',
            artStylesLine: 'total=1',
            agentMemoryBody: null,
            onLoadProjects: () {},
            onLoadProjectsSummary: () {},
            onLoadArtStyles: () async {},
            onCreateEmptyProject: () {},
            onOpenProjectDetail: (_) {},
            onProbeAgentMemory: () {},
          ),
        ),
      ),
    );

    expect(find.text('打开画风工作台'), findsOneWidget);
    expect(find.text('1 条画风'), findsOneWidget);
    expect(find.text('水墨古风'), findsOneWidget);
  });

  testWidgets('art styles workbench dialog shows seeded controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectsSection(
            accessToken: 'token',
            loadingProjects: false,
            loadingProjectsSummary: false,
            loadingArtStyles: false,
            creatingProject: false,
            loadingAgentMemory: false,
            projects: const <ProjectRow>[],
            artStyles: const [
              ArtStyleRow(
                id: 'style-1',
                legacyId: 11,
                name: '水墨古风',
                label: 'ink',
                prompt: 'soft ink wash',
                fileUrl: '/api/v1/art-styles/legacy/11/cover',
              ),
            ],
            projectsSummaryLine: null,
            artStylesLine: 'total=1',
            agentMemoryBody: null,
            onLoadProjects: () {},
            onLoadProjectsSummary: () {},
            onLoadArtStyles: () async {},
            onCreateEmptyProject: () {},
            onOpenProjectDetail: (_) {},
            onProbeAgentMemory: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开画风工作台'));
    await tester.pumpAndSettle();

    expect(find.text('画风工作台'), findsOneWidget);
    expect(find.text('Prompt 抽取'), findsOneWidget);
    expect(find.text('抽取 Prompt 到编辑区'), findsOneWidget);
    expect(find.textContaining('#11 水墨古风'), findsOneWidget);
    expect(find.widgetWithText(TextField, '水墨古风'), findsOneWidget);
  });
}
