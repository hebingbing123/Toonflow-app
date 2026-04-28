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

    expect(summary, '评审 2 条 · output:manual:81, storyboard:agent:72');
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

  test('summarizeQualityTokenEfficiencyRows formats efficiency preview', () {
    final summary = summarizeQualityTokenEfficiencyRows(const [
      QualityTokenEfficiencyRow(
        targetType: 'output',
        totalReviews: 10,
        linkedLlmReviewCount: 8,
        avgOverallScore: 84.3,
        avgPromptChars: 920,
        avgMemoryDeliveryChars: 120,
        avgMemoryVisualChars: 88,
        avgMemoryScriptScopeChars: 70,
        avgMemoryProjectScopeChars: 22,
        avgMemoryMixedScopeChars: 14,
        avgLinkedTotalTokens: 640,
        avgPromptCharsPerScorePoint: 10.9,
        avgLinkedTokensPerScorePoint: 7.6,
        deliveryPriorityAvgPromptCharsPerScorePoint: 9.8,
        deliveryPriorityAvgLinkedTokensPerScorePoint: 6.9,
        nonDeliveryPriorityAvgPromptCharsPerScorePoint: 11.7,
        nonDeliveryPriorityAvgLinkedTokensPerScorePoint: 8.1,
      ),
    ]);

    expect(
      summary,
      'output: linked=8/10, avgScore=84.3, mem=d120/v88 scope=s70/p22/m14, prompt/score=10.9, token/score=7.6 (delivery=6.9, non=8.1)',
    );
  });
}
