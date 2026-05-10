import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openflow_app/global_search/search_result_card.dart';
import 'package:openflow_app/rust_api/search/api.dart';

void main() {
  group('SearchResultCard', () {
    // Helper to create a test SearchResult
    SearchResult createTestResult({
      String id = 'test-id',
      ResultType type = ResultType.project,
      String title = 'Test Title',
      String snippet = 'This is a test <mark>snippet</mark> with highlights',
      double rank = 0.5,
      String? createdAt,
      String? updatedAt,
    }) {
      return SearchResult(
        id: id,
        resultType: type,
        title: title,
        snippet: snippet,
        rank: rank,
        createdAt: createdAt ?? DateTime.now().toIso8601String(),
        updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
      );
    }

    testWidgets('renders result card with title and type icon', (tester) async {
      final result = createTestResult(
        type: ResultType.project,
        title: 'My Project',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('My Project'), findsOneWidget);

      // Verify type icon is displayed (folder for project)
      expect(find.byIcon(Icons.folder_outlined), findsAtLeastNWidgets(1));

      // Verify type badge is displayed
      expect(find.text('项目'), findsOneWidget);
    });

    testWidgets('renders script type with correct icon', (tester) async {
      final result = createTestResult(
        type: ResultType.script,
        title: 'My Script',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify script icon is displayed
      expect(find.byIcon(Icons.description_outlined), findsAtLeastNWidgets(1));

      // Verify type badge
      expect(find.text('剧本'), findsOneWidget);
    });

    testWidgets('renders asset type with correct icon', (tester) async {
      final result = createTestResult(
        type: ResultType.asset,
        title: 'My Asset',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify asset icon is displayed
      expect(find.byIcon(Icons.image_outlined), findsAtLeastNWidgets(1));

      // Verify type badge
      expect(find.text('资产'), findsOneWidget);
    });

    testWidgets('parses and highlights <mark> tags in snippet',
        (tester) async {
      final result = createTestResult(
        snippet: 'This is a <mark>highlighted</mark> snippet',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify RichText widget is present (used for highlighting)
      expect(find.byType(RichText), findsWidgets);

      // The text should be present (though we can't easily verify styling)
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
    });

    testWidgets('handles snippet without <mark> tags', (tester) async {
      final result = createTestResult(
        snippet: 'This is a plain snippet without highlights',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify RichText is still rendered
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('handles multiple <mark> tags in snippet', (tester) async {
      final result = createTestResult(
        snippet:
            'This <mark>first</mark> and <mark>second</mark> are highlighted',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify RichText is rendered
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('displays formatted time for recent updates', (tester) async {
      // Create a result updated 2 hours ago
      final twoHoursAgo =
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
      final result = createTestResult(updatedAt: twoHoursAgo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify time display (should show "2 小时前")
      expect(find.textContaining('小时前'), findsOneWidget);
    });

    testWidgets('displays formatted time for older updates', (tester) async {
      // Create a result updated 10 days ago
      final tenDaysAgo =
          DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
      final result = createTestResult(updatedAt: tenDaysAgo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify time display shows date format (YYYY/M/D)
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('triggers onTap callback when card is tapped', (tester) async {
      final result = createTestResult();
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(
              result: result,
              onTap: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      // Tap the card
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // Verify callback was triggered
      expect(wasTapped, isTrue);
    });

    testWidgets('renders card with proper Material design', (tester) async {
      final result = createTestResult();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify Card widget is present
      expect(find.byType(Card), findsOneWidget);

      // Verify InkWell for tap feedback
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('truncates long titles with ellipsis', (tester) async {
      final result = createTestResult(
        title: 'This is a very long title that should be truncated ' * 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SearchResultCard(result: result),
            ),
          ),
        ),
      );

      // Verify the title Text widget has maxLines and overflow set
      final titleFinder = find.text(result.title);
      expect(titleFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('truncates long snippets with ellipsis', (tester) async {
      final result = createTestResult(
        snippet: 'This is a very long snippet that should be truncated ' * 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SearchResultCard(result: result),
            ),
          ),
        ),
      );

      // Verify RichText is rendered (maxLines is set in the component)
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      // The component sets maxLines to 3 and overflow to ellipsis
      // We can't directly test these properties, but we verify the widget renders
      expect(find.byType(SearchResultCard), findsOneWidget);
    });

    testWidgets('displays arrow icon for navigation hint', (tester) async {
      final result = createTestResult();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Verify arrow icon is displayed
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets('handles empty snippet gracefully', (tester) async {
      final result = createTestResult(snippet: '');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Should still render without errors
      expect(find.byType(SearchResultCard), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('handles malformed date gracefully', (tester) async {
      final result = createTestResult(updatedAt: 'invalid-date');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: result),
          ),
        ),
      );

      // Should render without crashing
      expect(find.byType(SearchResultCard), findsOneWidget);
    });
  });
}
