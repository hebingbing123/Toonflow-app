import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/design_system/tokens.dart';

/// Tests for text overflow protection across the app.
/// Verifies that long text content is properly truncated with ellipsis.
void main() {
  group('Text Overflow Protection', () {
    Widget buildTestApp({required Widget child}) {
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

    testWidgets('Text with maxLines and ellipsis truncates long content', (
      WidgetTester tester,
    ) async {
      // Create extremely long text (1000+ characters)
      final longText = '这是一个非常' * 200 + '长的标题';

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 300,
            child: Text(
              longText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

      // Verify the Text widget exists
      expect(find.byType(Text), findsOneWidget);

      // Verify maxLines and overflow are set correctly
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      // Verify no layout overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('Text with no spaces (continuous English) truncates properly', (
      WidgetTester tester,
    ) async {
      // Create long text without spaces
      final noSpaceText = 'ThisIsAVeryVeryVery' * 50 + 'LongTitle';

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 300,
            child: Text(
              noSpaceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

      // Verify the Text widget exists
      expect(find.byType(Text), findsOneWidget);

      // Verify maxLines and overflow are set correctly
      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      // Verify no layout overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('ListTile title with long text truncates properly', (
      WidgetTester tester,
    ) async {
      final longTitle = '这是一个超级超级超级' * 100 + '长的列表项标题';

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 400,
            child: ListTile(
              title: Text(
                longTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('副标题'),
            ),
          ),
        ),
      );

      // Verify the ListTile renders without errors
      expect(find.byType(ListTile), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify title Text has proper overflow handling
      final titleText = tester.widget<Text>(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text(longTitle),
        ),
      );
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Notification title with 2 lines truncates properly', (
      WidgetTester tester,
    ) async {
      final longNotificationTitle = '通知：' + '这是一个非常重要的' * 80 + '通知标题';

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 350,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    longNotificationTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StudioSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('未读', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify the notification title renders without errors
      expect(find.text(longNotificationTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify title has 2 maxLines
      final titleText = tester.widget<Text>(find.text(longNotificationTitle));
      expect(titleText.maxLines, 2);
      expect(titleText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Dropdown menu item with long text truncates properly', (
      WidgetTester tester,
    ) async {
      final longItemName = '角色名称：' + '非常长的' * 50 + '角色名';

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 300,
            child: DropdownButton<String>(
              value: 'item1',
              isExpanded: true, // Important: allows dropdown to respect width constraints
              items: [
                DropdownMenuItem(
                  value: 'item1',
                  child: Text(
                    longItemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify the dropdown renders without errors
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap to open dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Verify the dropdown item renders without errors
      expect(find.text(longItemName), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Description text with 3 lines truncates properly', (
      WidgetTester tester,
    ) async {
      final longDescription = '订阅计划描述：' + '这是一个详细的' * 100 + '描述文本';

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('标题', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                  longDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify the description renders without errors
      expect(find.text(longDescription), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify description has 3 maxLines
      final descText = tester.widget<Text>(find.text(longDescription));
      expect(descText.maxLines, 3);
      expect(descText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Multiple Text widgets with different maxLines coexist', (
      WidgetTester tester,
    ) async {
      final longTitle = '标题' * 100;
      final longSubtitle = '副标题' * 100;
      final longDescription = '描述' * 100;

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  longTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  longSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  longDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify all texts render without errors
      expect(find.text(longTitle), findsOneWidget);
      expect(find.text(longSubtitle), findsOneWidget);
      expect(find.text(longDescription), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify each has correct maxLines
      final titleWidget = tester.widget<Text>(find.text(longTitle));
      final subtitleWidget = tester.widget<Text>(find.text(longSubtitle));
      final descWidget = tester.widget<Text>(find.text(longDescription));

      expect(titleWidget.maxLines, 1);
      expect(subtitleWidget.maxLines, 2);
      expect(descWidget.maxLines, 3);
    });

    testWidgets('Text overflow in constrained container does not cause RenderFlex overflow', (
      WidgetTester tester,
    ) async {
      final extremelyLongText = 'A' * 10000; // 10000 characters

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 200,
            height: 100,
            child: Row(
              children: [
                const Icon(Icons.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    extremelyLongText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify no RenderFlex overflow errors
      expect(tester.takeException(), isNull);

      // Verify the layout is correct
      expect(find.byType(Icon), findsOneWidget);
      expect(find.text(extremelyLongText), findsOneWidget);
    });

    testWidgets('Text with emoji and special characters truncates properly', (
      WidgetTester tester,
    ) async {
      final textWithEmoji = '🎉🎊🎈' * 200 + '这是一个包含表情符号的超长文本' * 50;

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 300,
            child: Text(
              textWithEmoji,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

      // Verify the text renders without errors
      expect(find.text(textWithEmoji), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify maxLines is set
      final textWidget = tester.widget<Text>(find.text(textWithEmoji));
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Text in Card with long content does not overflow', (
      WidgetTester tester,
    ) async {
      final longCardContent = '卡片内容：' + '这是一段很长的' * 80 + '卡片文本';

      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            width: 350,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '卡片标题',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      longCardContent,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify the card renders without errors
      expect(find.byType(Card), findsOneWidget);
      expect(find.text(longCardContent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
