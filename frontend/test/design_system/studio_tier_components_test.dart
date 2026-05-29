import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_drawer.dart';
import 'package:openflow_app/design_system/components/studio_grid.dart';
import 'package:openflow_app/design_system/components/studio_list.dart';
import 'package:openflow_app/design_system/components/studio_stepper.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  testWidgets('StudioStepper shows active step', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: StudioStepper(
            currentIndex: 1,
            steps: [
              StudioStepItem(label: 'Draft'),
              StudioStepItem(label: 'Review'),
              StudioStepItem(label: 'Ship'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('StudioList shows skeleton when loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: StudioList(
            loading: true,
            itemCount: 0,
            itemBuilder: _noop,
          ),
        ),
      ),
    );
    expect(find.byType(StudioListSkeleton), findsOneWidget);
  });

  testWidgets('StudioGrid shows skeleton when loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: SizedBox(
            width: 800,
            child: StudioGrid(
              loading: true,
              itemCount: 0,
              itemBuilder: _noop,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(StudioGridSkeleton), findsOneWidget);
  });

  testWidgets('showStudioDrawer presents panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () {
                  showStudioDrawer<void>(
                    context: context,
                    builder: (_) => const Text('Drawer body'),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Drawer body'), findsOneWidget);
  });
}

Widget _noop(BuildContext context, int index) => const SizedBox.shrink();
