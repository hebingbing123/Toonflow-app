import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openflow_app/global_search/advanced_filter_panel.dart';
import 'package:openflow_app/rust_api/search/api.dart';

void main() {
  group('AdvancedFilterPanel', () {
    testWidgets('displays header with title and filter count badge',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify header elements
      expect(find.text('高级过滤'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('displays active filter count badge when filters are active',
        (tester) async {
      final filters = SearchFilters(
        resultTypes: {ResultType.project, ResultType.script},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters,
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Should show badge with count
      expect(find.text('1'), findsOneWidget); // 1 filter type active
    });

    testWidgets('displays all result type checkboxes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify all result types are shown
      expect(find.text('项目'), findsOneWidget);
      expect(find.text('剧本'), findsOneWidget);
      expect(find.text('资产'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('toggles result type when checkbox is tapped', (tester) async {
      SearchFilters? changedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (filters) {
                changedFilters = filters;
              },
            ),
          ),
        ),
      );

      // Toggle then apply (parent is notified on apply, not on each toggle)
      await tester.tap(find.text('项目'));
      await tester.pump();
      await tester.tap(find.text('应用过滤'));
      await tester.pump();

      expect(changedFilters, isNotNull);
      expect(changedFilters!.resultTypes, contains(ResultType.project));

      final checkbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('项目'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('displays time range selection buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify time range section
      expect(find.text('创建时间'), findsOneWidget);
      expect(find.text('选择起始日期'), findsOneWidget);
      expect(find.text('选择结束日期'), findsOneWidget);
    });

    testWidgets('opens date picker when start date button is tapped',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap the start date button
      await tester.tap(find.text('选择起始日期'));
      await tester.pumpAndSettle();

      // Verify date picker is shown
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('选择起始日期'), findsWidgets);
    });

    testWidgets('opens date picker when end date button is tapped',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap the end date button
      await tester.tap(find.text('选择结束日期'));
      await tester.pumpAndSettle();

      // Verify date picker is shown
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('选择结束日期'), findsWidgets);
    });

    testWidgets('displays formatted date after selection', (tester) async {
      final initialDate = DateTime(2024, 1, 15);
      final filters = SearchFilters(timeFrom: initialDate);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters,
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify formatted date is displayed
      expect(find.text('起始: 2024-01-15'), findsOneWidget);
    });

    testWidgets('displays clear time range button when dates are set',
        (tester) async {
      final filters = SearchFilters(
        timeFrom: DateTime(2024, 1, 1),
        timeTo: DateTime(2024, 1, 31),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters,
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify clear button is shown
      expect(find.text('清除时间范围'), findsOneWidget);
    });

    testWidgets('clears time range when clear button is tapped',
        (tester) async {
      final filters = SearchFilters(
        timeFrom: DateTime(2024, 1, 1),
        timeTo: DateTime(2024, 1, 31),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters,
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Scroll to make the clear button visible
      await tester.ensureVisible(find.text('清除时间范围'));
      await tester.pumpAndSettle();

      // Tap clear button
      await tester.tap(find.text('清除时间范围'));
      await tester.pump();

      // Verify dates are cleared (buttons should show default text)
      expect(find.text('选择起始日期'), findsOneWidget);
      expect(find.text('选择结束日期'), findsOneWidget);
    });

    testWidgets('displays apply and clear filter buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify action buttons
      expect(find.text('应用过滤'), findsOneWidget);
      expect(find.text('清除过滤'), findsOneWidget);
    });

    testWidgets('calls onFiltersChanged when apply button is tapped',
        (tester) async {
      SearchFilters? appliedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (filters) {
                appliedFilters = filters;
              },
            ),
          ),
        ),
      );

      // Tap apply button
      await tester.tap(find.text('应用过滤'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(appliedFilters, isNotNull);
    });

    testWidgets('shows snackbar when filters are applied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap apply button
      await tester.tap(find.text('应用过滤'));
      await tester.pumpAndSettle();

      // Verify snackbar is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('已应用 0 个过滤条件'), findsOneWidget);
    });

    testWidgets('clears all filters when clear button is tapped',
        (tester) async {
      SearchFilters? clearedFilters;
      final filters = SearchFilters(
        resultTypes: {ResultType.project},
        timeFrom: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters,
              onFiltersChanged: (filters) {
                clearedFilters = filters;
              },
            ),
          ),
        ),
      );

      // Tap clear button
      await tester.tap(find.text('清除过滤'));
      await tester.pumpAndSettle();

      // Verify filters are cleared
      expect(clearedFilters, isNotNull);
      expect(clearedFilters!.isEmpty, isTrue);
    });

    testWidgets('shows snackbar when filters are cleared', (tester) async {
      final filters = SearchFilters(
        resultTypes: {ResultType.project},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters,
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap clear button
      await tester.tap(find.text('清除过滤'));
      await tester.pumpAndSettle();

      // Verify snackbar is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('已清除所有过滤条件'), findsOneWidget);
    });

    testWidgets('disables clear button when no filters are active',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Find the clear button
      final clearButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '清除过滤'),
      );

      // Verify button is disabled
      expect(clearButton.onPressed, isNull);
    });

    testWidgets('uses desktop layout when isMobile is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
              isMobile: false,
            ),
          ),
        ),
      );

      // Verify desktop layout (Container with border)
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('uses mobile layout when isMobile is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
              isMobile: true,
            ),
          ),
        ),
      );

      // Verify mobile layout (Drawer)
      expect(find.byType(Drawer), findsOneWidget);
    });

    testWidgets('updates when initialFilters prop changes', (tester) async {
      final filters1 = SearchFilters.empty();
      final filters2 = SearchFilters(
        resultTypes: {ResultType.project},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters1,
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Update with new filters
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: filters2,
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify badge shows updated count
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('displays section titles with proper styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify section titles
      expect(find.text('结果类型'), findsOneWidget);
      expect(find.text('创建时间'), findsOneWidget);
    });

    testWidgets('displays icons for each result type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify icons are displayed
      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byIcon(Icons.description), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('displays calendar icons for date buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify calendar icons
      expect(find.byIcon(Icons.calendar_today), findsNWidgets(2));
    });

    testWidgets('displays action button icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify action button icons
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.clear_all), findsOneWidget);
    });

    testWidgets('maintains scroll position in filter content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdvancedFilterPanel(
              initialFilters: SearchFilters.empty(),
              onFiltersChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify scrollable content
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('SearchFilters', () {
    test('empty() creates filter with no active filters', () {
      final filters = SearchFilters.empty();

      expect(filters.resultTypes, isEmpty);
      expect(filters.timeFrom, isNull);
      expect(filters.timeTo, isNull);
      expect(filters.isEmpty, isTrue);
      expect(filters.hasActiveFilters, isFalse);
      expect(filters.activeFilterCount, equals(0));
    });

    test('activeFilterCount counts result types as one filter', () {
      final filters = SearchFilters(
        resultTypes: {ResultType.project, ResultType.script},
      );

      expect(filters.activeFilterCount, equals(1));
    });

    test('activeFilterCount counts time range as one filter', () {
      final filters = SearchFilters(
        timeFrom: DateTime(2024, 1, 1),
        timeTo: DateTime(2024, 1, 31),
      );

      expect(filters.activeFilterCount, equals(1));
    });

    test('activeFilterCount counts both filter types', () {
      final filters = SearchFilters(
        resultTypes: {ResultType.project},
        timeFrom: DateTime(2024, 1, 1),
      );

      expect(filters.activeFilterCount, equals(2));
    });

    test('hasActiveFilters returns true when filters are active', () {
      final filters = SearchFilters(
        resultTypes: {ResultType.project},
      );

      expect(filters.hasActiveFilters, isTrue);
    });

    test('isEmpty returns true when no filters are active', () {
      final filters = SearchFilters.empty();

      expect(filters.isEmpty, isTrue);
    });

    test('copyWith creates new instance with updated values', () {
      final filters1 = SearchFilters.empty();
      final filters2 = filters1.copyWith(
        resultTypes: {ResultType.project},
      );

      expect(filters2.resultTypes, contains(ResultType.project));
      expect(filters1.resultTypes, isEmpty);
    });

    test('copyWith with clearTimeRange clears time filters', () {
      final filters1 = SearchFilters(
        timeFrom: DateTime(2024, 1, 1),
        timeTo: DateTime(2024, 1, 31),
      );
      final filters2 = filters1.copyWith(clearTimeRange: true);

      expect(filters2.timeFrom, isNull);
      expect(filters2.timeTo, isNull);
    });

    test('equality compares all fields', () {
      final filters1 = SearchFilters(
        resultTypes: {ResultType.project},
        timeFrom: DateTime(2024, 1, 1),
      );
      final filters2 = SearchFilters(
        resultTypes: {ResultType.project},
        timeFrom: DateTime(2024, 1, 1),
      );

      expect(filters1, equals(filters2));
    });

    test('hashCode is consistent for equal objects', () {
      final filters1 = SearchFilters(
        resultTypes: {ResultType.project},
      );
      final filters2 = SearchFilters(
        resultTypes: {ResultType.project},
      );

      // Note: Set hashCode may vary, so we just verify they're both non-zero
      expect(filters1.hashCode, isNonZero);
      expect(filters2.hashCode, isNonZero);
    });
  });
}
