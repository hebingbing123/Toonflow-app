import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_card.dart';
import 'package:openflow_app/design_system/components/studio_pick_grid.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

void main() {
  test('StudioStep fromSlug defaults to script', () {
    expect(StudioStep.fromSlug(null), StudioStep.script);
    expect(StudioStep.fromSlug('deliver'), StudioStep.deliver);
  });

  testWidgets('StudioPickGrid hides when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: Scaffold(
          body: StudioPickGrid(
            candidateUrls: const <String>[],
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(StudioPickGrid), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('StudioCard renders child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: StudioCard(child: Text('hello')),
        ),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
  });
}
