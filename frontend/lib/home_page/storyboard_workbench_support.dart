import 'dart:collection';

import '../rust_api.dart';

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
}) {
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
