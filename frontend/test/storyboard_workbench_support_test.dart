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
        StoryboardBatchWorkbenchRecommendedAction.selectReadyStoryboards,
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

      expect(line, contains('下一步建议：批量发起出图。'));
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
      memoryStyleChars: 36,
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
      memoryStyleChars: 0,
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
      memoryStyleChars: 44,
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
        memoryStyleChars: 0,
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
        memoryStyleChars: 32,
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
        memoryStyleChars: 64,
        continuityNoteCount: 1,
        continuityNoteChars: 22,
        usesReferenceFrame: true,
        memoryBudgetTier: 'expanded',
      );

      expect(
        buildStoryboardVideoPromptBudgetHint(diagnostics),
        '当前提示词里的私有记忆占比已经不低，优先合并泛化风格句，别先删角色表演记忆。',
      );
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
        memoryStyleChars: 28,
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
        memoryStyleChars: 0,
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

    expect(line, contains('下一步建议：提交视频生成。'));
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
