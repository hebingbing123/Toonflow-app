part of 'diagnosis.dart';

const int _defaultStoryboardDurationSeconds = 5;
const int _storyboardExportSidecarCount = 4;

class StoryboardExportBundleSummary {
  const StoryboardExportBundleSummary({
    required this.filename,
    required this.shotIds,
    required this.imageFileCount,
    required this.sidecarFileCount,
    required this.totalDurationSeconds,
    this.byteLength,
  });

  final String filename;
  final List<int> shotIds;
  final int imageFileCount;
  final int sidecarFileCount;
  final int totalDurationSeconds;
  final int? byteLength;

  int get shotCount => shotIds.length;
  int get estimatedEntryCount => imageFileCount + sidecarFileCount;
  bool get includesManifest => true;
  bool get includesStoryboardCsv => true;
  bool get includesTimeline => true;
  bool get includesSubtitles => true;

  String get totalDurationLabel {
    final minutes = totalDurationSeconds ~/ 60;
    final seconds = totalDurationSeconds % 60;
    if (minutes == 0) {
      return '${seconds}s';
    }
    if (seconds == 0) {
      return '${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  String get sidecarLabel =>
      'manifest.json / storyboard.csv / timeline.json / subtitles.srt';
}

StoryboardExportBundleSummary buildStoryboardExportBundleSummary({
  required Iterable<int> selectedIds,
  required Iterable<StoryboardRow> boards,
  required Iterable<ProductionStoryboardItemV1> productionRows,
  ProductionExportZipResponse? zip,
}) {
  final sortedShotIds = selectedIds.toSet().toList()..sort();
  final boardById = <int, StoryboardRow>{
    for (final row in boards) row.numericId: row,
  };
  final productionById = <int, ProductionStoryboardItemV1>{
    for (final row in productionRows) row.id: row,
  };

  var totalDurationSeconds = 0;
  for (final id in sortedShotIds) {
    final productionDuration = productionById[id]?.duration;
    final boardDuration = boardById[id]?.duration;
    totalDurationSeconds += _parseStoryboardDurationSeconds(
      productionDuration ?? boardDuration,
    );
  }

  return StoryboardExportBundleSummary(
    filename: zip?.filename ?? 'storyboards.zip',
    shotIds: sortedShotIds,
    imageFileCount: sortedShotIds.length,
    sidecarFileCount: _storyboardExportSidecarCount,
    totalDurationSeconds: totalDurationSeconds,
    byteLength: zip?.bytes.length,
  );
}

int _parseStoryboardDurationSeconds(String? raw) {
  final duration = int.tryParse((raw ?? '').trim());
  if (duration == null || duration <= 0) {
    return _defaultStoryboardDurationSeconds;
  }
  return duration;
}
