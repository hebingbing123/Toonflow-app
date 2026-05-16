import 'dart:collection';

import 'package:openflow_app/l10n/app_localizations.dart';

import '../../../rust_api.dart';

enum StoryboardNarrationSource {
  explicitNarration,
  promptFallback,
  placeholder,
}

class StoryboardVideoPromptRequest {
  const StoryboardVideoPromptRequest({
    required this.description,
    required this.durationSeconds,
  });

  final String? description;
  final int? durationSeconds;
}

List<int> collectStoryboardTrackIds({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  Iterable<ProductionStoryboardItemV1> productionStoryboards = const [],
  Iterable<VideoItem> generatedVideos = const [],
}) {
  final trackIds = SplayTreeSet<int>();

  void addTrackId(int? trackId) {
    if (trackId != null && trackId > 0) {
      trackIds.add(trackId);
    }
  }

  addTrackId(scriptStoryboard?.trackId);
  addTrackId(productionStoryboard?.trackId);
  for (final row in productionStoryboards) {
    addTrackId(row.trackId);
  }
  for (final video in generatedVideos) {
    addTrackId(video.trackId);
  }
  return trackIds.toList(growable: false);
}

List<VideoItem> storyboardScopedVideos(
  Iterable<VideoItem> videos,
  int storyboardId,
) {
  final scoped = videos.where((video) => video.id == storyboardId).toList();
  scoped.sort((a, b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return scoped;
}

String? resolveStoryboardSourceImageUrl({
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftImageUrl,
}) {
  final draft = draftImageUrl?.trim();
  if (draft != null && draft.isNotEmpty) {
    return draft;
  }
  final current = productionStoryboard?.url?.trim();
  if (current == null || current.isEmpty) {
    return null;
  }
  return current;
}

String? resolveStoryboardGenerationPrompt({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftPrompt,
}) {
  final rawDraftPrompt = draftPrompt?.trim();
  if (rawDraftPrompt != null && rawDraftPrompt.isNotEmpty) {
    return rawDraftPrompt;
  }
  final scriptPrompt = scriptStoryboard?.prompt?.trim();
  if (scriptPrompt != null && scriptPrompt.isNotEmpty) {
    return scriptPrompt;
  }
  final productionPrompt = productionStoryboard?.prompt?.trim();
  if (productionPrompt != null && productionPrompt.isNotEmpty) {
    return productionPrompt;
  }
  return null;
}

String? resolveStoryboardNarrationText({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftNarration,
}) {
  final rawDraftNarration = draftNarration?.trim();
  if (rawDraftNarration != null && rawDraftNarration.isNotEmpty) {
    return rawDraftNarration;
  }
  final scriptNarration = scriptStoryboard?.videoDesc?.trim();
  if (scriptNarration != null && scriptNarration.isNotEmpty) {
    return scriptNarration;
  }
  final productionNarration = productionStoryboard?.videoDesc?.trim();
  if (productionNarration != null && productionNarration.isNotEmpty) {
    return productionNarration;
  }
  return null;
}

String? resolveStoryboardVideoPromptSeed({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftNarration,
  String? draftPrompt,
}) {
  final narration = resolveStoryboardNarrationText(
    scriptStoryboard: scriptStoryboard,
    productionStoryboard: productionStoryboard,
    draftNarration: draftNarration,
  );
  if (narration != null && narration.isNotEmpty) {
    return narration;
  }
  return resolveStoryboardGenerationPrompt(
    scriptStoryboard: scriptStoryboard,
    productionStoryboard: productionStoryboard,
    draftPrompt: draftPrompt,
  );
}

StoryboardNarrationSource resolveStoryboardNarrationSource({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftNarration,
  String? draftPrompt,
}) {
  final narration = resolveStoryboardNarrationText(
    scriptStoryboard: scriptStoryboard,
    productionStoryboard: productionStoryboard,
    draftNarration: draftNarration,
  );
  if (narration != null && narration.isNotEmpty) {
    return StoryboardNarrationSource.explicitNarration;
  }
  final prompt = resolveStoryboardGenerationPrompt(
    scriptStoryboard: scriptStoryboard,
    productionStoryboard: productionStoryboard,
    draftPrompt: draftPrompt,
  );
  if (prompt != null && prompt.isNotEmpty) {
    return StoryboardNarrationSource.promptFallback;
  }
  return StoryboardNarrationSource.placeholder;
}

String describeStoryboardNarrationSource(
  AppLocalizations l10n,
  StoryboardNarrationSource source,
) {
  switch (source) {
    case StoryboardNarrationSource.explicitNarration:
      return l10n.scriptEditorStoryboardsNarrationExplicit;
    case StoryboardNarrationSource.promptFallback:
      return l10n.scriptEditorStoryboardsNarrationPromptFallback;
    case StoryboardNarrationSource.placeholder:
      return l10n.scriptEditorStoryboardsNarrationPlaceholder;
  }
}

StoryboardVideoPromptRequest buildStoryboardVideoPromptRequest({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftNarration,
  String? draftPrompt,
  String? draftDuration,
}) {
  return StoryboardVideoPromptRequest(
    description: resolveStoryboardVideoPromptSeed(
      scriptStoryboard: scriptStoryboard,
      productionStoryboard: productionStoryboard,
      draftNarration: draftNarration,
      draftPrompt: draftPrompt,
    ),
    durationSeconds: resolveStoryboardDurationSeconds(
      scriptStoryboard: scriptStoryboard,
      productionStoryboard: productionStoryboard,
      draftDuration: draftDuration,
    ),
  );
}

int? resolveStoryboardDurationSeconds({
  StoryboardRow? scriptStoryboard,
  ProductionStoryboardItemV1? productionStoryboard,
  String? draftDuration,
}) {
  final candidates = <String?>[
    draftDuration,
    scriptStoryboard?.duration,
    productionStoryboard?.duration,
  ];
  for (final candidate in candidates) {
    final seconds = _parseStoryboardDurationSeconds(candidate);
    if (seconds != null) {
      return seconds;
    }
  }
  return null;
}

int? _parseStoryboardDurationSeconds(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final digits = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
      digits.write(char);
      continue;
    }
    if (digits.isNotEmpty) break;
  }
  if (digits.isEmpty) return null;
  final value = int.tryParse(digits.toString());
  if (value == null || value <= 0) return null;
  return value;
}
