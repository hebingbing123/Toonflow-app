import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/quality_reviews/support.dart';
import 'package:openflow_app/rust_api.dart';

final _zh = AppLocalizationsZh();

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
    ], l10n: _zh);

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
    ], l10n: _zh);

    expect(summary, 'output：共 12 条，通过率 75.0%（投放 75.0%，非投放 75.0%）');
  });

  test('summarizeQualityScopeInsightRows formats scope triage preview', () {
    final summary = summarizeQualityScopeInsightRows(const [
      QualityScopeInsightRow(
        scopeLabel: 'P12/S7',
        projectId: 12,
        scriptId: 7,
        totalReviews: 4,
        autoReviews: 3,
        passedCount: 2,
        badCaseCount: 2,
        passRatePercent: 50.0,
        avgOverallScore: 73.5,
        dialogueRiskCount: 2,
        visualRiskCount: 1,
        avgPromptChars: 480,
        avgMemoryChars: 92,
        avgMemoryDeliveryChars: 38,
        deliveryPriorityHitRatePercent: 66.7,
        memoryRemovedChars: 140,
        memoryRemovedRows: 3,
        feedbackSelectedMemoryPromotions: 2,
        feedbackRejectedMemoryWrites: 1,
        feedbackSummaryMemoryWrites: 0,
        feedbackMemoryRemovedChars: 88,
        feedbackMemoryRemovedRows: 2,
        feedbackFocusTags: ['delivery_realism', 'emotion_arc'],
        memoryAction: 'keep_delivery_memory',
        memoryFocus: 'selected_video_memory',
        memoryReason:
            'Keep scoped acting memory and keep trimming generic style first.',
      ),
    ], l10n: _zh);

    expect(
      summary,
      'P12/S7 4条 · pass=50.0% · 坏例2 · 情绪2 · 真实感1 · auto=480/92/38 · 压缩 140 字符/3条 · 晋升2 · 坏例回写1 · 回写slim 88c/2条 · 关注=台词真实/情绪层次 · 动作=保留表演记忆 · 焦点=selected_video_memory · Keep scoped acting memory and keep trimming generic style first.',
    );
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
        suggestedAction: 'patch_storyboard_items',
      ),
    );

    expect(
      details,
      contains(
        'r1 · output · manual · target=job-1 · score=88 · passed=true · bad_case · category=continuity · suggested_action=patch_storyboard_items',
      ),
    );
    expect(details, contains('suggestions=先局部修分镜条目，把动作、视线和节奏补齐。'));
  });

  test('QualityReview.fromJson parses suggestedAction', () {
    final review = QualityReview.fromJson(const {
      'id': 'r-json',
      'createdAt': '2026-04-10T00:00:00Z',
      'updatedAt': '2026-04-10T00:00:00Z',
      'userId': 'u1',
      'targetType': 'output',
      'source': 'manual',
      'isBadCase': true,
      'suggestedAction': 'adjust_video_prompt',
    });

    expect(review.suggestedAction, 'adjust_video_prompt');
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
              'negativeSavedFragmentCount': 2,
              'negativeSavedChars': 34,
              'memoryProjectScopeRowCount': 1,
              'memoryScriptScopeRowCount': 2,
              'memoryRoleScopeRowCount': 1,
              'continuityNoteCount': 1,
              'usesReferenceFrame': true,
            },
          },
        ),
        l10n: _zh,
      );

      expect(details, contains('诊断=prompt=420'));
      expect(details, contains('negative constraint=reviews+bad-case memory'));
      expect(details, contains('hit=表演 2 times/语气'));
      expect(details, contains('suppressed=动作 2 times'));
      expect(details, contains('director yield'));
      expect(details, contains('reference frame'));
      expect(details, contains('negative slim=2 items/34 chars'));
      expect(details, contains('memory scope=project 1/script 2/role 1'));
      expect(details, contains('建议='));
    },
  );

  test(
    'formatQualityReviewDetails appends memory writeback summary when present',
    () {
      final details = formatQualityReviewDetails(
        const QualityReview(
          id: 'r-memory',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          projectId: 7,
          scriptId: 3,
          targetType: 'storyboard',
          targetId: '12',
          source: 'auto',
          overallScore: 92,
          passed: true,
          isBadCase: false,
          modelParams: {
            'diagnostics': {
              'feedbackMemory': {
                'action': 'promoted_selected_memory',
                'storyboardId': 12,
                'memoryName': 'selected_video_memory',
                'clearedMemoryName': 'rejected_video_negative_memory',
                'removedRows': 2,
                'removedChars': 88,
                'removedVisualRows': 1,
                'removedDuplicateRows': 1,
                'focusTags': ['delivery_realism', 'lighting_realism'],
              },
            },
          },
        ),
        l10n: _zh,
      );

      expect(details, contains('回写=promoted selected memory'));
      expect(details, contains('shot 12'));
      expect(details, contains('write=selected_video_memory'));
      expect(details, contains('clear=rejected_video_negative_memory'));
      expect(
        details,
        contains('slim 88 chars / 2 items (dup 1 / visual-only 1)'),
      );
      expect(details, contains('watch=dialogue realism/lighting realism'));
    },
  );

  test(
    'buildQualityReviewRepairSuggestions flags project-only memory pressure before trimming delivery',
    () {
      final suggestions = buildQualityReviewRepairSuggestions(
        const QualityReview(
          id: 'r3',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'storyboard',
          source: 'auto',
          overallScore: 78,
          isBadCase: false,
          comments: '情绪还不够自然，有点生硬',
          suggestedAction: 'update_character_anchor',
          modelParams: {
            'diagnostics': {
              'promptChars': 430,
              'memoryStyleChars': 72,
              'memoryVisualChars': 30,
              'memoryDeliveryChars': 18,
              'memoryProjectScopeRowCount': 3,
              'memoryScriptScopeRowCount': 0,
              'memoryRoleScopeRowCount': 0,
              'memoryHitBuckets': ['表演'],
            },
          },
        ),
        l10n: _zh,
      );

      expect(suggestions.first, '先补角色锚点，明确外形、气质和情绪反应，再重试。');
      expect(suggestions, contains('当前主要命中项目级记忆，继续压词时先缩通用风格句，别动人物表演。'));
      expect(suggestions, contains('保留表演/语气记忆，补可演的情绪动作，别先删 delivery 记忆。'));
    },
  );

  test(
    'summarizeSuggestedActionHotspotsFromReviews ranks repeated actions',
    () {
      final summary = summarizeSuggestedActionHotspotsFromReviews(const [
        QualityReview(
          id: 'r1',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'storyboard',
          source: 'auto',
          isBadCase: true,
          suggestedAction: 'patch_storyboard_items',
        ),
        QualityReview(
          id: 'r2',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'storyboard',
          source: 'auto',
          isBadCase: true,
          suggestedAction: 'patch_storyboard_items',
        ),
        QualityReview(
          id: 'r3',
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:00:00Z',
          userId: 'u1',
          targetType: 'output',
          source: 'manual',
          isBadCase: true,
          suggestedAction: 'adjust_video_prompt',
        ),
      ], l10n: _zh);

      expect(summary, contains('先局部修分镜条目，把动作、视线和节奏补齐。 2x'));
      expect(summary, contains('先收紧 video prompt，把表演线索和情绪锚点写实。 1x'));
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
    ], l10n: _zh);

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
      ], l10n: _zh);

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
        l10n: _zh,
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
      ], l10n: _zh);

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
        l10n: _zh,
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
      ], l10n: _zh);

      expect(summary, contains('继续压动作/光影这类泛句，把预算留给表情、口型和人物一致性。 2次'));
      expect(summary, contains('保留表演/语气记忆，补可演的情绪动作，别先删 delivery 记忆。 1次'));
    },
  );

  test('summarizeQualityTokenEfficiencyRows formats prompt and memory shares', () {
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
        memoryAction: 'trim_generic_style_memory',
        memoryFocus: 'project_video_style_memory',
        memoryReason:
            'Project-wide style memory is eating budget; trim generic visual/style lines first.',
      ),
    ], l10n: _zh);

    expect(
      summary,
      'storyboard：提示词 420，基础 348，记忆 72（占比 17.1%，投放 32/7.6%，命中 66.7%） · 动作=压项目泛风格 · 焦点=project_video_style_memory · Project-wide style memory is eating budget; trim generic visual/style lines first.',
    );
  });

  test(
    'summarizeQualityTokenEfficiencyActionPlan prefers scoped quality-first memory actions',
    () {
      final summary = summarizeQualityTokenEfficiencyActionPlan(
        const [
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
            memoryAction: 'trim_generic_style_memory',
            memoryFocus: 'project_video_style_memory',
            memoryReason:
                'Project-wide style memory is eating budget; trim generic visual/style lines first.',
          ),
          QualityTokenEfficiencyRow(
            targetType: 'shot',
            sampleCount: 3,
            avgPromptChars: 408,
            avgNonMemoryPromptChars: 336,
            avgMemoryStyleChars: 72,
            avgMemoryVisualChars: 28,
            avgMemoryDeliveryChars: 44,
            avgMemorySharePercent: 17.6,
            avgDeliveryMemorySharePercent: 10.8,
            deliveryPriorityHitRatePercent: 100,
            memoryAction: 'keep_delivery_memory',
            memoryFocus: 'selected_video_memory',
            memoryReason:
                'Keep scoped acting memory and keep trimming generic style first.',
          ),
        ],
        projectId: 7,
        scriptId: 11,
        l10n: _zh,
      );

      expect(summary, startsWith('P7/S11 独立记忆建议：'));
      expect(
        summary,
        contains('shot 保留镜头级精选记忆的表演/情绪记忆，继续压泛风格句，别先删 delivery 片段。'),
      );
      expect(summary, contains('storyboard 优先压项目级风格记忆里的动作/光影/氛围套话'));
    },
  );

  test(
    'buildQualityScopedExecutionChecklist keeps scope isolation and quality-first trimming order',
    () {
      final checklist = buildQualityScopedExecutionChecklist(
        projectId: 7,
        scriptId: 11,
        tokenRows: const [
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
            memoryAction: 'keep_delivery_memory',
            memoryFocus: 'selected_video_memory',
            memoryReason: 'Keep acting memory first.',
          ),
          QualityTokenEfficiencyRow(
            targetType: 'storyboard',
            sampleCount: 4,
            avgPromptChars: 408,
            avgNonMemoryPromptChars: 336,
            avgMemoryStyleChars: 72,
            avgMemoryVisualChars: 28,
            avgMemoryDeliveryChars: 44,
            avgMemorySharePercent: 17.6,
            avgDeliveryMemorySharePercent: 10.8,
            deliveryPriorityHitRatePercent: 100,
            memoryAction: 'trim_generic_style_memory',
            memoryFocus: 'project_video_style_memory',
            memoryReason: 'Trim project style memory.',
          ),
        ],
        reviews: const [
          QualityReview(
            id: 'review-auto-1',
            createdAt: '2026-04-14T08:00:00Z',
            updatedAt: '2026-04-14T08:00:00Z',
            userId: 'user-1',
            projectId: 7,
            scriptId: 11,
            targetType: 'storyboard',
            source: 'auto',
            overallScore: 76,
            dialogueNaturalness: 70,
            visualQuality: 78,
            isBadCase: true,
            badCaseCategory: 'emotion',
            comments: '台词偏生硬，没有情绪起伏',
          ),
        ],
        l10n: _zh,
      );

      expect(checklist, startsWith('P7/S11 执行清单：'));
      expect(checklist, contains('保留镜头级精选记忆里的表演、语气、口型和情绪记忆，只压泛风格套话。'));
      expect(checklist, contains('清掉项目级风格记忆里的动作、光影、氛围套话，把 token 留给人物表演和连续性。'));
      expect(checklist, contains('范围：记忆只在 P7/S11 生效，不跨用户、项目或短剧复用。'));
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
      ], l10n: _zh);

      expect(
        summary,
        '04-28 09:30 storyboard：提示词 436，基础 356，记忆 80（占比 18.3%，delivery优先）',
      );
    },
  );
}
