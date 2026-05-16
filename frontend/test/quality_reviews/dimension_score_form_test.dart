// Widget tests for DimensionScoreFormWidget and DimensionScoreDisplayWidget
// Validates: Requirements 9.5

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/quality_reviews/dimension_score_form.dart';

/// Wraps [DimensionScoreFormWidget] in a minimal [MaterialApp] + [Scaffold].
Widget _buildForm({
  Map<String, int>? initialScores,
  void Function(Map<String, int>?)? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: DimensionScoreFormWidget(
          initialScores: initialScores,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('DimensionScoreFormWidget widget tests', () {
    // -------------------------------------------------------------------------
    // Test 1: Valid boundary score 1 — no error shown, dimensionScores updated
    // Validates: Requirement 9.5 (合法输入 — 分值 1)
    // -------------------------------------------------------------------------
    testWidgets('valid score 1 shows no error and updates dimensionScores',
        (WidgetTester tester) async {
      Map<String, int>? capturedScores;

      await tester.pumpWidget(_buildForm(
        // Start with lip_sync pre-filled so its row is visible (not skipped)
        initialScores: const {'lip_sync': 5},
        onChanged: (scores) => capturedScores = scores,
      ));

      // Find the TextFormField for the lip_sync row (the only non-skipped row).
      // There is exactly one TextFormField visible when only lip_sync is active.
      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, '1');
      await tester.pump();

      // No error text should be visible
      expect(find.text('分值须在 1–10 之间'), findsNothing);
      expect(find.text('请输入 1–10 的整数'), findsNothing);

      // The onChanged callback should have been called with the updated score
      expect(capturedScores, isNotNull);
      expect(capturedScores!['lip_sync'], equals(1));
    });

    // -------------------------------------------------------------------------
    // Test 1b: Valid boundary score 10 — no error shown, dimensionScores updated
    // Validates: Requirement 9.5 (合法输入 — 分值 10)
    // -------------------------------------------------------------------------
    testWidgets('valid score 10 shows no error and updates dimensionScores',
        (WidgetTester tester) async {
      Map<String, int>? capturedScores;

      await tester.pumpWidget(_buildForm(
        initialScores: const {'lip_sync': 5},
        onChanged: (scores) => capturedScores = scores,
      ));

      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, '10');
      await tester.pump();

      // No error text should be visible
      expect(find.text('分值须在 1–10 之间'), findsNothing);
      expect(find.text('请输入 1–10 的整数'), findsNothing);

      // The onChanged callback should have been called with the updated score
      expect(capturedScores, isNotNull);
      expect(capturedScores!['lip_sync'], equals(10));
    });

    // -------------------------------------------------------------------------
    // Test 2a: Out-of-range score 0 — shows error text
    // Validates: Requirement 9.5 (越界输入 — 分值 0)
    // -------------------------------------------------------------------------
    testWidgets('score 0 shows error text', (WidgetTester tester) async {
      int callbackCount = 0;

      await tester.pumpWidget(_buildForm(
        initialScores: const {'lip_sync': 5},
        onChanged: (_) => callbackCount++,
      ));

      // Reset counter after initial render (initial value triggers onChanged)
      callbackCount = 0;

      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, '0');
      await tester.pump();

      // Error text should be visible
      expect(find.text('分值须在 1–10 之间'), findsOneWidget);

      // onChanged should NOT have been called for invalid input
      expect(callbackCount, equals(0));
    });

    // -------------------------------------------------------------------------
    // Test 2b: Out-of-range score 11 — shows error text
    // Validates: Requirement 9.5 (越界输入 — 分值 11)
    // -------------------------------------------------------------------------
    testWidgets('score 11 shows error text', (WidgetTester tester) async {
      int callbackCount = 0;

      await tester.pumpWidget(_buildForm(
        initialScores: const {'lip_sync': 5},
        onChanged: (_) => callbackCount++,
      ));

      // Reset counter after initial render
      callbackCount = 0;

      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, '11');
      await tester.pump();

      // Error text should be visible
      expect(find.text('分值须在 1–10 之间'), findsOneWidget);

      // onChanged should NOT have been called for invalid input
      expect(callbackCount, equals(0));
    });

    // -------------------------------------------------------------------------
    // Test 3: null safety — DimensionScoreDisplayWidget with null scores
    //         shows placeholder, does not throw
    // Validates: Requirement 9.5 (null 安全性)
    // -------------------------------------------------------------------------
    testWidgets('null dimensionScores shows 暂无维度评分 without throwing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DimensionScoreDisplayWidget(scores: null),
          ),
        ),
      );

      expect(find.text('暂无维度评分'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 3b: empty map — DimensionScoreDisplayWidget also shows placeholder
    // Validates: Requirement 8.2 (null/空对象均显示占位文本)
    // -------------------------------------------------------------------------
    testWidgets('empty dimensionScores map shows 暂无维度评分',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DimensionScoreDisplayWidget(scores: {}),
          ),
        ),
      );

      expect(find.text('暂无维度评分'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 4: Pre-fill — initialScores = {"lip_sync": 7} pre-fills controller
    // Validates: Requirement 9.5 (回填测试)
    // -------------------------------------------------------------------------
    testWidgets(
        'initialScores lip_sync:7 pre-fills the TextFormField with "7"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildForm(
        initialScores: const {'lip_sync': 7},
      ));

      // The lip_sync row is not skipped, so its TextFormField should show "7".
      // All other dimensions are skipped (no TextFormField visible for them).
      final textFields = tester.widgetList<EditableText>(
        find.byType(EditableText),
      );

      // Find the EditableText whose controller has text "7"
      final prefilled = textFields.where((e) => e.controller.text == '7');
      expect(prefilled.length, equals(1),
          reason: 'Exactly one TextFormField should be pre-filled with "7"');
    });
  });
}
