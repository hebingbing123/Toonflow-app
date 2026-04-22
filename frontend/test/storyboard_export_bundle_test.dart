import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/storyboard_editor/support.dart';

void main() {
  test('buildStoryboardExportBundleSummary reports sidecars and duration', () {
    final summary = buildStoryboardExportBundleSummary(
      selectedIds: const [9, 7, 9],
      boards: const [
        StoryboardRow(
          id: 'sb-7',
          scriptId: 'sc-1',
          numericId: 7,
          duration: '4',
        ),
        StoryboardRow(
          id: 'sb-9',
          scriptId: 'sc-1',
          numericId: 9,
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
    expect(summary.sidecarFileCount, 4);
    expect(summary.estimatedEntryCount, 6);
    expect(summary.totalDurationSeconds, 14);
    expect(summary.totalDurationLabel, '14s');
    expect(summary.byteLength, 2048);
    expect(summary.includesTimeline, isTrue);
    expect(summary.includesSubtitles, isTrue);
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
      zip: ProductionExportZipResponse(filename: null, bytes: Uint8List(10)),
    );

    expect(summary.filename, 'storyboards.zip');
    expect(summary.totalDurationSeconds, 5);
    expect(summary.totalDurationLabel, '5s');
  });
}
