// Feature: quality-benchmark-ops, Property 7: 风险标记与分值规则一致性
// Validates: Requirements 8.3

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/quality_reviews/dimension_score_form.dart';

void main() {
  // Feature: quality-benchmark-ops, Property 7: 风险标记与分值规则一致性
  // Validates: Requirements 8.3
  group('Property 7: hasDimensionRisk consistency with score rules', () {
    test('hasDimensionRisk returns true iff any score <= 3 (200 random cases)', () {
      final rng = Random(42);
      for (int i = 0; i < 200; i++) {
        // Generate random scores for a random subset of dimensions
        final count = rng.nextInt(kDimensionKeys.length) + 1;
        final keys = (List.of(kDimensionKeys)..shuffle(rng)).take(count).toList();
        // Random scores in range 1-10
        final scores = Map.fromEntries(
          keys.map((k) => MapEntry(k, rng.nextInt(10) + 1)),
        );

        final result = hasDimensionRisk(scores);
        final expected = scores.values.any((v) => v <= 3);

        expect(result, equals(expected),
            reason: 'hasDimensionRisk($scores) should be $expected');
      }
    });

    test('hasDimensionRisk returns false for null scores', () {
      expect(hasDimensionRisk(null), isFalse);
    });

    test('hasDimensionRisk returns false for empty scores', () {
      expect(hasDimensionRisk({}), isFalse);
    });

    test('hasDimensionRisk returns true when score is exactly 3', () {
      expect(hasDimensionRisk({'lip_sync': 3}), isTrue);
    });

    test('hasDimensionRisk returns false when all scores are 4+', () {
      final scores = Map.fromEntries(kDimensionKeys.map((k) => MapEntry(k, 4)));
      expect(hasDimensionRisk(scores), isFalse);
    });
  });
}
