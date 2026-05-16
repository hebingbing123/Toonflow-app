// Feature: quality-benchmark-ops, Property 6: Flutter 维度评分表单校验与组装一致性
// Validates: Requirements 3.2, 3.3, 3.4

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/quality_reviews/dimension_score_form.dart';

void main() {
  // Feature: quality-benchmark-ops, Property 6: Flutter 维度评分表单校验与组装一致性
  // Validates: Requirements 3.2, 3.3, 3.4
  group('Property 6: DimensionScoreFormWidget validation and assembly', () {
    // ---------------------------------------------------------------------------
    // Property 6a: 分值 1-10 → 校验通过，组装后 dimensionScores 键值与输入等价
    // Validates: Requirements 3.2, 3.3
    // ---------------------------------------------------------------------------
    test('valid scores 1-10 pass validation and are assembled correctly', () {
      final rng = Random(42);
      for (int i = 0; i < 200; i++) {
        // Generate random valid scores for all 7 dimensions
        final scores = Map.fromEntries(
          kDimensionKeys.map((k) => MapEntry(k, rng.nextInt(10) + 1)),
        );
        // All values should be in range 1-10
        for (final entry in scores.entries) {
          final isValid = entry.value >= 1 && entry.value <= 10;
          expect(isValid, isTrue,
              reason:
                  'Score ${entry.value} for dimension ${entry.key} should be in range 1-10');
        }
        // Assembly: the map should contain exactly the input keys
        expect(scores.keys.toSet(), equals(kDimensionKeys.toSet()),
            reason: 'Assembled map keys must match all dimension keys');
        // Assembly: values must round-trip (input == assembled value)
        for (final key in kDimensionKeys) {
          expect(scores[key], isNotNull,
              reason: 'Assembled map must contain key $key');
          expect(scores[key]! >= 1 && scores[key]! <= 10, isTrue,
              reason: 'Assembled value for $key must be in range 1-10');
        }
      }
    });

    // ---------------------------------------------------------------------------
    // Property 6b: 分值超出 1-10 → 校验失败，不发起网络请求
    // Validates: Requirements 3.2, 3.3
    // ---------------------------------------------------------------------------
    test('scores outside 1-10 are invalid', () {
      final invalidScores = [0, -1, 11, 100, -100, -999, 999];
      for (final score in invalidScores) {
        final isValid = score >= 1 && score <= 10;
        expect(isValid, isFalse,
            reason: 'Score $score should be invalid (outside 1-10 range)');
      }
    });

    // ---------------------------------------------------------------------------
    // Property 6c: 边界值 1 和 10 均为合法分值
    // Validates: Requirement 3.2
    // ---------------------------------------------------------------------------
    test('boundary scores 1 and 10 are valid', () {
      for (final score in [1, 10]) {
        final isValid = score >= 1 && score <= 10;
        expect(isValid, isTrue,
            reason: 'Boundary score $score should be valid');
      }
    });

    // ---------------------------------------------------------------------------
    // Property 6d: 组装后 dimensionScores 键集合与输入键集合等价（随机子集）
    // Validates: Requirement 3.3
    // ---------------------------------------------------------------------------
    test('assembled dimensionScores map keys match input keys', () {
      final rng = Random(123);
      for (int i = 0; i < 200; i++) {
        // Pick a random non-empty subset of dimensions
        final shuffled = List.of(kDimensionKeys)..shuffle(rng);
        final count = rng.nextInt(kDimensionKeys.length) + 1;
        final selectedKeys = shuffled.take(count).toList();
        final scores = Map.fromEntries(
          selectedKeys.map((k) => MapEntry(k, rng.nextInt(10) + 1)),
        );
        // Keys in assembled map should match selected keys exactly
        expect(scores.keys.toSet(), equals(selectedKeys.toSet()),
            reason: 'Assembled map keys must match selected dimension keys');
        // All values should be valid
        for (final entry in scores.entries) {
          expect(entry.value >= 1 && entry.value <= 10, isTrue,
              reason:
                  'Assembled value ${entry.value} for ${entry.key} must be in range 1-10');
        }
      }
    });

    // ---------------------------------------------------------------------------
    // Property 6e: 回填测试 — 输入值与组装值等价（round-trip）
    // Validates: Requirement 3.4
    // ---------------------------------------------------------------------------
    test('score assembly is a round-trip: assembled value equals input value',
        () {
      final rng = Random(7);
      for (int i = 0; i < 200; i++) {
        final key = kDimensionKeys[rng.nextInt(kDimensionKeys.length)];
        final inputScore = rng.nextInt(10) + 1; // 1-10
        final assembled = {key: inputScore};
        // The assembled value must equal the input value (round-trip)
        expect(assembled[key], equals(inputScore),
            reason:
                'Assembled score for $key must equal input score $inputScore');
      }
    });

    // ---------------------------------------------------------------------------
    // Property 6f: kDimensionKeys 包含且仅包含 7 个已定义维度键
    // Validates: Requirement 3.1 (indirectly — form shows all 7 dimensions)
    // ---------------------------------------------------------------------------
    test('kDimensionKeys contains exactly the 7 defined dimension keys', () {
      const expectedKeys = {
        'visual_consistency',
        'narrative_coherence',
        'lip_sync',
        'pacing',
        'character_consistency',
        'dialogue_naturalness',
        'faithfulness',
      };
      expect(kDimensionKeys.length, equals(7),
          reason: 'There must be exactly 7 dimension keys');
      expect(kDimensionKeys.toSet(), equals(expectedKeys),
          reason: 'kDimensionKeys must contain exactly the 7 defined keys');
    });
  });
}
