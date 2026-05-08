import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/components/version_manager.dart';

void main() {
  group('AssemblyVersion', () {
    test('should create from JSON', () {
      final json = {
        'id': 'v1',
        'name': 'Version 1',
        'created_at': '2024-01-01T00:00:00.000Z',
        'shot_count': 10,
        'shot_config': {'123': {'enabled': true}},
      };

      final version = AssemblyVersion.fromJson(json);

      expect(version.id, 'v1');
      expect(version.name, 'Version 1');
      expect(version.shotCount, 10);
      expect(version.shotConfig, {'123': {'enabled': true}});
    });

    test('should convert to JSON', () {
      final version = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 10,
        shotConfig: {'123': {'enabled': true}},
      );

      final json = version.toJson();

      expect(json['id'], 'v1');
      expect(json['name'], 'Version 1');
      expect(json['shot_count'], 10);
      expect(json['shot_config'], {'123': {'enabled': true}});
    });

    test('should copy with new values', () {
      final version = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 10,
        shotConfig: {},
      );

      final copied = version.copyWith(name: 'Version 2', shotCount: 20);

      expect(copied.id, 'v1');
      expect(copied.name, 'Version 2');
      expect(copied.shotCount, 20);
    });
  });

  group('VersionManager Widget', () {
    late List<AssemblyVersion> testVersions;
    late String currentVersionId;
    late List<String> createVersionCalls;
    late List<String> switchVersionCalls;
    late List<String> deleteVersionCalls;

    setUp(() {
      testVersions = [
        AssemblyVersion(
          id: 'v1',
          name: 'Version 1',
          createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
          shotCount: 10,
          shotConfig: {},
        ),
        AssemblyVersion(
          id: 'v2',
          name: 'Version 2',
          createdAt: DateTime.parse('2024-01-02T00:00:00.000Z'),
          shotCount: 15,
          shotConfig: {},
        ),
      ];
      currentVersionId = 'v1';
      createVersionCalls = [];
      switchVersionCalls = [];
      deleteVersionCalls = [];
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: VersionManager(
            versions: testVersions,
            currentVersionId: currentVersionId,
            onCreateVersion: (name) async {
              createVersionCalls.add(name);
            },
            onSwitchVersion: (versionId) async {
              switchVersionCalls.add(versionId);
            },
            onDeleteVersion: (versionId) async {
              deleteVersionCalls.add(versionId);
            },
          ),
        ),
      );
    }

    testWidgets('should display version list', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('版本管理'), findsOneWidget);
      expect(find.text('Version 1'), findsOneWidget);
      expect(find.text('Version 2'), findsOneWidget);
      expect(find.text('所有版本 (2)'), findsOneWidget);
    });

    testWidgets('should highlight current version', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('当前版本：Version 1'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('should show create version button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('创建新版本'), findsOneWidget);
    });

    testWidgets('should open create version dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('创建新版本'));
      await tester.pumpAndSettle();

      expect(find.text('创建新版本'), findsNWidgets(2)); // Button + Dialog title
      expect(find.text('版本名称'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('创建'), findsOneWidget);
    });

    testWidgets('should create version with valid name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Open dialog
      await tester.tap(find.text('创建新版本'));
      await tester.pumpAndSettle();

      // Enter version name
      await tester.enterText(find.byType(TextField), 'Version 3');
      await tester.pumpAndSettle();

      // Tap create button
      await tester.tap(find.text('创建').last);
      await tester.pumpAndSettle();

      expect(createVersionCalls, ['Version 3']);
    });

    testWidgets('should not create version with empty name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Open dialog
      await tester.tap(find.text('创建新版本'));
      await tester.pumpAndSettle();

      // Tap create button without entering name
      await tester.tap(find.text('创建').last);
      await tester.pumpAndSettle();

      expect(createVersionCalls, isEmpty);
    });

    testWidgets('should show switch version button for non-current versions', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should have one switch button (for v2)
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('should show delete buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should have delete buttons for both versions
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('should disable delete button for current version', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find all delete buttons
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(2));

      // The first delete button (for current version) should be disabled
      final firstDeleteButton = tester.widget<IconButton>(
        find.ancestor(
          of: deleteButtons.first,
          matching: find.byType(IconButton),
        ),
      );
      expect(firstDeleteButton.onPressed, isNull);
    });

    testWidgets('should show empty state when no versions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VersionManager(
              versions: const [],
              currentVersionId: '',
              onCreateVersion: (name) async {},
              onSwitchVersion: (versionId) async {},
              onDeleteVersion: (versionId) async {},
            ),
          ),
        ),
      );

      expect(find.text('暂无版本，点击上方按钮创建第一个版本'), findsOneWidget);
    });

    testWidgets('should show confirmation dialog before delete', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find and tap the second delete button (for v2)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('确认删除'), findsOneWidget);
      expect(find.textContaining('确定要删除版本'), findsOneWidget);
    });

    testWidgets('should delete version after confirmation', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find and tap the second delete button (for v2)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(deleteVersionCalls, ['v2']);
    });

    testWidgets('should cancel delete when cancel button tapped', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find and tap the second delete button (for v2)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Cancel deletion
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();

      expect(deleteVersionCalls, isEmpty);
    });
  });
}
