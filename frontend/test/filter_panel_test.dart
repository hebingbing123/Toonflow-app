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
}
