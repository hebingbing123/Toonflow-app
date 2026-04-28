import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/quality_reviews/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('summarizeQualityReviews compacts review list', () {
    final summary = summarizeQualityReviews(const [
      QualityReview(
        id: 'r1',
        createdAt: '2026-04-10T00:00:00Z',
        updatedAt: '2026-04-10T00:00:00Z',
        userId: 'u1',
        targetType: 'output',
        source: 'manual',
        overallScore: 81,
        isBadCase: false,
      ),
      QualityReview(
        id: 'r2',
        createdAt: '2026-04-10T00:00:00Z',
        updatedAt: '2026-04-10T00:00:00Z',
        userId: 'u1',
        targetType: 'storyboard',
        source: 'agent',
        overallScore: 72,
        isBadCase: true,
      ),
    ]);

    expect(
      summary,
      '评审 2 条 · auto 0 条 · output:manual:81, storyboard:agent:72',
    );
  });

  test('summarizeQualityStatsRows formats stats preview', () {
    final summary = summarizeQualityStatsRows(const [
      QualityStatsRow(
        targetType: 'output',
        totalReviews: 12,
        passedCount: 9,
        failedCount: 3,
        badCaseCount: 2,
        passRatePercent: 75.0,
        avgOverallScore: 82.4,
        deliveryPriorityTotalReviews: 4,
        deliveryPriorityPassedCount: 3,
        deliveryPriorityBadCaseCount: 1,
        deliveryPriorityPassRatePercent: 75.0,
        nonDeliveryPriorityTotalReviews: 8,
        nonDeliveryPriorityPassedCount: 6,
        nonDeliveryPriorityBadCaseCount: 1,
        nonDeliveryPriorityPassRatePercent: 75.0,
      ),
    ]);

    expect(summary, 'output: total=12, pass=75.0% (delivery=75.0%, non=75.0%)');
  });

  test('formatQualityReviewDetails includes core fields', () {
    final details = formatQualityReviewDetails(
      const QualityReview(
        id: 'r1',
        createdAt: '2026-04-10T00:00:00Z',
        updatedAt: '2026-04-10T00:00:00Z',
        userId: 'u1',
        targetType: 'output',
        targetId: 'job-1',
        source: 'manual',
        overallScore: 88,
        passed: true,
        isBadCase: true,
        badCaseCategory: 'continuity',
      ),
    );

    expect(
      details,
      'r1 · output · manual · target=job-1 · score=88 · passed=true · bad_case · category=continuity',
    );
  });

  test(
    'summarizeQualityTokenEfficiencyRows formats prompt and memory shares',
    () {
      final summary = summarizeQualityTokenEfficiencyRows(const [
        QualityTokenEfficiencyRow(
          targetType: 'storyboard',
          sampleCount: 6,
          avgPromptChars: 420,
          avgNonMemoryPromptChars: 348,
          avgMemoryStyleChars: 72,
          avgMemoryVisualChars: 40,
          avgMemoryDeliveryChars: 32,
          avgMemorySharePercent: 17.1,
          avgDeliveryMemorySharePercent: 7.6,
          deliveryPriorityHitRatePercent: 66.7,
        ),
      ]);

      expect(
        summary,
        'storyboard: prompt=420, base=348, memory=72 (17.1%, delivery=32/7.6%, hit=66.7%)',
      );
    },
  );

  test(
    'summarizeQualityTokenEfficiencySamples formats recent sample preview',
    () {
      final summary = summarizeQualityTokenEfficiencySamples(const [
        QualityTokenEfficiencySampleRow(
          createdAt: '2026-04-28T09:30:00Z',
          targetType: 'storyboard',
          promptChars: 436,
          nonMemoryPromptChars: 356,
          memoryStyleChars: 80,
          memoryVisualChars: 44,
          memoryDeliveryChars: 36,
          memorySharePercent: 18.3,
          deliveryMemorySharePercent: 8.3,
          memoryDeliveryPriorityApplied: true,
        ),
      ]);

      expect(
        summary,
        '04-28 09:30 storyboard: prompt=436, base=356, memory=80 (18.3%, delivery优先)',
      );
    },
  );
}
