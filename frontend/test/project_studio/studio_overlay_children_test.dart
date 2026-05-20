import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/studio_overlay_children.dart';
import 'package:openflow_app/project_studio/studio_overlay_resolution.dart';

void main() {
  Widget wrapChildren(List<Widget> children) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  testWidgets('buildStudioOverlayChildren renders loading without Expanded', (
    tester,
  ) async {
    final children = buildStudioOverlayChildren(
      resolved: const ResolvedStudioOverlay.loading(),
      loadingChild: const Center(child: Text('loading')),
      storyboardBuilder: (_) => const Text('storyboard'),
      episodeConsoleBuilder: (_, _) => const Text('console'),
      projectStudioBuilder: (_, _) => const Text('studio'),
      reviewPackBuilder: (_, _) => const Text('review-pack'),
    );

    await tester.pumpWidget(wrapChildren(children));

    expect(find.text('loading'), findsOneWidget);
    expect(find.byType(Expanded), findsNothing);
  });

  testWidgets('buildStudioOverlayChildren wraps storyboard in Expanded', (
    tester,
  ) async {
    final children = buildStudioOverlayChildren(
      resolved: const ResolvedStudioOverlay.storyboardStudio(
        projectNumericId: 7,
      ),
      loadingChild: const SizedBox(),
      storyboardBuilder: (projectNumericId) =>
          Text('storyboard-$projectNumericId'),
      episodeConsoleBuilder: (_, _) => const Text('console'),
      projectStudioBuilder: (_, _) => const Text('studio'),
      reviewPackBuilder: (_, _) => const Text('review-pack'),
    );

    await tester.pumpWidget(wrapChildren(children));

    expect(find.byType(Expanded), findsOneWidget);
    expect(find.text('storyboard-7'), findsOneWidget);
  });

  testWidgets('buildStudioOverlayChildren passes console ids through', (
    tester,
  ) async {
    final children = buildStudioOverlayChildren(
      resolved: const ResolvedStudioOverlay.episodeConsole(
        projectNumericId: 7,
        scriptNumericId: 3,
      ),
      loadingChild: const SizedBox(),
      storyboardBuilder: (_) => const Text('storyboard'),
      episodeConsoleBuilder: (projectNumericId, scriptNumericId) =>
          Text('console-$projectNumericId-$scriptNumericId'),
      projectStudioBuilder: (_, _) => const Text('studio'),
      reviewPackBuilder: (_, _) => const Text('review-pack'),
    );

    await tester.pumpWidget(wrapChildren(children));

    expect(find.byType(Expanded), findsOneWidget);
    expect(find.text('console-7-3'), findsOneWidget);
  });

  testWidgets('buildStudioOverlayChildren passes studio ids through', (
    tester,
  ) async {
    final children = buildStudioOverlayChildren(
      resolved: const ResolvedStudioOverlay.projectStudio(
        projectNumericId: 7,
        projectUuid: 'project-7',
      ),
      loadingChild: const SizedBox(),
      storyboardBuilder: (_) => const Text('storyboard'),
      episodeConsoleBuilder: (_, _) => const Text('console'),
      projectStudioBuilder: (projectNumericId, projectUuid) =>
          Text('studio-$projectNumericId-$projectUuid'),
      reviewPackBuilder: (_, _) => const Text('review-pack'),
    );

    await tester.pumpWidget(wrapChildren(children));

    expect(find.byType(Expanded), findsOneWidget);
    expect(find.text('studio-7-project-7'), findsOneWidget);
  });

  testWidgets('buildStudioOverlayChildren passes review pack ids through', (
    tester,
  ) async {
    final children = buildStudioOverlayChildren(
      resolved: const ResolvedStudioOverlay.reviewPack(
        projectNumericId: 7,
        projectUuid: 'project-7',
      ),
      loadingChild: const SizedBox(),
      storyboardBuilder: (_) => const Text('storyboard'),
      episodeConsoleBuilder: (_, _) => const Text('console'),
      projectStudioBuilder: (_, _) => const Text('studio'),
      reviewPackBuilder: (projectNumericId, projectUuid) =>
          Text('review-pack-$projectNumericId-$projectUuid'),
    );

    await tester.pumpWidget(wrapChildren(children));

    expect(find.byType(Expanded), findsOneWidget);
    expect(find.text('review-pack-7-project-7'), findsOneWidget);
  });
}
