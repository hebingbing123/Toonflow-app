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
    'formatQualityReviewDetails appends prompt diagnostics when present',
    () {
      final details = formatQualityReviewDetails(
        const QualityReview(
          id: 'r2',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'storyboard',
          source: 'auto',
          overallScore: 91,
          isBadCase: false,
          modelParams: {
            'diagnostics': {
              'promptChars': 420,
              'memoryStyleChars': 72,
              'memoryVisualChars': 30,
              'memoryDeliveryChars': 42,
              'memoryHitBuckets': ['表演', '语气'],
              'memorySuppressedBuckets': ['动作'],
              'memoryHitBucketCounts': {'表演': 2, '语气': 1},
              'memorySuppressedBucketCounts': {'动作': 2},
              'memoryDeliveryPriorityApplied': true,
              'autoNegativeSource': 'review+rejected_memory',
              'directorManualYieldedToMemory': true,
              'directorAnchorSavedChars': 28,
              'continuityNoteCount': 1,
              'usesReferenceFrame': true,
            },
          },
        ),
      );

      expect(details, contains('诊断=prompt=420'));
      expect(details, contains('负向约束=评审+坏例记忆'));
      expect(details, contains('命中=表演2次/语气'));
      expect(details, contains('压缩=动作2次'));
      expect(details, contains('导演让位'));
      expect(details, contains('参考帧'));
      expect(details, contains('建议='));
    },
  );

  test('summarizePromptDiagnosticsFromQualityReviews aggregates auto rows', () {
    final summary = summarizePromptDiagnosticsFromQualityReviews(const [
      QualityReview(
        id: 'r1',
        createdAt: '2026-04-10T00:00:00Z',
        updatedAt: '2026-04-10T00:00:00Z',
        userId: 'u1',
        targetType: 'storyboard',
        source: 'auto',
        isBadCase: false,
        modelParams: {
          'diagnostics': {
            'promptChars': 400,
            'memoryStyleChars': 80,
            'memoryVisualChars': 24,
            'memoryDeliveryChars': 32,
            'memoryHitBuckets': ['表演', '语气'],
            'memorySuppressedBuckets': ['动作'],
            'memoryHitBucketCounts': {'表演': 1, '语气': 1},
            'memorySuppressedBucketCounts': {'动作': 1},
            'memoryDeliveryPriorityApplied': true,
            'autoNegativeSource': 'review+rejected_memory',
            'directorManualYieldedToMemory': true,
            'continuityNoteCount': 1,
            'usesReferenceFrame': true,
          },
        },
      ),
      QualityReview(
        id: 'r2',
        createdAt: '2026-04-10T00:00:00Z',
        updatedAt: '2026-04-10T00:00:00Z',
        userId: 'u1',
        targetType: 'storyboard',
        source: 'auto',
        isBadCase: false,
        modelParams: {
          'diagnostics': {
            'promptChars': 500,
            'memoryStyleChars': 100,
            'memoryVisualChars': 40,
            'memoryDeliveryChars': 50,
            'memoryHitBuckets': ['表演'],
            'memorySuppressedBuckets': ['动作', '光影'],
            'memoryHitBucketCounts': {'表演': 1},
            'memorySuppressedBucketCounts': {'动作': 1, '光影': 1},
            'memoryDeliveryPriorityApplied': false,
            'autoNegativeSource': 'review+rejected_memory',
            'directorManualYieldedToMemory': false,
            'continuityNoteCount': 0,
            'usesReferenceFrame': false,
          },
        },
      ),
    ]);

    expect(summary, contains('auto诊断 2 条'));
    expect(summary, contains('平均 prompt=450 chars'));
    expect(summary, contains('delivery优先 50.0%'));
    expect(summary, contains('负向约束=评审+坏例记忆 2 次'));
    expect(summary, contains('命中记忆 表演2次 / 语气1次'));
    expect(summary, contains('压缩桶 动作2次 / 光影1次'));
    expect(summary, contains('导演让位 1/2'));
  });

  test(
    'summarizeMemoryScopePressureFromQualityReviews groups bucket pressure by scope',
    () {
      final summary = summarizeMemoryScopePressureFromQualityReviews(const [
        QualityReview(
          id: 'r1',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          projectId: 12,
          scriptId: 7,
          targetType: 'storyboard',
          source: 'auto',
          isBadCase: false,
          modelParams: {
            'diagnostics': {
              'memoryHitBucketCounts': {'表演': 2, '语气': 1},
              'memorySuppressedBucketCounts': {'动作': 3},
            },
          },
        ),
        QualityReview(
          id: 'r2',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          projectId: 12,
          scriptId: 7,
          targetType: 'storyboard',
          source: 'auto',
          isBadCase: false,
          modelParams: {
            'diagnostics': {
              'memoryHitBucketCounts': {'表演': 1},
              'memorySuppressedBucketCounts': {'动作': 1, '光影': 1},
            },
          },
        ),
        QualityReview(
          id: 'r3',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          projectId: 30,
          targetType: 'storyboard',
          source: 'auto',
          isBadCase: false,
          modelParams: {
            'diagnostics': {
              'memoryHitBucketCounts': {'口型': 1},
            },
          },
        ),
      ]);

      expect(summary, contains('P12/S7 2条'));
      expect(summary, contains('命中 表演3次 / 语气1次'));
      expect(summary, contains('压缩 动作4次 / 光影1次'));
      expect(summary, contains('P30 1条'));
    },
  );

  test(
    'summarizeMemoryOptimizationSavingsFromQualityReviews groups saved chars by scope',
    () {
      final summary = summarizeMemoryOptimizationSavingsFromQualityReviews(
        const [
          QualityReview(
            id: 'r1',
            createdAt: '2026-04-10T00:00:00Z',
            updatedAt: '2026-04-10T00:00:00Z',
            userId: 'u1',
            projectId: 12,
            scriptId: 7,
            targetType: 'storyboard',
            source: 'auto',
            isBadCase: false,
            modelParams: {
              'diagnostics': {
                'memoryOptimizationRemovedChars': 88,
                'memoryOptimizationRemovedRows': 2,
                'memoryOptimizationRemovedVisualRows': 1,
                'memoryOptimizationRemovedDuplicateRows': 1,
              },
            },
          ),
          QualityReview(
            id: 'r2',
            createdAt: '2026-04-10T00:00:00Z',
            updatedAt: '2026-04-10T00:00:00Z',
            userId: 'u1',
            projectId: 12,
            scriptId: 7,
            targetType: 'storyboard',
            source: 'auto',
            isBadCase: false,
            modelParams: {
              'diagnostics': {
                'memoryOptimizationRemovedChars': 42,
                'memoryOptimizationRemovedRows': 1,
                'memoryOptimizationRemovedVisualRows': 0,
                'memoryOptimizationRemovedDuplicateRows': 1,
              },
            },
          ),
          QualityReview(
            id: 'r3',
            createdAt: '2026-04-10T00:00:00Z',
            updatedAt: '2026-04-10T00:00:00Z',
            userId: 'u1',
            projectId: 30,
            targetType: 'storyboard',
            source: 'auto',
            isBadCase: false,
            modelParams: {
              'diagnostics': {
                'memoryOptimizationRemovedChars': 24,
                'memoryOptimizationRemovedRows': 1,
                'memoryOptimizationRemovedVisualRows': 1,
                'memoryOptimizationRemovedDuplicateRows': 0,
              },
            },
          ),
        ],
      );

      expect(
        summary,
        contains('P12/S7 2条 · slim 130 chars / 3条（重复 2 / 纯视觉 1）'),
      );
      expect(summary, contains('P30 1条 · slim 24 chars / 1条（重复 0 / 纯视觉 1）'));
    },
  );

  test(
    'summarizeScopeRepairQueueFromQualityReviews ranks scope next steps',
    () {
      final summary = summarizeScopeRepairQueueFromQualityReviews(const [
        QualityReview(
          id: 'r1',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          projectId: 12,
          scriptId: 7,
          targetType: 'storyboard',
          source: 'auto',
          overallScore: 68,
          dialogueNaturalness: 69,
          visualQuality: 74,
          isBadCase: true,
          badCaseCategory: 'continuity',
          comments: '台词生硬，没情绪，镜头穿帮',
          modelParams: {
            'diagnostics': {
              'memoryOptimizationRemovedChars': 88,
              'continuityNoteCount': 2,
              'usesReferenceFrame': false,
              'memoryHitBucketCounts': {'表演': 1},
              'memorySuppressedBucketCounts': {'动作': 1},
            },
          },
        ),
        QualityReview(
          id: 'r2',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          projectId: 30,
          targetType: 'storyboard',
          source: 'manual',
          overallScore: 82,
          visualQuality: 78,
          isBadCase: false,
          comments: '画面有点假',
        ),
      ]);

      expect(
        summary,
        contains('P12/S7 1条 · 坏例 1 · 情绪/台词 1 · 真实感 1 · slim 88 chars'),
      );
      expect(summary, contains('下一步'));
      expect(summary, contains('P30 1条 · 真实感 1'));
    },
  );

  test(
    'buildQualityReviewRepairSuggestions prioritizes acting, continuity and token-saving fixes',
    () {
      final suggestions = buildQualityReviewRepairSuggestions(
        const QualityReview(
          id: 'r-fix',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'storyboard',
          source: 'auto',
          overallScore: 66,
          dialogueNaturalness: 68,
          visualQuality: 72,
          isBadCase: true,
          badCaseCategory: 'continuity',
          comments: '台词有点生硬，情绪也比较平，镜头有穿帮',
          modelParams: {
            'diagnostics': {
              'promptChars': 560,
              'memoryStyleChars': 112,
              'negativePromptChars': 62,
              'continuityNoteCount': 2,
              'usesReferenceFrame': false,
              'autoNegativeSource': 'review+rejected_memory',
              'directorManualYieldedToMemory': true,
              'memoryHitBucketCounts': {'表演': 2, '语气': 1},
              'memorySuppressedBucketCounts': {'动作': 2, '光影': 1},
            },
          },
        ),
      );

      expect(suggestions, contains('先补参考帧和上一镜衔接，锁定脸、服化道和站位连续性。'));
      expect(suggestions, contains('保留表演/语气记忆，补可演的情绪动作，别先删 delivery 记忆。'));
      expect(suggestions, contains('继续压动作/光影这类泛句，把预算留给表情、口型和人物一致性。'));
      expect(suggestions, contains('沿用现有坏例负向约束，手动补词前先去重，避免同义词重复烧 token。'));
    },
  );

  test(
    'summarizeQualityRepairPlanFromReviews ranks repeated repairs across reviews',
    () {
      final summary = summarizeQualityRepairPlanFromReviews(const [
        QualityReview(
          id: 'r1',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'storyboard',
          source: 'auto',
          overallScore: 70,
          dialogueNaturalness: 69,
          isBadCase: true,
          comments: '台词生硬，没情绪',
          modelParams: {
            'diagnostics': {
              'memoryHitBucketCounts': {'表演': 1},
              'memorySuppressedBucketCounts': {'动作': 1},
            },
          },
        ),
        QualityReview(
          id: 'r2',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'storyboard',
          source: 'auto',
          overallScore: 68,
          visualQuality: 70,
          isBadCase: true,
          badCaseCategory: 'continuity',
          modelParams: {
            'diagnostics': {
              'continuityNoteCount': 1,
              'usesReferenceFrame': false,
              'memorySuppressedBucketCounts': {'动作': 2},
            },
          },
        ),
      ]);

      expect(summary, contains('继续压动作/光影这类泛句，把预算留给表情、口型和人物一致性。 2次'));
      expect(summary, contains('保留表演/语气记忆，补可演的情绪动作，别先删 delivery 记忆。 2次'));
    },
  );

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
