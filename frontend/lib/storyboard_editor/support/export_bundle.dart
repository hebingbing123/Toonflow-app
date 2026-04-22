part of 'diagnosis.dart';

const int _defaultStoryboardDurationSeconds = 5;
const int _storyboardExportSidecarCount = 6;

class StoryboardExportBundleSummary {
  const StoryboardExportBundleSummary({
    required this.filename,
    required this.shotIds,
    required this.imageFileCount,
    required this.sidecarFileCount,
    required this.totalDurationSeconds,
    required this.explicitSubtitleCount,
    required this.promptFallbackSubtitleCount,
    required this.placeholderSubtitleCount,
    this.byteLength,
  });

  final String filename;
  final List<int> shotIds;
  final int imageFileCount;
  final int sidecarFileCount;
  final int totalDurationSeconds;
  final int explicitSubtitleCount;
  final int promptFallbackSubtitleCount;
  final int placeholderSubtitleCount;
  final int? byteLength;

  int get shotCount => shotIds.length;
  int get estimatedEntryCount => imageFileCount + sidecarFileCount;
  bool get includesManifest => true;
  bool get includesStoryboardCsv => true;
  bool get includesTimeline => true;
  bool get includesSubtitles => true;
  bool get includesVoiceoverScript => true;
  bool get includesVoiceoverSegments => true;

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
      'manifest.json / storyboard.csv / timeline.json / subtitles.srt / voiceover_script.txt / voiceover_segments.json';

  String get subtitleCoverageLabel =>
      '字幕来源：$explicitSubtitleCount 条旁白文案'
      ' / $promptFallbackSubtitleCount 条提示词回退'
      ' / $placeholderSubtitleCount 条占位文本';

  String get voiceoverCoverageLabel {
    final scriptedVoiceoverCount =
        explicitSubtitleCount + promptFallbackSubtitleCount;
    return '旁白脚本：$scriptedVoiceoverCount 条可用文案 / '
        '$placeholderSubtitleCount 条占位文案';
  }

  String get audioDeliveryLabel {
    final readyCount = explicitSubtitleCount + promptFallbackSubtitleCount;
    return '音频交付：$readyCount 条可直接配音 / '
        '$placeholderSubtitleCount 条仍是占位文本';
  }

  String get voiceoverJsonLabel {
    final readyCount = explicitSubtitleCount + promptFallbackSubtitleCount;
    return '配音 JSON：$readyCount 条可直接投喂 / '
        '$placeholderSubtitleCount 条仍需补文案';
  }
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
  var explicitSubtitleCount = 0;
  var promptFallbackSubtitleCount = 0;
  var placeholderSubtitleCount = 0;
  for (final id in sortedShotIds) {
    final productionRow = productionById[id];
    final boardRow = boardById[id];
    final productionDuration = productionRow?.duration;
    final boardDuration = boardById[id]?.duration;
    totalDurationSeconds += _parseStoryboardDurationSeconds(
      productionDuration ?? boardDuration,
    );
    final narration = resolveStoryboardNarrationText(
      scriptStoryboard: boardRow,
      productionStoryboard: productionRow,
    );
    if (narration != null && narration.isNotEmpty) {
      explicitSubtitleCount += 1;
      continue;
    }
    final prompt = resolveStoryboardGenerationPrompt(
      scriptStoryboard: boardRow,
      productionStoryboard: productionRow,
    );
    if (prompt != null && prompt.isNotEmpty) {
      promptFallbackSubtitleCount += 1;
      continue;
    }
    placeholderSubtitleCount += 1;
  }

  return StoryboardExportBundleSummary(
    filename: zip?.filename ?? 'storyboards.zip',
    shotIds: sortedShotIds,
    imageFileCount: sortedShotIds.length,
    sidecarFileCount: _storyboardExportSidecarCount,
    totalDurationSeconds: totalDurationSeconds,
    explicitSubtitleCount: explicitSubtitleCount,
    promptFallbackSubtitleCount: promptFallbackSubtitleCount,
    placeholderSubtitleCount: placeholderSubtitleCount,
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
