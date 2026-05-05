import '../../rust_api.dart';

String summarizeTaskProjects(
  Iterable<TaskCenterProjectItem> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有任务项目';
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericId} ${row.name}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '项目 ${items.length} 个 · $visible$suffix';
}

String summarizeTaskCategories(
  Iterable<TaskCenterTaskClassRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有任务分类';
  }
  final visible = items.take(maxItems).map((row) => row.taskClass).join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '分类 ${items.length} 个 · $visible$suffix';
}

String summarizeTaskJobs(Iterable<JobRow> rows, {int maxItems = 4}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有任务记录';
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericTaskId} ${row.kind}:${row.status}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '任务 ${items.length} 条 · $visible$suffix';
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
    this.scriptNumericId,
    this.storyboardNumericId,
    required this.openProductionWorkspace,
  });

  final int projectNumericId;
  final int? scriptNumericId;
  final int? storyboardNumericId;

  /// **`true`** → 制作工作区；**`false`** → 剧本工作区。
  final bool openProductionWorkspace;
}

enum TaskCenterDomainDeepLinkTarget { project, script, storyboard, publish }

class TaskCenterDomainDeepLink {
  const TaskCenterDomainDeepLink({
    required this.target,
    required this.projectNumericId,
    this.scriptNumericId,
    this.storyboardNumericId,
    this.publishDraftId,
  });

  final TaskCenterDomainDeepLinkTarget target;
  final int projectNumericId;
  final int? scriptNumericId;
  final int? storyboardNumericId;
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
  if (project == null) {
    return null;
  }
  final script = taskCenterDeepLinkInt(links, 'script_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'script_numeric_id');
  final storyboard = taskCenterDeepLinkInt(links, 'storyboard_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'storyboard_numeric_id');
  return TaskCenterExportJobDeepLink(
    projectNumericId: project,
    scriptNumericId: script,
    storyboardNumericId: storyboard,
    openProductionWorkspace: true,
  );
}

TaskCenterDomainDeepLink? tryParseTaskCenterDomainDeepLink(JobRow job) {
  final payload = job.payload;
  final rawLinks = job.errorDetails == null ? null : job.errorDetails!['deep_links'];
  final links = rawLinks is Map<String, dynamic> ? rawLinks : <String, dynamic>{};

  final project = taskCenterDeepLinkInt(links, 'project_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'project_numeric_id');
  if (project == null) {
    return null;
  }

  final script = taskCenterDeepLinkInt(links, 'script_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'script_numeric_id');
  final storyboard = taskCenterDeepLinkInt(links, 'storyboard_numeric_id') ??
      taskCenterDeepLinkInt(payload, 'storyboard_numeric_id');
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
    scriptNumericId: script,
    storyboardNumericId: storyboard,
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

String taskCenterShortVideoStageLabel(JobRow job) {
  switch (taskCenterShortVideoStageKey(job)) {
    case 'quality':
      return '质检';
    case 'export':
      return '导出成片';
    case 'video':
      return '出视频';
    case 'image':
      return '出图';
    case 'prep':
      return '素材准备';
    default:
      return '';
  }
}

String videoExportFailureCodeLabelZh(String code) {
  switch (code) {
    case 'payload_missing_source_url':
      return '缺少 source_url';
    case 'payload_source_url_empty':
      return '成片 URL 为空';
    case 'payload_format_invalid':
      return '导出格式无效';
    case 'local_export_dir_unset':
      return '服务端未配置导出目录';
    case 'export_provider_failed':
      return '导出提供方失败';
    case 'export_directory_create_failed':
      return '创建导出目录失败';
    case 'export_file_persist_failed':
      return '写入导出文件失败';
    case 'video_download_http':
      return '源视频 HTTP 失败';
    case 'video_download_stream':
      return '源视频下载中断';
    case 'video_format_mismatch_no_transcode':
      return '格式不一致（未转码）';
    case 'video_content_length_exceeds_limit':
      return '源视频过大（长度头）';
    case 'video_body_exceeds_limit':
      return '源视频过大（正文）';
    default:
      return code.isEmpty ? '未知原因码' : code;
  }
}
