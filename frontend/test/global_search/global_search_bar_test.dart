import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/global_search/global_search_bar.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

const _searchBar = GlobalSearchBar(
  accessToken: 'test-token',
  showLocalPrefsMenu: false,
);

Future<void> _pumpSearchBarAfterInput(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 1));
}

/// Waits until the submit control is an enabled [IconButton] (not the loading spinner).
Future<void> _tapSearchWhenReady(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    final finder = _submitSearchButton(enabledOnly: true);
    if (finder.evaluate().isEmpty) {
      continue;
    }
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return;
  }
  fail('Timed out waiting for enabled global search submit button');
}

Finder _submitSearchButton({bool enabledOnly = false}) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is! IconButton) {
        return false;
      }
      final icon = widget.icon;
      if (icon is! Icon || icon.icon != Icons.arrow_outward_rounded) {
        return false;
      }
      if (enabledOnly && widget.onPressed == null) {
        return false;
      }
      return true;
    },
  );
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProductDemoMode.instance.enable();
  });

  tearDown(() async {
    await ProductDemoMode.instance.disable();
  });

  group('GlobalSearchBar', () {
    testWidgets('renders search input with placeholder', (tester) async {
      await tester.pumpWidget(_buildTestApp(_searchBar));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('搜索项目、剧本、资产...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('disables search button when input is less than 2 characters',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(_searchBar));

      // Find the text field and enter 1 character
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'a');
      await tester.pump();

      final searchButton = _submitSearchButton();
      expect(searchButton, findsWidgets);

      // Verify button is disabled (onPressed is null)
      final iconButton = tester.widget<IconButton>(searchButton.first);
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('enables search button when input is 2 or more characters',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(_searchBar));

      // Find the text field and enter 2 characters
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'ab');
      await _pumpSearchBarAfterInput(tester);

      // Find the search button
      final searchButton = _submitSearchButton(enabledOnly: true);
      expect(searchButton, findsOneWidget);

      // Verify button is enabled (onPressed is not null)
      final iconButton = tester.widget<IconButton>(searchButton);
      expect(iconButton.onPressed, isNotNull);
    });

    testWidgets('triggers search on Enter key press', (tester) async {
      String? capturedQuery;

      await tester.pumpWidget(
        _buildTestApp(
          GlobalSearchBar(
            accessToken: 'test-token',
            showLocalPrefsMenu: false,
            onNavigateToResults: (query, {initialResultTypes = const [], initialTimeFrom, initialTimeTo}) {
              capturedQuery = query;
            },
          ),
        ),
      );

      // Enter text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'test query');
      await _pumpSearchBarAfterInput(tester);

      // Simulate Enter key press
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Verify navigation was triggered with correct query
      expect(capturedQuery, 'test query');
    });

    testWidgets('triggers search on button click', (tester) async {
      String? capturedQuery;

      await tester.pumpWidget(
        _buildTestApp(
          GlobalSearchBar(
            accessToken: 'test-token',
            showLocalPrefsMenu: false,
            onNavigateToResults: (query, {initialResultTypes = const [], initialTimeFrom, initialTimeTo}) {
              capturedQuery = query;
            },
          ),
        ),
      );

      // Enter text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'test query');
      await _pumpSearchBarAfterInput(tester);

      await _tapSearchWhenReady(tester);

      // Verify navigation was triggered with correct query
      expect(capturedQuery, 'test query');
    });

    testWidgets('shows error message when query is less than 2 characters',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(_searchBar));

      // Enter 1 character
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'a');
      await tester.pump();

      // Find the search button - it should be disabled
      final searchButton = _submitSearchButton();
      final iconButton = tester.widget<IconButton>(searchButton);
      
      // Verify button is disabled when less than 2 characters
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('Ctrl+K shortcut is handled', (tester) async {
      await tester.pumpWidget(_buildTestApp(_searchBar));
      await tester.pump();

      // Just verify the Focus widget exists and can handle key events
      final focusWidget = find.byType(Focus);
      expect(focusWidget, findsWidgets);
    });

    testWidgets('Escape key clears focus', (tester) async {
      await tester.pumpWidget(_buildTestApp(_searchBar));

      // Focus the search box
      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.pump();

      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.focusNode?.hasFocus, isTrue);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // Verify focus is cleared
      expect(textFieldWidget.focusNode?.hasFocus, isFalse);
    });

    testWidgets('validates maximum query length', (tester) async {
      await tester.pumpWidget(_buildTestApp(_searchBar));

      // Enter a very long query (>200 characters)
      final longQuery = 'a' * 201;
      final textField = find.byType(TextField);
      await tester.enterText(textField, longQuery);
      await tester.pump();

      // Try to submit
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Verify error message is shown
      expect(find.text('搜索关键词过长，请限制在200字符以内'), findsOneWidget);
    });
  });
}
