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

  test('summarizeQualityTokenEfficiencySampleRows formats sample preview', () {
    final summary = summarizeQualityTokenEfficiencySampleRows(const [
      QualityTokenEfficiencySampleRow(
        reviewId: 'r-sample',
        createdAt: '2026-04-10T00:00:00Z',
        projectId: 1,
        scriptId: 2,
        jobId: 'job-1',
        targetType: 'asset',
        targetId: 'asset-1',
        source: 'auto',
        overallScore: 4,
        passed: false,
        isBadCase: true,
        memoryDeliveryPriorityApplied: true,
        promptChars: 920,
        linkedTotalTokens: 0,
        memoryDeliveryChars: 90,
        memoryVisualChars: 140,
        memoryScriptScopeChars: 20,
        memoryProjectScopeChars: 150,
        memoryMixedScopeChars: 35,
        promptCharsPerScorePoint: 230,
        linkedTokensPerScorePoint: 0,
        dominantMemoryScope: 'project',
        recommendedAction: 'shift_to_delivery_memory',
        recommendedActionReason: '先把预算从泛设定移到情绪、动作和语气约束',
      ),
    ]);

    expect(
      summary,
      'asset:score=4,p=230.0,t=0.0,bad/delivery/project->shift-to-delivery-memory',
    );
  });

  test(
    'buildQualityMemoryDraft creates isolated summary memory for delivery shift',
    () {
      final draft = buildQualityMemoryDraft(
        const QualityTokenEfficiencySampleRow(
          reviewId: 'r-sample',
          createdAt: '2026-04-10T00:00:00Z',
          projectId: 1,
          scriptId: 2,
          jobId: 'job-1',
          targetType: 'output',
          targetId: 'storyboard-1',
          source: 'auto',
          overallScore: 4,
          passed: false,
          isBadCase: true,
          memoryDeliveryPriorityApplied: false,
          promptChars: 920,
          linkedTotalTokens: 640,
          memoryDeliveryChars: 60,
          memoryVisualChars: 88,
          memoryScriptScopeChars: 70,
          memoryProjectScopeChars: 220,
          memoryMixedScopeChars: 14,
          promptCharsPerScorePoint: 230,
          linkedTokensPerScorePoint: 160,
          dominantMemoryScope: 'project',
          recommendedAction: 'shift_to_delivery_memory',
          recommendedActionReason: '先把预算从泛设定移到情绪、动作和语气约束',
        ),
      );

      expect(draft.canAppend, isTrue);
      expect(draft.agentType, 'productionAgent');
      expect(draft.memoryType, 'summary');
      expect(draft.summary, contains('project#1 / script#2'));
      expect(draft.content, contains('keep=停顿、气口、表情反应、口型同步、动作反馈'));
    },
  );

  test(
    'buildQualityMemoryDraft blocks append when sample scope is incomplete',
    () {
      final draft = buildQualityMemoryDraft(
        const QualityTokenEfficiencySampleRow(
          reviewId: 'r-sample',
          createdAt: '2026-04-10T00:00:00Z',
          projectId: null,
          scriptId: 2,
          jobId: 'job-1',
          targetType: 'script',
          targetId: 'script-1',
          source: 'auto',
          overallScore: 6,
          passed: true,
          isBadCase: false,
          memoryDeliveryPriorityApplied: true,
          promptChars: 400,
          linkedTotalTokens: 320,
          memoryDeliveryChars: 90,
          memoryVisualChars: 40,
          memoryScriptScopeChars: 110,
          memoryProjectScopeChars: 0,
          memoryMixedScopeChars: 0,
          promptCharsPerScorePoint: 66,
          linkedTokensPerScorePoint: 53,
          dominantMemoryScope: 'script',
          recommendedAction: 'trim_script_memory',
          recommendedActionReason: 'script 级记忆占主导，保留当前镜头强约束即可',
        ),
      );

      expect(draft.canAppend, isFalse);
      expect(draft.blockingReason, contains('projectId 或 scriptId'));
    },
  );
}
