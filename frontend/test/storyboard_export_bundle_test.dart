import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/storyboard_editor/support.dart';

void main() {
  test('ProductionStoryboardItemV1 parses videoDesc payload', () {
    final item = ProductionStoryboardItemV1.fromJson(const {
      'id': 7,
      'prompt': '镜头提示词',
      'videoDesc': '旁白台词',
      'duration': '5',
    });

    expect(item.id, 7);
    expect(item.prompt, '镜头提示词');
    expect(item.videoDesc, '旁白台词');
    expect(item.duration, '5');
  });

  test('buildStoryboardExportBundleSummary reports sidecars and duration', () {
    final summary = buildStoryboardExportBundleSummary(
      selectedIds: const [9, 7, 9],
      boards: const [
        StoryboardRow(
          id: 'sb-7',
          scriptId: 'sc-1',
          numericId: 7,
          duration: '4',
          videoDesc: '旁白：镜头七',
        ),
        StoryboardRow(
          id: 'sb-9',
          scriptId: 'sc-1',
          numericId: 9,
          prompt: '镜头九提示词',
          duration: '8',
        ),
      ],
      productionRows: const [ProductionStoryboardItemV1(id: 7, duration: '6')],
      zip: ProductionExportZipResponse(
        filename: 'toonflow-storyboards.zip',
        bytes: Uint8List(2048),
      ),
    );

    expect(summary.filename, 'toonflow-storyboards.zip');
    expect(summary.shotIds, const [7, 9]);
    expect(summary.shotCount, 2);
    expect(summary.imageFileCount, 2);
    expect(summary.sidecarFileCount, 6);
    expect(summary.estimatedEntryCount, 8);
    expect(summary.totalDurationSeconds, 14);
    expect(summary.totalDurationLabel, '14s');
    expect(summary.explicitSubtitleCount, 1);
    expect(summary.promptFallbackSubtitleCount, 1);
    expect(summary.placeholderSubtitleCount, 0);
    expect(summary.subtitleCoverageLabel, '字幕来源：1 条旁白文案 / 1 条提示词回退 / 0 条占位文本');
    expect(summary.voiceoverCoverageLabel, '旁白脚本：2 条可用文案 / 0 条占位文案');
    expect(summary.audioDeliveryLabel, '音频交付：2 条可直接配音 / 0 条仍是占位文本');
    expect(summary.voiceoverJsonLabel, '配音 JSON：2 条可直接投喂 / 0 条仍需补文案');
    expect(summary.byteLength, 2048);
    expect(summary.includesTimeline, isTrue);
    expect(summary.includesSubtitles, isTrue);
    expect(summary.includesVoiceoverScript, isTrue);
    expect(summary.includesVoiceoverSegments, isTrue);
  });

  test('buildStoryboardExportBundleSummary falls back to default duration', () {
    final summary = buildStoryboardExportBundleSummary(
      selectedIds: const [5],
      boards: const [
        StoryboardRow(
          id: 'sb-5',
          scriptId: 'sc-1',
          numericId: 5,
          duration: '0',
        ),
      ],
      productionRows: const [],
    );

    expect(summary.filename, 'storyboards.zip');
    expect(summary.totalDurationSeconds, 5);
    expect(summary.totalDurationLabel, '5s');
    expect(summary.explicitSubtitleCount, 0);
    expect(summary.promptFallbackSubtitleCount, 0);
    expect(summary.placeholderSubtitleCount, 1);
    expect(summary.voiceoverCoverageLabel, '旁白脚本：0 条可用文案 / 1 条占位文案');
    expect(summary.audioDeliveryLabel, '音频交付：0 条可直接配音 / 1 条仍是占位文本');
    expect(summary.voiceoverJsonLabel, '配音 JSON：0 条可直接投喂 / 1 条仍需补文案');
    expect(summary.byteLength, isNull);
  });
}
