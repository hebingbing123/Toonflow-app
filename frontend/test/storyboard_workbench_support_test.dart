import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/storyboard_editor/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
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
      recommendedAction: StoryboardWorkbenchRecommendedAction.syncProductionData,
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
