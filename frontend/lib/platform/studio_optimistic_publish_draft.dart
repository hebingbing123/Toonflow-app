import '../../rust_api/project/publish_models.dart';

PublishDraftRow studioPublishDraftRowWithScheduledAt(
  PublishDraftRow row,
  String scheduledAtIso,
) {
  return PublishDraftRow(
    id: row.id,
    projectId: row.projectId,
    title: row.title,
    description: row.description,
    tags: row.tags,
    draftStatus: row.draftStatus,
    profileId: row.profileId,
    scriptId: row.scriptId,
    videoAssetKey: row.videoAssetKey,
    coverAssetKey: row.coverAssetKey,
    scheduledAt: scheduledAtIso,
    platformCopy: row.platformCopy,
  );
}

PublishDraftRow studioPublishDraftRowWithStatus(
  PublishDraftRow row,
  String draftStatus,
) {
  return PublishDraftRow(
    id: row.id,
    projectId: row.projectId,
    title: row.title,
    description: row.description,
    tags: row.tags,
    draftStatus: draftStatus,
    profileId: row.profileId,
    scriptId: row.scriptId,
    videoAssetKey: row.videoAssetKey,
    coverAssetKey: row.coverAssetKey,
    scheduledAt: row.scheduledAt,
    platformCopy: row.platformCopy,
  );
}

List<PublishDraftRow> studioReplacePublishDraftInList(
  List<PublishDraftRow> items,
  PublishDraftRow updated,
) {
  final next = List<PublishDraftRow>.from(items);
  final index = next.indexWhere((row) => row.id == updated.id);
  if (index >= 0) {
    next[index] = updated;
  }
  return next;
}

List<PublishDraftRow> studioRemovePublishDraftsById(
  List<PublishDraftRow> items,
  Set<String> draftIds,
) {
  return items
      .where((row) => !draftIds.contains(row.id))
      .toList(growable: false);
}
