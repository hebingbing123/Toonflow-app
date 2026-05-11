import '../l10n/app_localizations.dart';
import '../../rust_api.dart';

String summarizeTaskProjects(
  AppLocalizations l10n,
  Iterable<TaskCenterProjectItem> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n.taskCenterProjectsEmpty;
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericId} ${row.name}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return l10n.taskCenterProjectsSummary(items.length, visible, suffix);
}

String summarizeTaskCategories(
  AppLocalizations l10n,
  Iterable<TaskCenterTaskClassRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n.taskCenterCategoriesEmpty;
  }
  final visible = items.take(maxItems).map((row) => row.taskClass).join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return l10n.taskCenterCategoriesSummary(items.length, visible, suffix);
}

String summarizeTaskJobs(
  AppLocalizations l10n,
  Iterable<JobRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n.taskCenterJobsEmpty;
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericTaskId} ${row.kind}:${row.status}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return l10n.taskCenterJobsSummary(items.length, visible, suffix);
}

String formatTaskJobDetails(JobRow row) {
  final payloadKeys = row.payload.keys.take(4).join(', ');
  final resultKeys = row.result?.keys.take(4).join(', ');
  final errCode = row.errorDetails == null
      ? null
      : row.errorDetails!['code'] as String?;
  return [
    '#${row.numericTaskId}',
    row.kind,
    row.status,
    'uuid=${row.id}',
    'updated=${row.updatedAt}',
    if (row.claimedBy != null && row.claimedBy!.isNotEmpty)
      'claimed_by=${row.claimedBy}',
    if (row.errorMessage != null && row.errorMessage!.isNotEmpty)
      'error=${row.errorMessage}',
    if (errCode != null && errCode.isNotEmpty) 'failure_code=$errCode',
    if (payloadKeys.isNotEmpty) 'payload={$payloadKeys}',
    if (resultKeys != null && resultKeys.isNotEmpty) 'result={$resultKeys}',
  ].join(' · ');
}

/// Shell navigates workspaces after the task dialog pops (**`video.export`** failed rows).
class TaskCenterExportJobDeepLink {
  const TaskCenterExportJobDeepLink({
    required this.projectNumericId,
    this.projectUuid,
    this.scriptNumericId,
    this.storyboardNumericId,
    this.workspaceId,
    required this.openProductionWorkspace,
  });

  final int? projectNumericId;
  final String? projectUuid;
  final int? scriptNumericId;
  final int? storyboardNumericId;
  final String? workspaceId;

  /// **`true`** → 制作工作区；**`false`** → 剧本工作区。
  final bool openProductionWorkspace;
}

enum TaskCenterDomainDeepLinkTarget { project, script, storyboard, publish }

class TaskCenterDomainDeepLink {
  const TaskCenterDomainDeepLink({
    required this.target,
    required this.projectNumericId,
    this.projectUuid,
    this.scriptNumericId,
    this.storyboardNumericId,
    this.workspaceId,
    this.publishDraftId,
  });

  final TaskCenterDomainDeepLinkTarget target;
  final int? projectNumericId;
  final String? projectUuid;
  final int? scriptNumericId;
  final int? storyboardNumericId;
  final String? workspaceId;
  final String? publishDraftId;
}

int? taskCenterDeepLinkInt(Map<String, dynamic>? map, String key) {
  if (map == null) {
    return null;
  }
  final value = map[key];
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? taskCenterDeepLinkString(Map<String, dynamic>? map, String key) {
  if (map == null) {
    return null;
  }
  final value = map[key];
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

TaskCenterExportJobDeepLink? tryParseVideoExportJobDeepLink(JobRow job) {
  if (job.kind != 'video.export') {
    return null;
  }
  final payload = job.payload;
  final rawLinks = job.errorDetails == null
      ? null
      : job.errorDetails!['deep_links'];
  final links = rawLinks is Map<String, dynamic>
      ? rawLinks
      : <String, dynamic>{};
  final project = taskCenterDeepLinkInt(links, 'project_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'project_numeric_id');
  final projectUuid =
      taskCenterDeepLinkString(links, 'project_uuid') ??
      taskCenterDeepLinkString(payload, 'project_uuid') ??
      taskCenterDeepLinkString(links, 'project_id') ??
      taskCenterDeepLinkString(payload, 'project_id');
  if (project == null && projectUuid == null) {
    return null;
  }
  final script = taskCenterDeepLinkInt(links, 'script_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'script_numeric_id');
  final storyboard = taskCenterDeepLinkInt(links, 'storyboard_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'storyboard_numeric_id');
  final workspaceId =
      taskCenterDeepLinkString(links, 'workspace_id') ??
      taskCenterDeepLinkString(payload, 'workspace_id');
  return TaskCenterExportJobDeepLink(
    projectNumericId: project,
    projectUuid: projectUuid,
    scriptNumericId: script,
    storyboardNumericId: storyboard,
    workspaceId: workspaceId,
    openProductionWorkspace: true,
  );
}

TaskCenterDomainDeepLink? tryParseTaskCenterDomainDeepLink(JobRow job) {
  final payload = job.payload;
  final rawLinks = job.errorDetails == null ? null : job.errorDetails!['deep_links'];
  final links = rawLinks is Map<String, dynamic> ? rawLinks : <String, dynamic>{};

  final project = taskCenterDeepLinkInt(links, 'project_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'project_numeric_id');
  final projectUuid =
      taskCenterDeepLinkString(links, 'project_uuid') ??
      taskCenterDeepLinkString(payload, 'project_uuid') ??
      taskCenterDeepLinkString(links, 'project_id') ??
      taskCenterDeepLinkString(payload, 'project_id');
  if (project == null && projectUuid == null) {
    return null;
  }

  final script = taskCenterDeepLinkInt(links, 'script_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'script_numeric_id');
  final storyboard = taskCenterDeepLinkInt(links, 'storyboard_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'storyboard_numeric_id');
  final workspaceId =
      taskCenterDeepLinkString(links, 'workspace_id') ??
      taskCenterDeepLinkString(payload, 'workspace_id');
  final publishDraftId = (links['publish_draft_id'] ?? payload['publish_draft_id'])?.toString();

  final kind = job.kind.trim().toLowerCase();
  TaskCenterDomainDeepLinkTarget target;
  if (kind.contains('publish') || publishDraftId != null) {
    target = TaskCenterDomainDeepLinkTarget.publish;
  } else if (storyboard != null || kind.contains('storyboard')) {
    target = TaskCenterDomainDeepLinkTarget.storyboard;
  } else if (script != null || kind.contains('script')) {
    target = TaskCenterDomainDeepLinkTarget.script;
  } else {
    target = TaskCenterDomainDeepLinkTarget.project;
  }

  return TaskCenterDomainDeepLink(
    target: target,
    projectNumericId: project,
    projectUuid: projectUuid,
    scriptNumericId: script,
    storyboardNumericId: storyboard,
    workspaceId: workspaceId,
    publishDraftId: publishDraftId,
  );
}

String taskCenterShortVideoStageKey(JobRow job) {
  final phase = (job.productionPhase ?? '').trim().toLowerCase();
  final kind = job.kind.trim().toLowerCase();
  if (phase.contains('quality') || kind.contains('quality')) {
    return 'quality';
  }
  if (phase.contains('export') || kind.contains('video.export')) {
    return 'export';
  }
  if (phase.contains('video') || kind.contains('video.') || kind.contains('clip')) {
    return 'video';
  }
  if (phase.contains('image') || kind.contains('image') || kind.contains('asset.generate.image')) {
    return 'image';
  }
  if (phase.isNotEmpty) {
    return 'prep';
  }
  // Fallback: project/script/storyboard/publish-centric tasks are treated as preparation.
  return 'prep';
}

String taskCenterShortVideoStageLabel(AppLocalizations l10n, JobRow job) {
  switch (taskCenterShortVideoStageKey(job)) {
    case 'quality':
      return l10n.taskCenterPhaseQuality;
    case 'export':
      return l10n.taskCenterPhaseExport;
    case 'video':
      return l10n.taskCenterPhaseVideo;
    case 'image':
      return l10n.taskCenterPhaseImage;
    case 'prep':
      return l10n.taskCenterPhasePrep;
    default:
      return '';
  }
}

bool taskCenterSupportsPartialRework(JobRow job) {
  return tryParseTaskCenterDomainDeepLink(job) != null;
}

bool taskCenterSupportsWritebackCompensation(JobRow job) {
  final kind = job.kind.trim().toLowerCase();
  if (kind.contains('export') || kind.contains('publish')) {
    return true;
  }
  final details = job.errorDetails;
  if (details == null) {
    return false;
  }
  final code = (details['code'] ?? '').toString();
  return code.contains('writeback') || code.contains('persist');
}

String videoExportFailureCodeLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'payload_missing_source_url':
      return l10n.taskCenterFailurePayloadMissingSourceUrl;
    case 'payload_source_url_empty':
      return l10n.taskCenterFailurePayloadSourceUrlEmpty;
    case 'payload_format_invalid':
      return l10n.taskCenterFailurePayloadFormatInvalid;
    case 'local_export_dir_unset':
      return l10n.taskCenterFailureLocalExportDirUnset;
    case 'export_provider_failed':
      return l10n.taskCenterFailureExportProviderFailed;
    case 'export_directory_create_failed':
      return l10n.taskCenterFailureExportDirectoryCreateFailed;
    case 'export_file_persist_failed':
      return l10n.taskCenterFailureExportFilePersistFailed;
    case 'video_download_http':
      return l10n.taskCenterFailureVideoDownloadHttp;
    case 'video_download_stream':
      return l10n.taskCenterFailureVideoDownloadStream;
    case 'video_format_mismatch_no_transcode':
      return l10n.taskCenterFailureVideoFormatMismatchNoTranscode;
    case 'video_content_length_exceeds_limit':
      return l10n.taskCenterFailureVideoContentLengthExceedsLimit;
    case 'video_body_exceeds_limit':
      return l10n.taskCenterFailureVideoBodyExceedsLimit;
    default:
      return code.isEmpty ? l10n.taskCenterFailureUnknownCode : code;
  }
}
