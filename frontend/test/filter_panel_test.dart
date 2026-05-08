import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/components/filter_panel.dart';

void main() {
  group('FilterPanel', () {
    late List<FilterState> filterChangedCalls;

    setUp(() {
      filterChangedCalls = [];
    });

    Widget createTestWidget({FilterState? initialFilter}) {
      return MaterialApp(
        home: Scaffold(
          body: FilterPanel(
            onFilterChanged: (filter) {
              filterChangedCalls.add(filter);
            },
            initialFilter: initialFilter,
          ),
        ),
      );
    }

    testWidgets('should display search input field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('搜索字幕或旁白内容...'), findsOneWidget);
    });

    testWidgets('should display status filter dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('状态过滤'), findsOneWidget);
    });

    testWidgets('should display quality filter dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('质量过滤'), findsOneWidget);
    });

    testWidgets('should not show clear button when no filters active', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('清除'), findsNothing);
    });

    testWidgets('should show clear button when filters active', 
        (WidgetTester tester) async {
      final initialFilter = FilterState(
        searchKeyword: 'test',
      );
      await tester.pumpWidget(createTestWidget(initialFilter: initialFilter));

      expect(find.text('清除'), findsOneWidget);
    });

    testWidgets('should trigger filter change with debounce on search input', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test keyword');
      
      // Wait for debounce (300ms)
      await tester.pump(const Duration(milliseconds: 100));
      expect(filterChangedCalls, isEmpty); // Should not trigger yet
      
      await tester.pump(const Duration(milliseconds: 250));
      expect(filterChangedCalls.length, 1);
      expect(filterChangedCalls.first.searchKeyword, 'test keyword');
    });

    testWidgets('should show search options when search keyword entered', 
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Enter search text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('搜索范围：'), findsOneWidget);
      expect(find.text('字幕'), findsOneWidget);
      expect(find.text('旁白'), findsOneWidget);
    });

    testWidgets('should clear search when clear icon tapped', 
        (WidgetTester tester) async {
      final initialFilter = FilterState(searchKeyword: 'test');
      await tester.pumpWidget(createTestWidget(initialFilter: initialFilter));

      // Find and tap the clear icon
      final clearIcon = find.byIcon(Icons.clear);
      expect(clearIcon, findsOneWidget);
      
      await tester.tap(clearIcon);
      await tester.pump(const Duration(milliseconds: 350));

      expect(filterChangedCalls.isNotEmpty, true);
      expect(filterChangedCalls.last.searchKeyword, '');
    });

    testWidgets('should display active filter tags', 
        (WidgetTester tester) async {
      final initialFilter = FilterState(
        searchKeyword: 'test',
        statusFilters: {ShotStatusFilter.enabled},
      );
      await tester.pumpWidget(createTestWidget(initialFilter: initialFilter));

      expect(find.byType(Chip), findsNWidgets(2)); // Search + status filter
      expect(find.text('搜索: test'), findsOneWidget);
      expect(find.text('已启用'), findsOneWidget);
    });

    testWidgets('should remove filter tag when delete icon tapped', 
        (WidgetTester tester) async {
      final initialFilter = FilterState(
        searchKeyword: 'test',
      );
      await tester.pumpWidget(createTestWidget(initialFilter: initialFilter));

      // Find the chip with delete icon
      final chip = find.byType(Chip);
      expect(chip, findsOneWidget);

      // Tap the delete icon
      await tester.tap(find.descendant(
        of: chip,
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(filterChangedCalls.isNotEmpty, true);
      expect(filterChangedCalls.last.searchKeyword, '');
    });

    testWidgets('should clear all filters when clear button tapped', 
        (WidgetTester tester) async {
      final initialFilter = FilterState(
        searchKeyword: 'test',
        statusFilters: {ShotStatusFilter.enabled},
        qualityFilters: {QualityFilter.hasBadExample},
      );
      await tester.pumpWidget(createTestWidget(initialFilter: initialFilter));

      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();

      expect(filterChangedCalls.isNotEmpty, true);
      final lastFilter = filterChangedCalls.last;
      expect(lastFilter.searchKeyword, '');
      expect(lastFilter.statusFilters, isEmpty);
      expect(lastFilter.qualityFilters, isEmpty);
    });

    testWidgets('should toggle search in subtitles option', 
        (WidgetTester tester) async {
      final initialFilter = FilterState(searchKeyword: 'test');
      await tester.pumpWidget(createTestWidget(initialFilter: initialFilter));

      // Find the subtitle filter chip
      final subtitleChip = find.widgetWithText(FilterChip, '字幕');
      expect(subtitleChip, findsOneWidget);

      await tester.tap(subtitleChip);
      await tester.pumpAndSettle();

      expect(filterChangedCalls.isNotEmpty, true);
      expect(filterChangedCalls.last.searchInSubtitles, false);
    });

    testWidgets('should toggle search in voiceover option', 
        (WidgetTester tester) async {
      final initialFilter = FilterState(searchKeyword: 'test');
      await tester.pumpWidget(createTestWidget(initialFilter: initialFilter));

      // Find the voiceover filter chip
      final voiceoverChip = find.widgetWithText(FilterChip, '旁白');
      expect(voiceoverChip, findsOneWidget);

      await tester.tap(voiceoverChip);
      await tester.pumpAndSettle();

      expect(filterChangedCalls.isNotEmpty, true);
      expect(filterChangedCalls.last.searchInVoiceover, false);
    });
  });

  group('FilterState', () {
    test('should create empty filter state', () {
      final filter = FilterState.empty();

      expect(filter.searchKeyword, '');
      expect(filter.statusFilters, isEmpty);
      expect(filter.qualityFilters, isEmpty);
      expect(filter.searchInSubtitles, true);
      expect(filter.searchInVoiceover, true);
      expect(filter.isEmpty, true);
      expect(filter.isNotEmpty, false);
    });

    test('should create filter state with values', () {
      final filter = FilterState(
        searchKeyword: 'test',
        statusFilters: {ShotStatusFilter.enabled},
        qualityFilters: {QualityFilter.hasBadExample},
        searchInSubtitles: false,
        searchInVoiceover: true,
      );

      expect(filter.searchKeyword, 'test');
      expect(filter.statusFilters, {ShotStatusFilter.enabled});
      expect(filter.qualityFilters, {QualityFilter.hasBadExample});
      expect(filter.searchInSubtitles, false);
      expect(filter.searchInVoiceover, true);
      expect(filter.isEmpty, false);
      expect(filter.isNotEmpty, true);
    });

    test('should copy with new values', () {
      final original = FilterState(
        searchKeyword: 'test',
        statusFilters: {ShotStatusFilter.enabled},
      );

      final copied = original.copyWith(
        searchKeyword: 'new test',
        qualityFilters: {QualityFilter.hasBadExample},
      );

      expect(copied.searchKeyword, 'new test');
      expect(copied.statusFilters, {ShotStatusFilter.enabled});
      expect(copied.qualityFilters, {QualityFilter.hasBadExample});
    });

    test('should detect empty state correctly', () {
      final emptyFilter = FilterState.empty();
      expect(emptyFilter.isEmpty, true);

      final filterWithSearch = FilterState(searchKeyword: 'test');
      expect(filterWithSearch.isEmpty, false);

      final filterWithStatus = FilterState(
        statusFilters: {ShotStatusFilter.enabled},
      );
      expect(filterWithStatus.isEmpty, false);

      final filterWithQuality = FilterState(
        qualityFilters: {QualityFilter.hasBadExample},
      );
      expect(filterWithQuality.isEmpty, false);
    });
  });

  group('ShotStatusFilter', () {
    test('should have correct labels', () {
      expect(ShotStatusFilter.enabled.label, '已启用');
      expect(ShotStatusFilter.disabled.label, '已禁用');
      expect(ShotStatusFilter.hasVideo.label, '有视频');
      expect(ShotStatusFilter.noVideo.label, '无视频');
      expect(ShotStatusFilter.hasDuration.label, '有时长');
      expect(ShotStatusFilter.noDuration.label, '无时长');
      expect(ShotStatusFilter.hasSubtitle.label, '有字幕');
      expect(ShotStatusFilter.noSubtitle.label, '无字幕');
      expect(ShotStatusFilter.hasVoiceover.label, '有配音');
      expect(ShotStatusFilter.noVoiceover.label, '无配音');
      expect(ShotStatusFilter.voiceoverFailed.label, '配音失败');
    });

    test('should have all expected values', () {
      expect(ShotStatusFilter.values.length, 11);
    });
  });

  group('QualityFilter', () {
    test('should have correct labels', () {
      expect(QualityFilter.hasBadExample.label, '有坏例');
      expect(QualityFilter.noBadExample.label, '无坏例');
      expect(QualityFilter.generationStage.label, '生成阶段');
      expect(QualityFilter.postProductionStage.label, '后期阶段');
      expect(QualityFilter.hasDegradation.label, '有退化');
      expect(QualityFilter.noDegradation.label, '无退化');
    });

    test('should have all expected values', () {
      expect(QualityFilter.values.length, 6);
    });
  });

  group('FilterTag', () {
    test('should create filter tag with correct properties', () {
      const tag = FilterTag(
        type: FilterTagType.search,
        label: '搜索: test',
        value: 'test',
      );

      expect(tag.type, FilterTagType.search);
      expect(tag.label, '搜索: test');
      expect(tag.value, 'test');
    });
  });

  group('FilterTagType', () {
    test('should have all expected values', () {
      expect(FilterTagType.values.length, 3);
      expect(FilterTagType.values, [
        FilterTagType.search,
        FilterTagType.status,
        FilterTagType.quality,
      ]);
    });
  });

  group('FilterPreset', () {
    test('should create filter preset with correct properties', () {
      final filter = FilterState(
        searchKeyword: 'test',
        statusFilters: {ShotStatusFilter.enabled},
      );
      final createdAt = DateTime.now();
      final preset = FilterPreset(
        name: 'My Preset',
        filter: filter,
        createdAt: createdAt,
      );

      expect(preset.name, 'My Preset');
      expect(preset.filter, filter);
      expect(preset.createdAt, createdAt);
    });

    test('should generate correct description', () {
      final preset1 = FilterPreset(
        name: 'Test',
        filter: FilterState(searchKeyword: 'test'),
        createdAt: DateTime.now(),
      );
      expect(preset1.description, '搜索: test');

      final preset2 = FilterPreset(
        name: 'Test',
        filter: FilterState(
          statusFilters: {ShotStatusFilter.enabled, ShotStatusFilter.hasVideo},
        ),
        createdAt: DateTime.now(),
      );
      expect(preset2.description, '2个状态');

      final preset3 = FilterPreset(
        name: 'Test',
        filter: FilterState(
          searchKeyword: 'test',
          statusFilters: {ShotStatusFilter.enabled},
          qualityFilters: {QualityFilter.hasBadExample},
        ),
        createdAt: DateTime.now(),
      );
      expect(preset3.description, '搜索: test, 1个状态, 1个质量');

      final preset4 = FilterPreset(
        name: 'Test',
        filter: FilterState.empty(),
        createdAt: DateTime.now(),
      );
      expect(preset4.description, '无过滤条件');
    });

    test('should serialize to JSON correctly', () {
      final filter = FilterState(
        searchKeyword: 'test',
        statusFilters: {ShotStatusFilter.enabled, ShotStatusFilter.hasVideo},
        qualityFilters: {QualityFilter.hasBadExample},
        searchInSubtitles: true,
        searchInVoiceover: false,
      );
      final createdAt = DateTime(2024, 1, 15, 10, 30);
      final preset = FilterPreset(
        name: 'My Preset',
        filter: filter,
        createdAt: createdAt,
      );

      final json = preset.toJson();

      expect(json['name'], 'My Preset');
      expect(json['filter']['searchKeyword'], 'test');
      expect(json['filter']['statusFilters'], hasLength(2));
      expect(json['filter']['statusFilters'], contains('enabled'));
      expect(json['filter']['statusFilters'], contains('hasVideo'));
      expect(json['filter']['qualityFilters'], ['hasBadExample']);
      expect(json['filter']['searchInSubtitles'], true);
      expect(json['filter']['searchInVoiceover'], false);
      expect(json['createdAt'], '2024-01-15T10:30:00.000');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'My Preset',
        'filter': {
          'searchKeyword': 'test',
          'statusFilters': ['enabled', 'hasVideo'],
          'qualityFilters': ['hasBadExample'],
          'searchInSubtitles': true,
          'searchInVoiceover': false,
        },
        'createdAt': '2024-01-15T10:30:00.000',
      };

      final preset = FilterPreset.fromJson(json);

      expect(preset.name, 'My Preset');
      expect(preset.filter.searchKeyword, 'test');
      expect(preset.filter.statusFilters, hasLength(2));
      expect(preset.filter.statusFilters, contains(ShotStatusFilter.enabled));
      expect(preset.filter.statusFilters, contains(ShotStatusFilter.hasVideo));
      expect(preset.filter.qualityFilters, {QualityFilter.hasBadExample});
      expect(preset.filter.searchInSubtitles, true);
      expect(preset.filter.searchInVoiceover, false);
      expect(preset.createdAt, DateTime(2024, 1, 15, 10, 30));
    });

    test('should handle empty filter in JSON serialization', () {
      final preset = FilterPreset(
        name: 'Empty Preset',
        filter: FilterState.empty(),
        createdAt: DateTime(2024, 1, 15),
      );

      final json = preset.toJson();
      final deserialized = FilterPreset.fromJson(json);

      expect(deserialized.name, 'Empty Preset');
      expect(deserialized.filter.isEmpty, true);
    });
  });

  group('FilterPanel with Presets', () {
    late List<FilterState> filterChangedCalls;
    late List<List<FilterPreset>> presetsChangedCalls;

    setUp(() {
      filterChangedCalls = [];
      presetsChangedCalls = [];
    });

    Widget createTestWidgetWithPresets({
      FilterState? initialFilter,
      List<FilterPreset>? presets,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: FilterPanel(
            onFilterChanged: (filter) {
              filterChangedCalls.add(filter);
            },
            initialFilter: initialFilter,
            presets: presets ?? [],
            onPresetsChanged: (presets) {
              presetsChangedCalls.add(presets);
            },
          ),
        ),
      );
    }

    testWidgets('should show save preset button when filters active',
        (WidgetTester tester) async {
      final initialFilter = FilterState(searchKeyword: 'test');
      await tester.pumpWidget(
        createTestWidgetWithPresets(initialFilter: initialFilter),
      );

      expect(find.text('保存预设'), findsOneWidget);
    });

    testWidgets('should not show save preset button when no filters active',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidgetWithPresets());

      expect(find.text('保存预设'), findsNothing);
    });

    testWidgets('should show presets dropdown when presets exist',
        (WidgetTester tester) async {
      final presets = [
        FilterPreset(
          name: 'Preset 1',
          filter: FilterState(searchKeyword: 'test'),
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(
        createTestWidgetWithPresets(presets: presets),
      );

      expect(find.byIcon(Icons.bookmarks), findsOneWidget);
    });

    testWidgets('should not show presets dropdown when no presets',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidgetWithPresets());

      expect(find.byIcon(Icons.bookmarks), findsNothing);
    });

    testWidgets('should open save preset dialog when save button tapped',
        (WidgetTester tester) async {
      final initialFilter = FilterState(searchKeyword: 'test');
      await tester.pumpWidget(
        createTestWidgetWithPresets(initialFilter: initialFilter),
      );

      await tester.tap(find.text('保存预设'));
      await tester.pumpAndSettle();

      expect(find.text('保存过滤预设'), findsOneWidget);
      expect(find.text('预设名称'), findsOneWidget);
    });

    testWidgets('should save preset with entered name',
        (WidgetTester tester) async {
      final initialFilter = FilterState(searchKeyword: 'test');
      await tester.pumpWidget(
        createTestWidgetWithPresets(initialFilter: initialFilter),
      );

      await tester.tap(find.text('保存预设'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '预设名称'),
        'My New Preset',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(presetsChangedCalls.length, 1);
      expect(presetsChangedCalls.first.length, 1);
      expect(presetsChangedCalls.first.first.name, 'My New Preset');
      expect(presetsChangedCalls.first.first.filter.searchKeyword, 'test');
    });

    testWidgets('should cancel save preset dialog',
        (WidgetTester tester) async {
      final initialFilter = FilterState(searchKeyword: 'test');
      await tester.pumpWidget(
        createTestWidgetWithPresets(initialFilter: initialFilter),
      );

      await tester.tap(find.text('保存预设'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(presetsChangedCalls, isEmpty);
    });

    testWidgets('should apply preset when selected from dropdown',
        (WidgetTester tester) async {
      final presetFilter = FilterState(
        searchKeyword: 'preset test',
        statusFilters: {ShotStatusFilter.enabled},
      );
      final presets = [
        FilterPreset(
          name: 'Test Preset',
          filter: presetFilter,
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(
        createTestWidgetWithPresets(presets: presets),
      );

      // Open presets dropdown
      await tester.tap(find.byIcon(Icons.bookmarks));
      await tester.pumpAndSettle();

      // Select the preset
      await tester.tap(find.text('Test Preset'));
      await tester.pumpAndSettle();

      expect(filterChangedCalls.length, 1);
      expect(filterChangedCalls.first.searchKeyword, 'preset test');
      expect(filterChangedCalls.first.statusFilters, {ShotStatusFilter.enabled});
    });

    testWidgets('should delete preset when delete button tapped',
        (WidgetTester tester) async {
      final presets = [
        FilterPreset(
          name: 'Preset 1',
          filter: FilterState(searchKeyword: 'test1'),
          createdAt: DateTime.now(),
        ),
        FilterPreset(
          name: 'Preset 2',
          filter: FilterState(searchKeyword: 'test2'),
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(
        createTestWidgetWithPresets(presets: presets),
      );

      // Open presets dropdown
      await tester.tap(find.byIcon(Icons.bookmarks));
      await tester.pumpAndSettle();

      // Find and tap the delete button for the first preset
      final deleteButtons = find.byIcon(Icons.delete);
      expect(deleteButtons, findsNWidgets(2));
      
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(presetsChangedCalls.length, 1);
      expect(presetsChangedCalls.first.length, 1);
      expect(presetsChangedCalls.first.first.name, 'Preset 2');
    });

    testWidgets('should show preset description in dropdown',
        (WidgetTester tester) async {
      final presets = [
        FilterPreset(
          name: 'Complex Preset',
          filter: FilterState(
            searchKeyword: 'test',
            statusFilters: {ShotStatusFilter.enabled},
            qualityFilters: {QualityFilter.hasBadExample},
          ),
          createdAt: DateTime.now(),
        ),
      ];
      await tester.pumpWidget(
        createTestWidgetWithPresets(presets: presets),
      );

      // Open presets dropdown
      await tester.tap(find.byIcon(Icons.bookmarks));
      await tester.pumpAndSettle();

      expect(find.text('Complex Preset'), findsOneWidget);
      expect(find.text('搜索: test, 1个状态, 1个质量'), findsOneWidget);
    });
  });
}
