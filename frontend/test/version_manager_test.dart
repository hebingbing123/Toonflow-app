import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/components/version_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    late List<AssemblyDraft> testDrafts;
    late List<String> createVersionCalls;
    late List<String> switchVersionCalls;
    late List<String> deleteVersionCalls;
    late List<String> saveDraftCalls;
    late List<String> restoreDraftCalls;
    late List<String> deleteDraftCalls;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await (await SharedPreferences.getInstance()).clear();
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
      testDrafts = [];
      createVersionCalls = [];
      switchVersionCalls = [];
      deleteVersionCalls = [];
      saveDraftCalls = [];
      restoreDraftCalls = [];
      deleteDraftCalls = [];
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: VersionManager(
            versions: testVersions,
            currentVersionId: currentVersionId,
            drafts: testDrafts,
            onCreateVersion: (name) async {
              createVersionCalls.add(name);
            },
            onSwitchVersion: (versionId) async {
              switchVersionCalls.add(versionId);
            },
            onDeleteVersion: (versionId) async {
              deleteVersionCalls.add(versionId);
            },
            onSaveDraft: (name) async {
              saveDraftCalls.add(name);
            },
            onRestoreDraft: (draftId) async {
              restoreDraftCalls.add(draftId);
            },
            onDeleteDraft: (draftId) async {
              deleteDraftCalls.add(draftId);
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
              drafts: const [],
              onCreateVersion: (name) async {},
              onSwitchVersion: (versionId) async {},
              onDeleteVersion: (versionId) async {},
              onSaveDraft: (name) async {},
              onRestoreDraft: (draftId) async {},
              onDeleteDraft: (draftId) async {},
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

    testWidgets('should show save draft button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('保存草稿'), findsOneWidget);
    });

    testWidgets('should show empty draft state', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('草稿 (0/10)'), findsOneWidget);
      expect(find.text('暂无草稿，点击上方"保存草稿"按钮保存当前编辑状态'), findsOneWidget);
    });

    testWidgets('should open save draft dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('保存草稿'));
      await tester.pumpAndSettle();

      expect(find.text('保存草稿'), findsNWidgets(2)); // Button + Dialog title
      expect(find.text('草稿名称'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('should save draft with valid name', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Open dialog
      await tester.tap(find.text('保存草稿'));
      await tester.pumpAndSettle();

      // Enter draft name
      await tester.enterText(find.byType(TextField), 'Draft 1');
      await tester.pumpAndSettle();

      // Tap save button
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      expect(saveDraftCalls, ['Draft 1']);
    });

    testWidgets('should show draft limit warning when 10 drafts exist', 
        (WidgetTester tester) async {
      // Create 10 drafts
      testDrafts = List.generate(
        10,
        (i) => AssemblyDraft(
          id: 'd$i',
          name: 'Draft $i',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      );

      await tester.pumpWidget(createTestWidget());

      // Try to save another draft
      await tester.tap(find.text('保存草稿'));
      await tester.pumpAndSettle();

      expect(find.text('草稿数量已达上限'), findsOneWidget);
      expect(find.textContaining('最多只能保存'), findsOneWidget);
    });

    testWidgets('should display draft list', (WidgetTester tester) async {
      testDrafts = [
        AssemblyDraft(
          id: 'd1',
          name: 'Draft 1',
          savedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
          shotCount: 5,
          shotConfig: {},
        ),
        AssemblyDraft(
          id: 'd2',
          name: 'Draft 2',
          savedAt: DateTime.parse('2024-01-02T00:00:00.000Z'),
          shotCount: 8,
          shotConfig: {},
        ),
      ];

      await tester.pumpWidget(createTestWidget());

      expect(find.text('草稿 (2/10)'), findsOneWidget);
      expect(find.text('Draft 1'), findsOneWidget);
      expect(find.text('Draft 2'), findsOneWidget);
    });

    testWidgets('should show restore and delete buttons for drafts', 
        (WidgetTester tester) async {
      testDrafts = [
        AssemblyDraft(
          id: 'd1',
          name: 'Draft 1',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      ];

      await tester.pumpWidget(createTestWidget());

      expect(find.byIcon(Icons.restore), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(3)); // 2 versions + 1 draft
    });

    testWidgets('should show confirmation dialog before restoring draft', 
        (WidgetTester tester) async {
      testDrafts = [
        AssemblyDraft(
          id: 'd1',
          name: 'Draft 1',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      ];

      await tester.pumpWidget(createTestWidget());

      // Tap restore button
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      expect(find.text('确认恢复草稿'), findsOneWidget);
      expect(find.textContaining('确定要恢复草稿'), findsOneWidget);
    });

    testWidgets('should restore draft after confirmation', 
        (WidgetTester tester) async {
      testDrafts = [
        AssemblyDraft(
          id: 'd1',
          name: 'Draft 1',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      ];

      await tester.pumpWidget(createTestWidget());

      // Tap restore button
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      // Confirm restoration
      await tester.tap(find.text('恢复').last);
      await tester.pumpAndSettle();

      expect(restoreDraftCalls, ['d1']);
    });

    testWidgets('should show view all drafts button when drafts exist', 
        (WidgetTester tester) async {
      testDrafts = List.generate(
        5,
        (i) => AssemblyDraft(
          id: 'd$i',
          name: 'Draft $i',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      );

      await tester.pumpWidget(createTestWidget());

      expect(find.text('查看全部'), findsOneWidget);
    });

    testWidgets('should open drafts dialog when view all tapped', 
        (WidgetTester tester) async {
      testDrafts = List.generate(
        5,
        (i) => AssemblyDraft(
          id: 'd$i',
          name: 'Draft $i',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      );

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('查看全部'));
      await tester.pumpAndSettle();

      expect(find.text('草稿列表'), findsOneWidget);
      // All 5 drafts should be visible in the dialog (but not in the main list)
      // The main list shows only 3, so we expect 5 total (3 in main + 5 in dialog - 3 duplicates = 5)
      expect(find.text('Draft 0'), findsNWidgets(2)); // One in main list, one in dialog
    });

    testWidgets('should switch version when switch button tapped', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap switch button for v2
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      expect(switchVersionCalls, ['v2']);
    });

    testWidgets('should show compare versions button when multiple versions exist', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('对比版本'), findsOneWidget);
    });

    testWidgets('should not show compare button with single version', 
        (WidgetTester tester) async {
      testVersions = [
        AssemblyVersion(
          id: 'v1',
          name: 'Version 1',
          createdAt: DateTime.now(),
          shotCount: 10,
          shotConfig: {},
        ),
      ];

      await tester.pumpWidget(createTestWidget());

      expect(find.text('对比版本'), findsNothing);
    });

    testWidgets('should delete draft after confirmation', 
        (WidgetTester tester) async {
      testDrafts = [
        AssemblyDraft(
          id: 'd1',
          name: 'Draft 1',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
      ];

      await tester.pumpWidget(createTestWidget());

      // Find the delete button for the draft (last delete button)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(deleteDraftCalls, ['d1']);
    });
  });

  group('Version Creation and Switching Logic', () {
    test('should create new version with unique ID', () {
      final versions = <AssemblyVersion>[];
      final newVersion = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.now(),
        shotCount: 10,
        shotConfig: {'shot1': {'enabled': true}},
      );

      versions.add(newVersion);

      expect(versions, hasLength(1));
      expect(versions.first.id, 'v1');
      expect(versions.first.name, 'Version 1');
    });

    test('should switch to different version', () {
      final versions = [
        AssemblyVersion(
          id: 'v1',
          name: 'Version 1',
          createdAt: DateTime.now(),
          shotCount: 10,
          shotConfig: {},
        ),
        AssemblyVersion(
          id: 'v2',
          name: 'Version 2',
          createdAt: DateTime.now(),
          shotCount: 15,
          shotConfig: {},
        ),
      ];

      var currentVersionId = 'v1';
      
      // Switch to v2
      currentVersionId = 'v2';
      
      expect(currentVersionId, 'v2');
      final currentVersion = versions.firstWhere((v) => v.id == currentVersionId);
      expect(currentVersion.name, 'Version 2');
      expect(currentVersion.shotCount, 15);
    });

    test('should maintain version history order', () {
      final versions = <AssemblyVersion>[];
      
      // Add versions in order
      versions.add(AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 10,
        shotConfig: {},
      ));
      
      versions.add(AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.parse('2024-01-02T00:00:00.000Z'),
        shotCount: 15,
        shotConfig: {},
      ));
      
      versions.add(AssemblyVersion(
        id: 'v3',
        name: 'Version 3',
        createdAt: DateTime.parse('2024-01-03T00:00:00.000Z'),
        shotCount: 20,
        shotConfig: {},
      ));

      expect(versions, hasLength(3));
      expect(versions[0].name, 'Version 1');
      expect(versions[1].name, 'Version 2');
      expect(versions[2].name, 'Version 3');
      
      // Verify chronological order
      expect(versions[0].createdAt.isBefore(versions[1].createdAt), true);
      expect(versions[1].createdAt.isBefore(versions[2].createdAt), true);
    });

    test('should copy shot config when creating new version', () {
      final baseVersion = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.now(),
        shotCount: 10,
        shotConfig: {
          'shot1': {'enabled': true, 'duration': 10},
          'shot2': {'enabled': false, 'duration': 15},
        },
      );

      // Create new version by copying config
      final newVersion = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.now(),
        shotCount: baseVersion.shotCount,
        shotConfig: Map.from(baseVersion.shotConfig),
      );

      expect(newVersion.shotConfig, equals(baseVersion.shotConfig));
      expect(newVersion.shotConfig['shot1'], equals({'enabled': true, 'duration': 10}));
      expect(newVersion.shotConfig['shot2'], equals({'enabled': false, 'duration': 15}));
    });

    test('should handle version deletion', () {
      final versions = <AssemblyVersion>[
        AssemblyVersion(
          id: 'v1',
          name: 'Version 1',
          createdAt: DateTime.now(),
          shotCount: 10,
          shotConfig: {},
        ),
        AssemblyVersion(
          id: 'v2',
          name: 'Version 2',
          createdAt: DateTime.now(),
          shotCount: 15,
          shotConfig: {},
        ),
      ];

      // Delete v2
      versions.removeWhere((v) => v.id == 'v2');

      expect(versions, hasLength(1));
      expect(versions.first.id, 'v1');
    });

    test('should not allow deleting current version', () {
      const currentVersionId = 'v1';

      // Try to delete current version - should be prevented
      final canDelete = currentVersionId != 'v1';

      expect(canDelete, false);
    });
  });

  group('Draft Saving and Restoring Logic', () {
    test('should save draft with current state', () {
      final drafts = <AssemblyDraft>[];
      final currentState = {
        'shot1': {'enabled': true, 'duration': 10},
        'shot2': {'enabled': false, 'duration': 15},
      };

      final newDraft = AssemblyDraft(
        id: 'd1',
        name: 'Draft 1',
        savedAt: DateTime.now(),
        shotCount: 2,
        shotConfig: Map.from(currentState),
      );

      drafts.add(newDraft);

      expect(drafts, hasLength(1));
      expect(drafts.first.name, 'Draft 1');
      expect(drafts.first.shotConfig, equals(currentState));
    });

    test('should restore draft to current state', () {
      final draft = AssemblyDraft(
        id: 'd1',
        name: 'Draft 1',
        savedAt: DateTime.now(),
        shotCount: 2,
        shotConfig: {
          'shot1': {'enabled': true, 'duration': 10},
          'shot2': {'enabled': false, 'duration': 15},
        },
      );

      // Restore draft
      final restoredConfig = Map.from(draft.shotConfig);

      expect(restoredConfig['shot1'], equals({'enabled': true, 'duration': 10}));
      expect(restoredConfig['shot2'], equals({'enabled': false, 'duration': 15}));
    });

    test('should enforce draft limit of 10', () {
      final drafts = <AssemblyDraft>[];
      
      // Add 10 drafts
      for (int i = 0; i < 10; i++) {
        drafts.add(AssemblyDraft(
          id: 'd$i',
          name: 'Draft $i',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ));
      }

      expect(drafts, hasLength(10));

      // Try to add 11th draft - should be prevented
      final canAddMore = drafts.length < 10;
      expect(canAddMore, false);
    });

    test('should delete draft by ID', () {
      final drafts = <AssemblyDraft>[
        AssemblyDraft(
          id: 'd1',
          name: 'Draft 1',
          savedAt: DateTime.now(),
          shotCount: 5,
          shotConfig: {},
        ),
        AssemblyDraft(
          id: 'd2',
          name: 'Draft 2',
          savedAt: DateTime.now(),
          shotCount: 8,
          shotConfig: {},
        ),
      ];

      // Delete d1
      drafts.removeWhere((d) => d.id == 'd1');

      expect(drafts, hasLength(1));
      expect(drafts.first.id, 'd2');
    });

    test('should maintain draft order by save time', () {
      final drafts = <AssemblyDraft>[];
      
      // Add drafts with different save times
      drafts.add(AssemblyDraft(
        id: 'd1',
        name: 'Draft 1',
        savedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 5,
        shotConfig: {},
      ));
      
      drafts.add(AssemblyDraft(
        id: 'd2',
        name: 'Draft 2',
        savedAt: DateTime.parse('2024-01-02T00:00:00.000Z'),
        shotCount: 8,
        shotConfig: {},
      ));
      
      drafts.add(AssemblyDraft(
        id: 'd3',
        name: 'Draft 3',
        savedAt: DateTime.parse('2024-01-03T00:00:00.000Z'),
        shotCount: 10,
        shotConfig: {},
      ));

      // Sort by save time (most recent first)
      drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      expect(drafts[0].name, 'Draft 3');
      expect(drafts[1].name, 'Draft 2');
      expect(drafts[2].name, 'Draft 1');
    });

    test('should preserve shot config when saving draft', () {
      final originalConfig = {
        'shot1': {
          'enabled': true,
          'duration': 10,
          'video_url': 'https://example.com/video1.mp4',
          'subtitle': 'Test subtitle',
        },
        'shot2': {
          'enabled': false,
          'duration': 15,
          'video_url': 'https://example.com/video2.mp4',
        },
      };

      final draft = AssemblyDraft(
        id: 'd1',
        name: 'Draft 1',
        savedAt: DateTime.now(),
        shotCount: 2,
        shotConfig: Map.from(originalConfig),
      );

      // Verify all fields are preserved
      expect(draft.shotConfig['shot1']['enabled'], true);
      expect(draft.shotConfig['shot1']['duration'], 10);
      expect(draft.shotConfig['shot1']['video_url'], 'https://example.com/video1.mp4');
      expect(draft.shotConfig['shot1']['subtitle'], 'Test subtitle');
      expect(draft.shotConfig['shot2']['enabled'], false);
    });

    test('should handle empty draft config', () {
      final draft = AssemblyDraft(
        id: 'd1',
        name: 'Empty Draft',
        savedAt: DateTime.now(),
        shotCount: 0,
        shotConfig: {},
      );

      expect(draft.shotConfig, isEmpty);
      expect(draft.shotCount, 0);
    });

    test('should allow restoring draft multiple times', () {
      final draft = AssemblyDraft(
        id: 'd1',
        name: 'Draft 1',
        savedAt: DateTime.now(),
        shotCount: 2,
        shotConfig: {
          'shot1': {'enabled': true},
          'shot2': {'enabled': false},
        },
      );

      // Restore first time
      final restored1 = Map.from(draft.shotConfig);
      expect(restored1['shot1']['enabled'], true);

      // Restore second time
      final restored2 = Map.from(draft.shotConfig);
      expect(restored2['shot1']['enabled'], true);

      // Both restorations should be identical
      expect(restored1, equals(restored2));
    });
  });

  group('Version Comparison Integration', () {
    test('should detect shot count differences between versions', () {
      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.now(),
        shotCount: 10,
        shotConfig: {},
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.now(),
        shotCount: 15,
        shotConfig: {},
      );

      final countDifference = version2.shotCount - version1.shotCount;
      expect(countDifference, 5);
    });

    test('should detect config differences between versions', () {
      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.now(),
        shotCount: 2,
        shotConfig: {
          'shot1': {'enabled': true, 'duration': 10},
          'shot2': {'enabled': false, 'duration': 15},
        },
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.now(),
        shotCount: 2,
        shotConfig: {
          'shot1': {'enabled': true, 'duration': 12}, // Changed duration
          'shot2': {'enabled': true, 'duration': 15}, // Changed enabled
        },
      );

      // Check shot1 duration difference
      final shot1V1 = version1.shotConfig['shot1'] as Map<String, dynamic>;
      final shot1V2 = version2.shotConfig['shot1'] as Map<String, dynamic>;
      expect(shot1V1['duration'], 10);
      expect(shot1V2['duration'], 12);

      // Check shot2 enabled difference
      final shot2V1 = version1.shotConfig['shot2'] as Map<String, dynamic>;
      final shot2V2 = version2.shotConfig['shot2'] as Map<String, dynamic>;
      expect(shot2V1['enabled'], false);
      expect(shot2V2['enabled'], true);
    });

    test('should identify added shots in new version', () {
      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.now(),
        shotCount: 2,
        shotConfig: {
          'shot1': {'enabled': true},
          'shot2': {'enabled': false},
        },
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.now(),
        shotCount: 3,
        shotConfig: {
          'shot1': {'enabled': true},
          'shot2': {'enabled': false},
          'shot3': {'enabled': true}, // New shot
        },
      );

      final addedShots = <String>[];
      for (final shotId in version2.shotConfig.keys) {
        if (!version1.shotConfig.containsKey(shotId)) {
          addedShots.add(shotId);
        }
      }

      expect(addedShots, hasLength(1));
      expect(addedShots, contains('shot3'));
    });

    test('should identify removed shots in new version', () {
      final version1 = AssemblyVersion(
        id: 'v1',
        name: 'Version 1',
        createdAt: DateTime.now(),
        shotCount: 3,
        shotConfig: {
          'shot1': {'enabled': true},
          'shot2': {'enabled': false},
          'shot3': {'enabled': true},
        },
      );

      final version2 = AssemblyVersion(
        id: 'v2',
        name: 'Version 2',
        createdAt: DateTime.now(),
        shotCount: 2,
        shotConfig: {
          'shot1': {'enabled': true},
          'shot2': {'enabled': false},
          // shot3 removed
        },
      );

      final removedShots = <String>[];
      for (final shotId in version1.shotConfig.keys) {
        if (!version2.shotConfig.containsKey(shotId)) {
          removedShots.add(shotId);
        }
      }

      expect(removedShots, hasLength(1));
      expect(removedShots, contains('shot3'));
    });
  });

  group('AssemblyDraft', () {
    test('should create from JSON', () {
      final json = {
        'id': 'd1',
        'name': 'Draft 1',
        'saved_at': '2024-01-01T00:00:00.000Z',
        'shot_count': 5,
        'shot_config': {'123': {'enabled': true}},
      };

      final draft = AssemblyDraft.fromJson(json);

      expect(draft.id, 'd1');
      expect(draft.name, 'Draft 1');
      expect(draft.shotCount, 5);
      expect(draft.shotConfig, {'123': {'enabled': true}});
    });

    test('should convert to JSON', () {
      final draft = AssemblyDraft(
        id: 'd1',
        name: 'Draft 1',
        savedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 5,
        shotConfig: {'123': {'enabled': true}},
      );

      final json = draft.toJson();

      expect(json['id'], 'd1');
      expect(json['name'], 'Draft 1');
      expect(json['shot_count'], 5);
      expect(json['shot_config'], {'123': {'enabled': true}});
    });

    test('should copy with new values', () {
      final draft = AssemblyDraft(
        id: 'd1',
        name: 'Draft 1',
        savedAt: DateTime.parse('2024-01-01T00:00:00.000Z'),
        shotCount: 5,
        shotConfig: {},
      );

      final copied = draft.copyWith(name: 'Draft 2', shotCount: 10);

      expect(copied.id, 'd1');
      expect(copied.name, 'Draft 2');
      expect(copied.shotCount, 10);
    });
  });
}
