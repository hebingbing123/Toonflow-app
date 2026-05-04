import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/storyboard_editor/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test(
    'compactStoryboardManualNegativePrompt drops manual fragments already covered by auto negative',
    () {
      final compressed = compactStoryboardManualNegativePrompt(
        manualPrompt:
            'avoid blur, avoid flicker, avoid face distortion, avoid blank expression',
        automaticPrompt:
            'avoid blur, avoid flicker or motion jitter, avoid face distortion or identity drift',
      );

      expect(compressed.manualPrompt, 'avoid blank expression');
      expect(compressed.removedFragmentCount, 3);
    },
  );

  test(
    'compactStoryboardManualNegativePrompt keeps more specific manual fragment',
    () {
      final compressed = compactStoryboardManualNegativePrompt(
        manualPrompt: 'avoid blank expression or monotone delivery',
        automaticPrompt: 'avoid blank expression',
      );

      expect(
        compressed.manualPrompt,
        'avoid blank expression or monotone delivery',
      );
      expect(compressed.removedFragmentCount, 0);
    },
  );

  test('video prompt diagnostics line shows auto memory slimming result', () {
    const diagnostics = GenerateVideoPromptDiagnostics(
      promptChars: 412,
      negativePromptChars: 56,
      negativeConstraintCount: 2,
      negativeSavedFragmentCount: 2,
      negativeSavedChars: 34,
      negativeBudgetTier: 'lean',
      autoNegativeSource: 'rejected_memory',
      autoNegativeReviewFragmentCount: 0,
      autoNegativeMemoryFragmentCount: 2,
      observationNoteChars: 0,
      roleAnchorCount: 1,
      sceneAnchorCount: 1,
      toolAnchorCount: 0,
      styleAnchorCount: 1,
      memoryStyleAnchorCount: 1,
      memoryDeliveryAnchorCount: 1,
      memoryDeliveryPriorityApplied: true,
      memoryStyleChars: 64,
      memoryVisualChars: 18,
      memoryDeliveryChars: 32,
      memoryHitBuckets: <String>['表演'],
      memorySuppressedBuckets: <String>['动作'],
      memoryOptimizationApplied: true,
      memoryOptimizationRemovedRows: 2,
      memoryOptimizationRemovedChars: 88,
      memoryOptimizationRemovedVisualRows: 1,
      memoryOptimizationRemovedDuplicateRows: 1,
      memoryProjectScopeRowCount: 2,
      memoryScriptScopeRowCount: 1,
      memoryRoleScopeRowCount: 1,
      continuityNoteCount: 1,
      continuityNoteChars: 20,
      usesReferenceFrame: true,
      memoryBudgetTier: 'expanded',
    );

    expect(
      buildStoryboardVideoPromptDiagnosticsLine(diagnostics),
      contains('Memory slim -88'),
    );
    expect(
      buildStoryboardVideoPromptDiagnosticsLine(diagnostics),
      contains('Negative slim -34'),
    );
    expect(
      buildStoryboardVideoPromptSourceSummary(diagnostics),
      contains('自动瘦身 2 条（低信号 0 / 重复 1 / 纯视觉 1）'),
    );
    expect(
      buildStoryboardVideoPromptSourceSummary(diagnostics),
      contains('负向精简 2 条 / 34 chars'),
    );
    expect(
      buildStoryboardVideoPromptAnchorSummary(diagnostics),
      contains('记忆命中 项目 2 / 剧本 1 / 角色 1'),
    );
    expect(
      buildStoryboardVideoPromptBudgetHint(diagnostics),
      contains('已自动清掉重复/纯视觉私有记忆'),
    );
    expect(
      buildStoryboardPromptGenerationFollowUp(
        diagnostics,
        observationNote: '观察到上一轮嘴型偏僵',
      ),
      '已生成默认视频提示词并回填时长；自动负向来自私有坏例记忆；命中项目 2 / 剧本 1 / 角色 1记忆；自动精简 2 条负向约束 / 34 chars；观察到上一轮嘴型偏僵。',
    );
  });

  test(
    'buildStoryboardVideoPromptBudgetHint warns when prompt mostly leans on project memory',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 396,
        negativePromptChars: 22,
        negativeConstraintCount: 1,
        negativeBudgetTier: 'lean',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 0,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 2,
        memoryDeliveryAnchorCount: 0,
        memoryDeliveryPriorityApplied: false,
        memoryStyleChars: 62,
        memoryVisualChars: 30,
        memoryDeliveryChars: 0,
        memoryHitBuckets: [],
        memorySuppressedBuckets: [],
        continuityNoteCount: 0,
        continuityNoteChars: 0,
        usesReferenceFrame: true,
        memoryBudgetTier: 'expanded',
        memoryProjectScopeRowCount: 3,
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '这次主要命中项目级记忆，先把通用风格句收短一点，预算优先留给人物表演和当前镜头连续性。',
      );
      expect(buildStoryboardVideoPromptRepairSuggestions(diagnostics), [
        '这轮主要靠项目级通用记忆在撑，继续压词时优先缩短泛风格句。',
      ]);
    },
  );

  test(
    'describeStoryboardSelectedMemoryFeedback explains isolated reusable memory',
    () {
      final line = describeStoryboardSelectedMemoryFeedback(
        const WorkbenchVideoMemoryFeedback(
          kind: 'selected',
          scope: 'user-project-script',
          subject: '林晚',
          style: '表演喉结滚动，语气低声尾音发颤',
          note: '克制停顿后再开口',
          charCount: 72,
        ),
      );

      expect(line, contains('已提炼私有记忆：林晚 / 表演喉结滚动，语气低声尾音发颤 / 克制停顿后再开口。'));
      expect(line, contains('仅作用于当前用户、项目、剧本'));
    },
  );

  test(
    'describeStoryboardRejectedMemoryFeedback explains isolated negative reuse',
    () {
      final line = describeStoryboardRejectedMemoryFeedback(
        const WorkbenchVideoMemoryFeedback(
          kind: 'rejected',
          scope: 'user-project-script',
          avoid: 'avoid flat cold lighting, avoid blank expression',
          riskTags: <String>['emotion', 'lighting'],
          rejectionCount: 3,
          charCount: 64,
        ),
      );

      expect(
        line,
        contains('已回写私有坏例约束：avoid flat cold lighting, avoid blank expression。'),
      );
      expect(line, contains('累计失败 3 次'));
      expect(line, contains('重点风险 emotion / lighting'));
      expect(line, contains('后续生成会优先复用当前用户、项目、剧本下的负向记忆'));
    },
  );

  test('diagnoseStoryboardList requests creation when there are no boards', () {
    final diagnosis = diagnoseStoryboardList(
      boards: const <StoryboardRow>[],
      productionSummaryLoaded: false,
    );

    expect(
      diagnosis.recommendedAction,
      StoryboardListRecommendedAction.addStoryboard,
    );
    expect(diagnosis.summary, '当前剧本还没有分镜。');
  });

  test(
    'diagnoseStoryboardList requests production refresh before workbench',
    () {
      final diagnosis = diagnoseStoryboardList(
        boards: const [
          StoryboardRow(id: '1', numericId: 11, scriptId: '3', prompt: '镜头一'),
        ],
        productionSummaryLoaded: false,
      );

      expect(
        diagnosis.recommendedAction,
        StoryboardListRecommendedAction.refreshProductionSummary,
      );
    },
  );

  test('diagnoseStoryboardList routes to editing when prompts are missing', () {
    final diagnosis = diagnoseStoryboardList(
      boards: const [
        StoryboardRow(id: '1', numericId: 11, scriptId: '3', prompt: '  '),
      ],
      productionSummaryLoaded: true,
    );

    expect(
      diagnosis.recommendedAction,
      StoryboardListRecommendedAction.editStoryboard,
    );
  });

  test('buildStoryboardListFollowUp appends the recommended action', () {
    final line = buildStoryboardListFollowUp(
      actionSummary: '已批量新增 2 条分镜。',
      diagnosis: diagnoseStoryboardList(
        boards: const [
          StoryboardRow(id: '1', numericId: 11, scriptId: '3', prompt: '镜头一'),
          StoryboardRow(id: '2', numericId: 12, scriptId: '3', prompt: '镜头二'),
        ],
        productionSummaryLoaded: true,
      ),
    );

    expect(line, contains('下一步建议：进入分镜出图工作台。'));
  });

  test(
    'diagnoseStoryboardBatchWorkbench recommends selecting ready boards first',
    () {
      final diagnosis = diagnoseStoryboardBatchWorkbench(
        selectedIds: const <int>[],
        boards: const [
          StoryboardRow(id: '1', numericId: 11, scriptId: '3', prompt: '镜头一'),
          StoryboardRow(id: '2', numericId: 12, scriptId: '3', prompt: '  '),
        ],
        productionRows: const [],
      );

      expect(
        diagnosis.recommendedAction,
        StoryboardBatchWorkbenchRecommendedAction.generateSelected,
      );
    },
  );

  test(
    'diagnoseStoryboardBatchWorkbench requests production sync when coverage is missing',
    () {
      final diagnosis = diagnoseStoryboardBatchWorkbench(
        selectedIds: const [11, 12],
        boards: const [
          StoryboardRow(id: '1', numericId: 11, scriptId: '3', prompt: '镜头一'),
          StoryboardRow(id: '2', numericId: 12, scriptId: '3', prompt: '镜头二'),
        ],
        productionRows: const [
          ProductionStoryboardItemV1(id: 11, prompt: '镜头一'),
        ],
      );

      expect(
        diagnosis.recommendedAction,
        StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary,
      );
    },
  );

  test(
    'diagnoseStoryboardBatchWorkbench prefers preview for single selected board with image',
    () {
      final diagnosis = diagnoseStoryboardBatchWorkbench(
        selectedIds: const [11],
        boards: const [
          StoryboardRow(
            id: '1',
            numericId: 11,
            scriptId: '3',
            prompt: '镜头一',
            filePath: 'poster.png',
          ),
        ],
        productionRows: const [
          ProductionStoryboardItemV1(id: 11, prompt: '镜头一'),
        ],
      );

      expect(
        diagnosis.recommendedAction,
        StoryboardBatchWorkbenchRecommendedAction.previewSelected,
      );
    },
  );

  test(
    'buildStoryboardBatchWorkbenchFollowUp appends the recommended action',
    () {
      final line = buildStoryboardBatchWorkbenchFollowUp(
        actionSummary: '已提交 2 条分镜出图任务。',
        diagnosis: diagnoseStoryboardBatchWorkbench(
          selectedIds: const [11, 12],
          boards: const [
            StoryboardRow(id: '1', numericId: 11, scriptId: '3', prompt: '镜头一'),
            StoryboardRow(id: '2', numericId: 12, scriptId: '3', prompt: '镜头二'),
          ],
          productionRows: const [
            ProductionStoryboardItemV1(id: 11, prompt: '镜头一'),
            ProductionStoryboardItemV1(id: 12, prompt: '镜头二'),
          ],
        ),
      );

      expect(line, contains('下一步建议：一键批量出图。'));
    },
  );

  test('diagnoseStoryboardWorkbench requests sync before anything else', () {
    final diagnosis = diagnoseStoryboardWorkbench(
      scriptStoryboard: const StoryboardRow(
        id: '1',
        numericId: 11,
        scriptId: '3',
        prompt: '镜头一',
      ),
      productionStoryboard: null,
      productionStoryboards: const [],
      generatedVideos: const [],
      generatingJobs: const [],
      draftImageUrl: null,
      trackIdText: '',
      videoPromptText: '',
      videoDurationText: '',
    );

    expect(
      diagnosis.recommendedAction,
      StoryboardWorkbenchRecommendedAction.syncProductionData,
    );
  });

  test(
    'diagnoseStoryboardWorkbench requests preview when image is missing',
    () {
      final diagnosis = diagnoseStoryboardWorkbench(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头一',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(id: 11),
        productionStoryboards: const [ProductionStoryboardItemV1(id: 11)],
        generatedVideos: const [],
        generatingJobs: const [],
        draftImageUrl: '  ',
        trackIdText: '',
        videoPromptText: '',
        videoDurationText: '',
      );

      expect(
        diagnosis.recommendedAction,
        StoryboardWorkbenchRecommendedAction.readCurrentPreview,
      );
    },
  );

  test('diagnoseStoryboardWorkbench requests track preparation first', () {
    final diagnosis = diagnoseStoryboardWorkbench(
      scriptStoryboard: const StoryboardRow(
        id: '1',
        numericId: 11,
        scriptId: '3',
        prompt: '镜头一',
        trackId: 4,
      ),
      productionStoryboard: const ProductionStoryboardItemV1(
        id: 11,
        url: 'https://example.com/frame.png',
      ),
      productionStoryboards: const [ProductionStoryboardItemV1(id: 11)],
      generatedVideos: const [],
      generatingJobs: const [],
      draftImageUrl: null,
      trackIdText: '',
      videoPromptText: 'prompt',
      videoDurationText: '5',
    );

    expect(
      diagnosis.recommendedAction,
      StoryboardWorkbenchRecommendedAction.prepareVideoTrack,
    );
  });

  test(
    'diagnoseStoryboardWorkbench requests default prompt when video params are incomplete',
    () {
      final diagnosis = diagnoseStoryboardWorkbench(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头一',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(
          id: 11,
          url: 'https://example.com/frame.png',
        ),
        productionStoryboards: const [ProductionStoryboardItemV1(id: 11)],
        generatedVideos: const [],
        generatingJobs: const [],
        draftImageUrl: null,
        trackIdText: '7',
        videoPromptText: ' ',
        videoDurationText: '0',
      );

      expect(
        diagnosis.recommendedAction,
        StoryboardWorkbenchRecommendedAction.generateDefaultVideoPrompt,
      );
    },
  );

  test('buildStoryboardVideoPromptDiagnosticsLine summarizes prompt budget', () {
    const diagnostics = GenerateVideoPromptDiagnostics(
      promptChars: 318,
      negativePromptChars: 64,
      negativeConstraintCount: 3,
      negativeBudgetTier: 'expanded',
      autoNegativeSource: null,
      autoNegativeReviewFragmentCount: 0,
      autoNegativeMemoryFragmentCount: 0,
      observationNoteChars: 22,
      roleAnchorCount: 1,
      sceneAnchorCount: 2,
      toolAnchorCount: 1,
      styleAnchorCount: 2,
      memoryStyleAnchorCount: 1,
      memoryDeliveryAnchorCount: 0,
      memoryDeliveryPriorityApplied: false,
      memoryStyleChars: 36,
      memoryVisualChars: 36,
      memoryDeliveryChars: 0,
      memoryHitBuckets: [],
      memorySuppressedBuckets: [],
      continuityNoteCount: 1,
      continuityNoteChars: 18,
      usesReferenceFrame: true,
      memoryBudgetTier: 'expanded',
    );

    expect(
      buildStoryboardVideoPromptDiagnosticsLine(diagnostics),
      'Prompt 318 chars · Negative 64 (expanded) · Observation 22 · Memory 36 · Memory tier expanded',
    );
    expect(
      buildStoryboardVideoPromptAnchorSummary(diagnostics),
      '角色锚点 1 · 场景锚点 2 · 道具锚点 1 · 风格锚点 2 · 私有记忆 1 · 连续性记忆 1 · 已引用当前画面',
    );
  });

  test('buildStoryboardVideoPromptAnchorSummary handles empty diagnostics', () {
    const diagnostics = GenerateVideoPromptDiagnostics(
      promptChars: 120,
      negativePromptChars: 0,
      negativeConstraintCount: 0,
      negativeBudgetTier: 'lean',
      autoNegativeSource: null,
      autoNegativeReviewFragmentCount: 0,
      autoNegativeMemoryFragmentCount: 0,
      observationNoteChars: 0,
      roleAnchorCount: 0,
      sceneAnchorCount: 0,
      toolAnchorCount: 0,
      styleAnchorCount: 0,
      memoryStyleAnchorCount: 0,
      memoryDeliveryAnchorCount: 0,
      memoryDeliveryPriorityApplied: false,
      memoryStyleChars: 0,
      memoryVisualChars: 0,
      memoryDeliveryChars: 0,
      memoryHitBuckets: [],
      memorySuppressedBuckets: [],
      continuityNoteCount: 0,
      continuityNoteChars: 0,
      usesReferenceFrame: false,
      memoryBudgetTier: 'lean',
    );

    expect(
      buildStoryboardVideoPromptAnchorSummary(diagnostics),
      '当前提示词未命中额外锚点或记忆。',
    );
    expect(
      buildStoryboardVideoPromptBudgetHint(diagnostics),
      '当前提示词未绑定当前画面，先补参考帧再继续压缩，更稳。',
    );
  });

  test('buildStoryboardVideoPromptBudgetHint warns about bloated prompt', () {
    const diagnostics = GenerateVideoPromptDiagnostics(
      promptChars: 548,
      negativePromptChars: 70,
      negativeConstraintCount: 2,
      negativeBudgetTier: 'expanded',
      autoNegativeSource: null,
      autoNegativeReviewFragmentCount: 0,
      autoNegativeMemoryFragmentCount: 0,
      observationNoteChars: 20,
      roleAnchorCount: 1,
      sceneAnchorCount: 2,
      toolAnchorCount: 1,
      styleAnchorCount: 2,
      memoryStyleAnchorCount: 1,
      memoryDeliveryAnchorCount: 0,
      memoryDeliveryPriorityApplied: false,
      memoryStyleChars: 44,
      memoryVisualChars: 44,
      memoryDeliveryChars: 0,
      memoryHitBuckets: [],
      memorySuppressedBuckets: [],
      continuityNoteCount: 1,
      continuityNoteChars: 18,
      usesReferenceFrame: true,
      memoryBudgetTier: 'expanded',
    );

    expect(
      buildStoryboardVideoPromptBudgetHint(diagnostics),
      '当前提示词偏长，优先删重复场景/风格描述，先别动角色和关键道具锚点。',
    );
  });

  test(
    'buildStoryboardVideoPromptBudgetHint prefers anchor warning before extra trimming',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 220,
        negativePromptChars: 0,
        negativeConstraintCount: 0,
        negativeBudgetTier: 'lean',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 0,
        sceneAnchorCount: 0,
        toolAnchorCount: 0,
        styleAnchorCount: 0,
        memoryStyleAnchorCount: 0,
        memoryDeliveryAnchorCount: 0,
        memoryDeliveryPriorityApplied: false,
        memoryStyleChars: 0,
        memoryVisualChars: 0,
        memoryDeliveryChars: 0,
        memoryHitBuckets: [],
        memorySuppressedBuckets: [],
        continuityNoteCount: 0,
        continuityNoteChars: 0,
        usesReferenceFrame: true,
        memoryBudgetTier: 'lean',
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '当前提示词主要依赖分镜文案，缺少角色/场景锚点，画面更容易漂。',
      );
    },
  );

  test(
    'buildStoryboardVideoPromptBudgetHint confirms healthy prompt budget',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 260,
        negativePromptChars: 36,
        negativeConstraintCount: 1,
        negativeBudgetTier: 'lean',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 18,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 1,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 1,
        memoryDeliveryAnchorCount: 0,
        memoryDeliveryPriorityApplied: false,
        memoryStyleChars: 32,
        memoryVisualChars: 32,
        memoryDeliveryChars: 0,
        memoryHitBuckets: [],
        memorySuppressedBuckets: [],
        continuityNoteCount: 1,
        continuityNoteChars: 20,
        usesReferenceFrame: true,
        memoryBudgetTier: 'lean',
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '当前提示词预算仍可控，可继续优先保留人物表演、关键道具和情绪信息。',
      );
    },
  );

  test(
    'buildStoryboardVideoPromptBudgetHint warns when private memory gets heavy',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 412,
        negativePromptChars: 28,
        negativeConstraintCount: 2,
        negativeBudgetTier: 'expanded',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 0,
        styleAnchorCount: 2,
        memoryStyleAnchorCount: 2,
        memoryDeliveryAnchorCount: 1,
        memoryDeliveryPriorityApplied: true,
        memoryStyleChars: 64,
        memoryVisualChars: 28,
        memoryDeliveryChars: 36,
        memoryHitBuckets: [],
        memorySuppressedBuckets: [],
        continuityNoteCount: 1,
        continuityNoteChars: 22,
        usesReferenceFrame: true,
        memoryBudgetTier: 'expanded',
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '已命中表演/语气优先记忆，先别删这段；优先压缩重复的场景/风格与连续性泛句，避免又回到“读稿腔”。',
      );
    },
  );

  test(
    'buildStoryboardVideoPromptBudgetHint keeps trimming repeated suppressed bucket before delivery memory',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 426,
        negativePromptChars: 24,
        negativeConstraintCount: 1,
        negativeBudgetTier: 'lean',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 0,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 2,
        memoryDeliveryAnchorCount: 1,
        memoryDeliveryPriorityApplied: false,
        memoryStyleChars: 58,
        memoryVisualChars: 26,
        memoryDeliveryChars: 18,
        memoryHitBuckets: ['表演'],
        memorySuppressedBuckets: ['动作'],
        memorySuppressedBucketCounts: {'动作': 3},
        continuityNoteCount: 1,
        continuityNoteChars: 16,
        usesReferenceFrame: true,
        memoryBudgetTier: 'expanded',
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '当前私有记忆里已压掉较多动作类重复片段，继续先收这类泛句，别先删角色表演记忆。',
      );
    },
  );

  test(
    'buildStoryboardVideoPromptRepairSuggestions prioritizes reference frame and delivery memory',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 436,
        negativePromptChars: 48,
        negativeConstraintCount: 2,
        negativeBudgetTier: 'expanded',
        autoNegativeSource: 'review+rejected_memory',
        autoNegativeReviewFragmentCount: 2,
        autoNegativeMemoryFragmentCount: 3,
        observationNoteChars: 16,
        roleAnchorCount: 1,
        sceneAnchorCount: 0,
        toolAnchorCount: 0,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 2,
        memoryDeliveryAnchorCount: 1,
        memoryDeliveryPriorityApplied: true,
        memoryStyleChars: 88,
        memoryVisualChars: 40,
        memoryDeliveryChars: 32,
        memoryHitBuckets: ['表演'],
        memorySuppressedBuckets: ['动作'],
        memoryHitBucketCounts: {'表演': 2},
        memorySuppressedBucketCounts: {'动作': 3},
        continuityNoteCount: 1,
        continuityNoteChars: 32,
        usesReferenceFrame: false,
        memoryBudgetTier: 'expanded',
      );

      expect(buildStoryboardVideoPromptRepairSuggestions(diagnostics), [
        '先补当前参考帧，再压词；人物脸、服化道和站位会更稳。',
        '保留表演/语气记忆，把情绪写成可演动作，别退回成读稿腔。',
        '优先删动作/光影泛句，把预算让给口型、微表情和人物一致性。',
        '沿用自动坏例负向约束，手动补词前先去重，避免同义词重复烧 token。',
        '这次已经命中项目/剧本私有坏例记忆，先复用它，别再堆一层共享长记忆。',
      ]);
    },
  );

  test(
    'buildStoryboardVideoPromptRepairSuggestions falls back to healthy guidance',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 260,
        negativePromptChars: 0,
        negativeConstraintCount: 0,
        negativeBudgetTier: 'lean',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 1,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 1,
        memoryDeliveryAnchorCount: 0,
        memoryDeliveryPriorityApplied: false,
        memoryStyleChars: 24,
        memoryVisualChars: 24,
        memoryDeliveryChars: 0,
        memoryHitBuckets: [],
        memorySuppressedBuckets: [],
        continuityNoteCount: 0,
        continuityNoteChars: 0,
        usesReferenceFrame: true,
        memoryBudgetTier: 'lean',
      );

      expect(buildStoryboardVideoPromptRepairSuggestions(diagnostics), [
        '当前预算可控，继续保留人物表演、关键道具和情绪细节。',
      ]);
    },
  );

  test(
    'applyStoryboardVideoPromptRepairs trims duplicate generic prompt fragments and repeated negative constraints',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 540,
        negativePromptChars: 44,
        negativeConstraintCount: 2,
        negativeBudgetTier: 'expanded',
        autoNegativeSource: 'review+rejected_memory',
        autoNegativeReviewFragmentCount: 1,
        autoNegativeMemoryFragmentCount: 2,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 0,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 2,
        memoryDeliveryAnchorCount: 1,
        memoryDeliveryPriorityApplied: true,
        memoryStyleChars: 104,
        memoryVisualChars: 48,
        memoryDeliveryChars: 28,
        memoryHitBuckets: ['表演'],
        memorySuppressedBuckets: ['动作'],
        memoryHitBucketCounts: {'表演': 2},
        memorySuppressedBucketCounts: {'动作': 3},
        continuityNoteCount: 1,
        continuityNoteChars: 24,
        usesReferenceFrame: true,
        memoryBudgetTier: 'expanded',
      );

      final repaired = applyStoryboardVideoPromptRepairs(
        diagnostics: diagnostics,
        prompt: '人物压着怒意盯住对手，镜头缓慢跟拍，光影层次丰富，镜头缓慢跟拍，微表情压着爆发前的停顿',
        negativePrompt:
            'avoid blur, avoid blank expression, avoid face distortion',
        automaticNegativePrompt:
            'avoid blur, avoid face distortion or identity drift',
      );

      expect(repaired.prompt, '人物压着怒意盯住对手，微表情压着爆发前的停顿');
      expect(repaired.negativePrompt, 'avoid blank expression');
      expect(repaired.removedPromptFragmentCount, 3);
      expect(repaired.removedNegativeFragmentCount, 2);
      expect(repaired.changed, isTrue);
    },
  );

  test(
    'applyStoryboardVideoPromptRepairs preserves performance-heavy prompt fragments when budget is healthy',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 280,
        negativePromptChars: 0,
        negativeConstraintCount: 0,
        negativeBudgetTier: 'lean',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 0,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 1,
        memoryDeliveryAnchorCount: 1,
        memoryDeliveryPriorityApplied: true,
        memoryStyleChars: 40,
        memoryVisualChars: 20,
        memoryDeliveryChars: 24,
        memoryHitBuckets: ['表演'],
        memorySuppressedBuckets: [],
        continuityNoteCount: 0,
        continuityNoteChars: 0,
        usesReferenceFrame: true,
        memoryBudgetTier: 'lean',
      );

      final repaired = applyStoryboardVideoPromptRepairs(
        diagnostics: diagnostics,
        prompt: '人物强忍眼泪开口，短暂停顿后继续说完台词',
        negativePrompt: '',
      );

      expect(repaired.prompt, '人物强忍眼泪开口，短暂停顿后继续说完台词');
      expect(repaired.negativePrompt, '');
      expect(repaired.removedPromptFragmentCount, 0);
      expect(repaired.removedNegativeFragmentCount, 0);
      expect(repaired.changed, isFalse);
    },
  );

  test(
    'buildStoryboardVideoPromptBudgetHint preserves expanded memory on risky shots',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 340,
        negativePromptChars: 18,
        negativeConstraintCount: 3,
        negativeBudgetTier: 'expanded',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 0,
        styleAnchorCount: 2,
        memoryStyleAnchorCount: 1,
        memoryDeliveryAnchorCount: 0,
        memoryDeliveryPriorityApplied: false,
        memoryStyleChars: 28,
        memoryVisualChars: 28,
        memoryDeliveryChars: 0,
        memoryHitBuckets: [],
        memorySuppressedBuckets: [],
        continuityNoteCount: 1,
        continuityNoteChars: 26,
        usesReferenceFrame: true,
        memoryBudgetTier: 'expanded',
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '当前镜头被判定为高风险，先保留角色表演和连续性记忆，再压其他泛化描述。',
      );
    },
  );

  test(
    'buildStoryboardVideoPromptBudgetHint warns before trimming expanded negative constraints',
    () {
      const diagnostics = GenerateVideoPromptDiagnostics(
        promptChars: 310,
        negativePromptChars: 62,
        negativeConstraintCount: 3,
        negativeBudgetTier: 'expanded',
        autoNegativeSource: null,
        autoNegativeReviewFragmentCount: 0,
        autoNegativeMemoryFragmentCount: 0,
        observationNoteChars: 0,
        roleAnchorCount: 1,
        sceneAnchorCount: 1,
        toolAnchorCount: 0,
        styleAnchorCount: 1,
        memoryStyleAnchorCount: 0,
        memoryDeliveryAnchorCount: 0,
        memoryDeliveryPriorityApplied: false,
        memoryStyleChars: 0,
        memoryVisualChars: 0,
        memoryDeliveryChars: 0,
        memoryHitBuckets: [],
        memorySuppressedBuckets: [],
        continuityNoteCount: 0,
        continuityNoteChars: 0,
        usesReferenceFrame: true,
        memoryBudgetTier: 'lean',
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '当前镜头的防穿帮约束已切到 expanded，先保留人物一致性和镜头连续性，再压泛化负面词。',
      );
    },
  );

  test('resolveStoryboardNarrationText prefers script narration first', () {
    final narration = resolveStoryboardNarrationText(
      scriptStoryboard: const StoryboardRow(
        id: '1',
        numericId: 11,
        scriptId: '3',
        videoDesc: '脚本旁白',
      ),
      productionStoryboard: const ProductionStoryboardItemV1(
        id: 11,
        videoDesc: '制作旁白',
      ),
    );

    expect(narration, '脚本旁白');
  });

  test(
    'resolveStoryboardNarrationSource prefers explicit narration before prompt fallback',
    () {
      final source = resolveStoryboardNarrationSource(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头提示词',
          videoDesc: '旁白台词',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(id: 11),
      );

      expect(source, StoryboardNarrationSource.explicitNarration);
      expect(describeStoryboardNarrationSource(source), '已具备显式旁白文案');
    },
  );

  test(
    'resolveStoryboardNarrationSource falls back to prompt when narration is absent',
    () {
      final source = resolveStoryboardNarrationSource(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头提示词',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(id: 11),
      );

      expect(source, StoryboardNarrationSource.promptFallback);
      expect(describeStoryboardNarrationSource(source), '将回退到分镜提示词');
    },
  );

  test(
    'resolveStoryboardNarrationSource reports placeholder when both narration and prompt are absent',
    () {
      final source = resolveStoryboardNarrationSource(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(id: 11),
      );

      expect(source, StoryboardNarrationSource.placeholder);
      expect(describeStoryboardNarrationSource(source), '仍是占位文本');
    },
  );

  test(
    'resolveStoryboardVideoPromptSeed falls back to prompt when narration is absent',
    () {
      final prompt = resolveStoryboardVideoPromptSeed(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头一提示词',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(id: 11),
      );

      expect(prompt, '镜头一提示词');
    },
  );

  test(
    'resolveStoryboardVideoPromptSeed prefers narration over prompt for video generation',
    () {
      final prompt = resolveStoryboardVideoPromptSeed(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头一提示词',
          videoDesc: '旁白：主角抬头看向远方',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(
          id: 11,
          prompt: '制作提示词',
        ),
      );

      expect(prompt, '旁白：主角抬头看向远方');
    },
  );

  test(
    'buildStoryboardVideoPromptRequest prefers draft narration and draft duration',
    () {
      final request = buildStoryboardVideoPromptRequest(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '脚本提示词',
          videoDesc: '脚本旁白',
          duration: '4s',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(
          id: 11,
          prompt: '制作提示词',
          videoDesc: '制作旁白',
          duration: '6',
        ),
        draftNarration: '临时改成新的旁白',
        draftPrompt: '临时提示词',
        draftDuration: '8 秒',
      );

      expect(request.description, '临时改成新的旁白');
      expect(request.durationSeconds, 8);
    },
  );

  test(
    'buildStoryboardVideoPromptRequest falls back to prompt and persisted duration',
    () {
      final request = buildStoryboardVideoPromptRequest(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '脚本提示词',
          duration: '4s',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(
          id: 11,
          prompt: '制作提示词',
          duration: '6',
        ),
        draftNarration: ' ',
        draftPrompt: ' ',
        draftDuration: '',
      );

      expect(request.description, '脚本提示词');
      expect(request.durationSeconds, 4);
    },
  );

  test(
    'diagnoseStoryboardWorkbench prefers refreshing when jobs or videos already exist',
    () {
      final withJobs = diagnoseStoryboardWorkbench(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头一',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(
          id: 11,
          url: 'https://example.com/frame.png',
        ),
        productionStoryboards: const [ProductionStoryboardItemV1(id: 11)],
        generatedVideos: const [],
        generatingJobs: const [
          JobRow(
            numericTaskId: 1,
            id: 'job-1',
            ownerUserId: 'u',
            kind: 'video',
            status: 'running',
            payload: {},
            createdAt: '2026-04-10T10:00:00Z',
            updatedAt: '2026-04-10T10:01:00Z',
          ),
        ],
        draftImageUrl: null,
        trackIdText: '7',
        videoPromptText: 'prompt',
        videoDurationText: '5',
      );

      final withVideos = diagnoseStoryboardWorkbench(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头一',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(
          id: 11,
          url: 'https://example.com/frame.png',
        ),
        productionStoryboards: const [ProductionStoryboardItemV1(id: 11)],
        generatedVideos: const [
          VideoItem(id: 11, videoUrl: 'https://example.com/video.mp4'),
        ],
        generatingJobs: const [],
        draftImageUrl: null,
        trackIdText: '7',
        videoPromptText: 'prompt',
        videoDurationText: '5',
      );

      expect(
        withJobs.recommendedAction,
        StoryboardWorkbenchRecommendedAction.refreshVideoData,
      );
      expect(
        withVideos.recommendedAction,
        StoryboardWorkbenchRecommendedAction.refreshVideoData,
      );
    },
  );

  test('buildStoryboardWorkbenchFollowUp appends the recommended action', () {
    final line = buildStoryboardWorkbenchFollowUp(
      actionSummary: '已读取当前分镜预览。',
      diagnosis: diagnoseStoryboardWorkbench(
        scriptStoryboard: const StoryboardRow(
          id: '1',
          numericId: 11,
          scriptId: '3',
          prompt: '镜头一',
        ),
        productionStoryboard: const ProductionStoryboardItemV1(
          id: 11,
          url: 'https://example.com/frame.png',
        ),
        productionStoryboards: const [ProductionStoryboardItemV1(id: 11)],
        generatedVideos: const [],
        generatingJobs: const [],
        draftImageUrl: null,
        trackIdText: '7',
        videoPromptText: 'prompt',
        videoDurationText: '5',
      ),
    );

    expect(line, contains('下一步建议：一键生成视频。'));
  });

  test('buildStoryboardWorkbenchFailureNotice normalizes rust api errors', () {
    final line = buildStoryboardWorkbenchFailureNotice(
      actionSummary: '刷新当前分镜的视频数据失败。',
      recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
      error: 'RustApiException(503): database_error',
      fallbackDetail: '可稍后重试。',
    );

    expect(line, contains('下一步建议：刷新视频数据。'));
    expect(line, contains('失败原因：database_error。'));
  });

  test('buildStoryboardWorkbenchLoadingNotice appends detail text', () {
    final line = buildStoryboardWorkbenchLoadingNotice(
      actionSummary: '正在同步当前分镜制作数据。',
      recommendedAction:
          StoryboardWorkbenchRecommendedAction.syncProductionData,
      detail: '同步完成后会自动回填当前画面。',
    );

    expect(line, contains('下一步建议：同步当前分镜数据。'));
    expect(line, contains('同步完成后会自动回填当前画面。'));
  });

  test('collectStoryboardTrackIds merges and sorts known track ids', () {
    final ids = collectStoryboardTrackIds(
      scriptStoryboard: const StoryboardRow(
        id: '1',
        numericId: 11,
        scriptId: '3',
        prompt: 'p',
        trackId: 4,
      ),
      productionStoryboard: const ProductionStoryboardItemV1(
        id: 11,
        trackId: 2,
      ),
      productionStoryboards: const [
        ProductionStoryboardItemV1(id: 12, trackId: 6),
        ProductionStoryboardItemV1(id: 13, trackId: 4),
      ],
      generatedVideos: const [
        VideoItem(id: 11, trackId: 8),
        VideoItem(id: 12, trackId: 2),
      ],
    );

    expect(ids, [2, 4, 6, 8]);
  });

  test(
    'storyboardScopedVideos keeps current storyboard and sorts newest first',
    () {
      final videos = storyboardScopedVideos([
        VideoItem(
          id: 7,
          videoUrl: 'https://example.com/older.mp4',
          createdAt: DateTime.parse('2026-04-08T10:00:00Z'),
        ),
        VideoItem(
          id: 9,
          videoUrl: 'https://example.com/other.mp4',
          createdAt: DateTime.parse('2026-04-09T10:00:00Z'),
        ),
        VideoItem(
          id: 7,
          videoUrl: 'https://example.com/newer.mp4',
          createdAt: DateTime.parse('2026-04-09T11:00:00Z'),
        ),
      ], 7);

      expect(videos.map((video) => video.videoUrl).toList(), [
        'https://example.com/newer.mp4',
        'https://example.com/older.mp4',
      ]);
    },
  );

  test(
    'resolveStoryboardSourceImageUrl prefers draft url then production url',
    () {
      expect(
        resolveStoryboardSourceImageUrl(
          productionStoryboard: const ProductionStoryboardItemV1(
            id: 1,
            url: 'https://example.com/current.png',
          ),
          draftImageUrl: ' https://example.com/draft.png ',
        ),
        'https://example.com/draft.png',
      );

      expect(
        resolveStoryboardSourceImageUrl(
          productionStoryboard: const ProductionStoryboardItemV1(
            id: 1,
            url: 'https://example.com/current.png',
          ),
          draftImageUrl: '  ',
        ),
        'https://example.com/current.png',
      );
    },
  );

  test(
    'resolveStoryboardGenerationPrompt prefers script prompt then production prompt',
    () {
      expect(
        resolveStoryboardGenerationPrompt(
          scriptStoryboard: const StoryboardRow(
            id: '1',
            numericId: 11,
            scriptId: '3',
            prompt: ' script prompt ',
          ),
          productionStoryboard: const ProductionStoryboardItemV1(
            id: 11,
            prompt: 'production prompt',
          ),
        ),
        'script prompt',
      );

      expect(
        resolveStoryboardGenerationPrompt(
          scriptStoryboard: const StoryboardRow(
            id: '1',
            numericId: 11,
            scriptId: '3',
            prompt: '   ',
          ),
          productionStoryboard: const ProductionStoryboardItemV1(
            id: 11,
            prompt: ' production prompt ',
          ),
        ),
        'production prompt',
      );
    },
  );
}
