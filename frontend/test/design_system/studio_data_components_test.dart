import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_breadcrumb.dart';
import 'package:openflow_app/design_system/components/studio_table.dart';
import 'package:openflow_app/design_system/components/studio_timeline.dart';
import 'package:openflow_app/design_system/components/studio_tree.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('StudioTable renders rows and supports sort tap', (tester) async {
    var sorted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioTable<_Row>(
            columns: [
              StudioTableColumn(
                label: 'Name',
                sortable: true,
                cellBuilder: (_, row) => Text(row.name),
              ),
            ],
            rows: const [_Row('Alpha'), _Row('Beta')],
            onSort: (_, ascending) => sorted = true,
          ),
        ),
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    await tester.tap(find.text('Name'));
    await tester.pump();
    expect(sorted, isTrue);
  });

  testWidgets('StudioTable shows localized empty label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioTable<_Row>(
            columns: [
              StudioTableColumn(
                label: 'Name',
                cellBuilder: (_, row) => Text(row.name),
              ),
            ],
            rows: const [],
          ),
        ),
      ),
    );
    expect(find.text('No rows'), findsOneWidget);
  });

  testWidgets('StudioTree expands nested nodes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: StudioTree(
            nodes: [
              StudioTreeNode(
                id: 'root',
                label: 'Root',
                children: [
                  StudioTreeNode(id: 'child', label: 'Child'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Child'), findsNothing);
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsOneWidget);
  });

  testWidgets('StudioTimeline renders entries', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: StudioTimeline(
            entries: [
              StudioTimelineEntry(
                timeLabel: '10:00',
                title: 'Event A',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Event A'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('StudioBreadcrumb navigates segments', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioBreadcrumb(
            segments: [
              StudioBreadcrumbSegment(
                label: 'Home',
                onTap: () => tapped = true,
              ),
              const StudioBreadcrumbSegment(label: 'Projects'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    expect(tapped, isTrue);
    expect(find.text('Projects'), findsOneWidget);
  });
}

class _Row {
  const _Row(this.name);
  final String name;
}
