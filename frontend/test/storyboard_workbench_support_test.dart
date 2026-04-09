import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/storyboard_workbench_support.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  test('collectStoryboardTrackIds merges and sorts known track ids', () {
    final ids = collectStoryboardTrackIds(
      scriptStoryboard: const StoryboardRow(
        id: '1',
        legacyId: 11,
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
            legacyId: 11,
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
            legacyId: 11,
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
