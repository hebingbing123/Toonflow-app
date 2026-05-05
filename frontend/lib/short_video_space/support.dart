import 'package:flutter/widgets.dart';

import '../rust_api.dart';
import 'view.dart';

enum ShortVideoNextStepTarget {
  projects,
  scriptWorkspace,
  productionWorkspace,
  tasks,
  quality,
}

class ShortVideoNextStepPlan {
  const ShortVideoNextStepPlan({
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.target,
  });

  final String title;
  final String detail;
  final String buttonLabel;
  final ShortVideoNextStepTarget target;
}

bool shortVideoHasVisualStyleSignal(ProjectRow? project) {
  if (project == null) {
    return false;
  }
  return (project.artStyle ?? '').trim().isNotEmpty ||
      (project.artStylePack ?? '').trim().isNotEmpty;
}

bool shortVideoHasDirectionSignal(ProjectRow? project) {
  if (project == null) {
    return false;
  }
  return (project.directorManual ?? '').trim().isNotEmpty ||
      (project.storyStylePack ?? '').trim().isNotEmpty;
}

String? shortVideoVisualStyleLabel(ProjectRow? project) {
  if (project == null) {
    return null;
  }
  final pack = (project.artStylePack ?? '').trim();
  if (pack.isNotEmpty) {
    return '风格包 $pack';
  }
  final style = (project.artStyle ?? '').trim();
  if (style.isNotEmpty) {
    return '画风 $style';
  }
  return null;
}

String? shortVideoDirectionLabel(ProjectRow? project) {
  if (project == null) {
    return null;
  }
  final pack = (project.storyStylePack ?? '').trim();
  if (pack.isNotEmpty) {
    return '故事包 $pack';
  }
  final manual = (project.directorManual ?? '').trim();
  if (manual.isNotEmpty) {
    return '手册 $manual';
  }
  return null;
}

String shortVideoModeLabel(ShortVideoMode mode) {
  return mode == ShortVideoMode.animated ? '动漫短剧' : '真人短剧';
}

String shortVideoVideoRatioLabel(String ratio) {
  switch (ratio) {
    case '16:9':
      return '横屏 16:9';
    case '1:1':
      return '方屏 1:1';
    default:
      return '竖屏 9:16';
  }
}

String shortVideoProjectReadinessSummary(ProjectStats? stats) {
  if (stats == null) {
    return '读取项目统计后，会在这里提示你更适合先去脚本还是制作。';
  }
  if (stats.scriptCount <= 0) {
    return '当前项目还没有剧本，建议先去脚本工作区生成第一版。';
  }
  if (stats.storyboardCount <= 0) {
    return '已有剧本但还缺分镜，建议先继续脚本/分镜规划，再进入制作。';
  }
  if (stats.roleCount <= 0) {
    return '已有脚本和分镜，但角色资产还少，建议先补角色与参考素材。';
  }
  return '脚本、分镜和角色资产都已有基础，可以直接进入制作工作区继续出图和出片。';
}

int shortVideoCountTasksByStatus(
  TaskCenterGetTaskApiResult? tasks,
  String status,
) {
  final rows = tasks?.data ?? const <JobRow>[];
  return rows.where((row) => row.status == status).length;
}

String shortVideoQualitySummaryLine({
  required bool isAnimated,
  required QualityScopeInsightRow? insight,
}) {
  if (insight == null) {
    return isAnimated
        ? '质量评审还没有收敛出明显信号，后续会在这里提醒画风一致性、角色连续性和镜头节奏风险。'
        : '质量评审还没有收敛出明显信号，后续会在这里提醒表演自然度、真实感和口播节奏风险。';
  }
  final passRate = insight.passRatePercent.toStringAsFixed(0);
  if (isAnimated) {
    return '当前项目自动/人工评审通过率约 $passRate%，已记录 ${insight.badCaseCount} 条坏例；继续重点盯角色一致性、画面连续性和镜头节奏。';
  }
  return '当前项目自动/人工评审通过率约 $passRate%，已记录 ${insight.badCaseCount} 条坏例；继续重点盯表演自然度、场景真实感和口播镜头质感。';
}

String shortVideoFormatBadCaseLabel(BadCaseStatItem item) {
  final raw = (item.badCaseCategory ?? '').trim();
  if (raw.isEmpty) {
    return '未分类';
  }
  return raw.replaceAll('_', ' ');
}

String shortVideoFormatTaskKind(JobRow row) {
  final kind = row.kind.trim();
  if (kind.isEmpty) {
    return '未命名任务';
  }
  return kind.replaceAll('.', ' / ');
}

String shortVideoFormatTaskStatus(JobRow row) {
  switch (row.status) {
    case 'queued':
      return '排队中';
    case 'running':
      return '进行中';
    case 'succeeded':
      return '已完成';
    case 'failed':
      return '失败';
    case 'cancelled':
      return '已取消';
    default:
      return row.status;
  }
}

String shortVideoSpaceOverviewSummary({
  required bool loadingProjectOverview,
  required ProjectRow? project,
  required ProjectStats? projectStats,
  required TaskCenterGetTaskApiResult? recentProjectTasks,
  required QualityScopeInsightRow? qualityScopeInsight,
}) {
  if (loadingProjectOverview) {
    return '正在汇总当前项目的脚本、任务和质检状态…';
  }
  if (project == null) {
    return '先选一个项目，Space 才能把当前模式、任务和质检线索收成同一张概览。';
  }
  final taskCount = recentProjectTasks?.total ?? 0;
  final runningCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'running',
  );
  final failedCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'failed',
  );
  if (projectStats == null) {
    return '项目已选中，但概览还没读到。可以先刷新项目或直接进入脚本工作区。';
  }
  if (failedCount > 0) {
    return '这个项目最近有 $failedCount 个失败任务，建议先去任务中心定位失败点，再继续出图或出片。';
  }
  if (runningCount > 0) {
    return '当前还有 $runningCount 个任务在处理中，适合先去任务中心盯进度，同时准备下一轮脚本或素材。';
  }
  if ((qualityScopeInsight?.badCaseCount ?? 0) > 0) {
    return '这个项目已有 ${qualityScopeInsight!.badCaseCount} 条坏例记录，建议先看质量评审再决定是改脚本还是重做分镜。';
  }
  if (taskCount <= 0) {
    return shortVideoProjectReadinessSummary(projectStats);
  }
  return '当前项目最近已有 $taskCount 条任务记录，基础链路已经跑起来了，可以继续推进脚本、制作或质检复核。';
}

List<ShortVideoReadinessItem> buildShortVideoReadinessItems({
  required bool isAnimated,
  required ProjectRow? project,
  required ProjectStats? stats,
  required int sceneAssetCount,
  required int clipAssetCount,
}) {
  final hasVisualStyle = shortVideoHasVisualStyleSignal(project);
  final hasDirection = shortVideoHasDirectionSignal(project);
  final visualLabel = shortVideoVisualStyleLabel(project);
  final directionLabel = shortVideoDirectionLabel(project);
  final roleCount = stats?.roleCount ?? 0;
  final scriptCount = stats?.scriptCount ?? 0;
  final storyboardCount = stats?.storyboardCount ?? 0;
  if (isAnimated) {
    return <ShortVideoReadinessItem>[
      ShortVideoReadinessItem(
        label: '剧本基础',
        ready: scriptCount > 0,
        detail: scriptCount > 0 ? '已有 $scriptCount 份剧本' : '还没有第一版剧本',
      ),
      ShortVideoReadinessItem(
        label: '角色资产',
        ready: roleCount > 0,
        detail: roleCount > 0 ? '已有 $roleCount 个角色资产' : '还缺角色资产',
      ),
      ShortVideoReadinessItem(
        label: '场景资产',
        ready: sceneAssetCount > 0,
        detail: sceneAssetCount > 0 ? '已有 $sceneAssetCount 个场景资产' : '还缺场景资产',
      ),
      ShortVideoReadinessItem(
        label: '画风信号',
        ready: hasVisualStyle,
        detail: hasVisualStyle
            ? '已配置 ${visualLabel ?? "画风或风格包"}'
            : '还没收口画风 / 视觉风格',
      ),
      ShortVideoReadinessItem(
        label: '导演手册',
        ready: hasDirection,
        detail: hasDirection
            ? '已配置 ${directionLabel ?? "导演手册或故事风格包"}'
            : '还没收口导演手册',
      ),
      ShortVideoReadinessItem(
        label: '分镜基础',
        ready: storyboardCount > 0,
        detail: storyboardCount > 0 ? '已有 $storyboardCount 条分镜' : '还没有分镜结构',
      ),
    ];
  }
  return <ShortVideoReadinessItem>[
    ShortVideoReadinessItem(
      label: '剧本基础',
      ready: scriptCount > 0,
      detail: scriptCount > 0 ? '已有 $scriptCount 份剧本' : '还没有第一版剧本',
    ),
    ShortVideoReadinessItem(
      label: '角色设定',
      ready: roleCount > 0,
      detail: roleCount > 0 ? '已有 $roleCount 个角色资产' : '还缺角色设定 / 角色资产',
    ),
    ShortVideoReadinessItem(
      label: '场景参考',
      ready: sceneAssetCount > 0,
      detail: sceneAssetCount > 0 ? '已有 $sceneAssetCount 个场景资产' : '还缺真人场景参考',
    ),
    ShortVideoReadinessItem(
      label: '镜头素材',
      ready: clipAssetCount > 0,
      detail: clipAssetCount > 0
          ? '已有 $clipAssetCount 份 clip 参考'
          : '还缺真人镜头 / clip 参考',
    ),
    ShortVideoReadinessItem(
      label: '视觉手册',
      ready: hasVisualStyle,
      detail: hasVisualStyle
          ? '已配置 ${visualLabel ?? "视觉风格或风格包"}'
          : '还没收口真人视觉风格',
    ),
    ShortVideoReadinessItem(
      label: '表演 / 口播手册',
      ready: hasDirection,
      detail: hasDirection
          ? '已配置 ${directionLabel ?? "导演手册或故事风格包"}'
          : '还没收口口播语气 / 导演手册',
    ),
  ];
}

String shortVideoReadinessGapSummary({
  required bool isAnimated,
  required List<ShortVideoReadinessItem> readinessItems,
}) {
  final missing = readinessItems.where((item) => !item.ready).toList();
  if (missing.isEmpty) {
    return isAnimated
        ? '动漫短剧的基础准备项已经齐了，可以直接推进脚本、制作和质检闭环。'
        : '真人短剧的基础准备项已经齐了，可以继续推进镜头生成、口播和成片复核。';
  }
  final labels = missing.take(3).map((item) => item.label).join('、');
  final suffix = missing.length > 3 ? ' 等 ${missing.length} 项' : '';
  return '当前还缺 $labels$suffix，建议先回项目区把这些准备项补齐。';
}

/// Builds the Space panel for **`GET /api/v1/projects/{id}/short-video-readiness`**.
ShotReadinessUi buildShotReadinessUi({
  required bool loadingProjectOverview,
  required ProjectShortVideoReadiness? readiness,
  required bool readinessUnavailable,
}) {
  if (loadingProjectOverview) {
    return const ShotReadinessUi(loading: true);
  }
  if (readinessUnavailable) {
    return const ShotReadinessUi(unavailable: true);
  }
  if (readiness == null) {
    return const ShotReadinessUi(
      headline: '还没有读取到分镜就绪数据。',
    );
  }
  final roll = readiness.rollup;
  if (roll.totalStoryboards == 0) {
    return const ShotReadinessUi(
      headline: '当前项目还没有分镜行，可先在脚本侧拆镜后再看聚合。',
    );
  }
  final headline =
      '就绪 ${roll.readyCount}/${roll.totalStoryboards} 条分镜；阻塞 ${roll.blockedCount} 条。';
  final reasonLines = readiness.rollup.byReason
      .map(
        (e) =>
            '${labelShortVideoBlockingReason(e.reason)}（${e.storyboardCount} 条分镜）',
      )
      .toList(growable: false);
  final shotDetailLines = readiness.storyboards
      .where((s) => !s.readyForGeneration)
      .take(5)
      .map((s) {
        final parts =
            s.blockingReasons.map(labelShortVideoBlockingReason).join('、');
        final script = s.scriptNumericId;
        final idx = s.sbIndex;
        return '分镜 #${s.storyboardNumericId}'
            '${script != null ? ' · 脚本 #$script' : ''}'
            '${idx != null ? ' · 镜位 $idx' : ''}'
            '：$parts';
      })
      .toList(growable: false);
  return ShotReadinessUi(
    headline: headline,
    reasonLines: reasonLines,
    shotDetailLines: shotDetailLines,
  );
}

String shortVideoAssetTypeOverviewLabel(String assetType) {
  switch (assetType) {
    case 'role':
      return '角色';
    case 'scene':
      return '场景';
    case 'tool':
      return '道具';
    case 'clip':
      return '镜头';
    default:
      return assetType.isEmpty ? '其他' : assetType;
  }
}

/// Space **统一资产总览**（C9）：消费 **`GET /projects/{id}/assets-overview`**。
ShortVideoAssetsOverviewPanelUi buildShortVideoAssetsOverviewPanelUi({
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectAssetsOverview? overview,
}) {
  if (!projectSelected) {
    return const ShortVideoAssetsOverviewPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return const ShortVideoAssetsOverviewPanelUi(
      visible: true,
      loading: true,
      headline: '正在读取资产总览…',
      detail: '按资产类型汇总数量，并聚合关联剧本号（app_script_asset）。',
    );
  }
  if (overview == null) {
    return const ShortVideoAssetsOverviewPanelUi(
      visible: true,
      unavailable: true,
      headline: '资产总览暂不可用。',
      detail: '可稍后刷新，或在项目区维护资产与剧本挂载关系。',
    );
  }
  final lines = <String>[];
  for (final g in overview.byAssetType) {
    final ids = <int>{};
    for (final item in g.items) {
      ids.addAll(item.linkedScriptNumericIds);
    }
    final sorted = ids.toList()..sort();
    final idPart = sorted.isEmpty
        ? '暂无关联剧本'
        : '剧本 ${sorted.take(8).map((n) => '#$n').join('·')}${sorted.length > 8 ? '…' : ''}';
    lines.add(
      '${shortVideoAssetTypeOverviewLabel(g.assetType)} · ${g.items.length} 条 · $idPart',
    );
  }
  final headline =
      '共 ${overview.totalCount} 条资产，按类型分组（实验剧本挂载关系见每行「剧本」摘要）。';
  const detail = '数据来自只读聚合接口；候选状态维护仍在项目区 PATCH 资产。';
  return ShortVideoAssetsOverviewPanelUi(
    visible: true,
    headline: headline,
    typeLines: lines,
    detail: detail,
  );
}

/// Maps **`short-video-export-check`** machine **`code`** to short zh labels for Space lists.
/// 与后端 **`app_quality_review.stage`** 枚举对齐的短标签（L3 展示）。
String shortVideoQualityStageLabelZh(String stage) {
  final s = stage.trim();
  switch (s) {
    case '':
      return '未标注阶段';
    case 'story_skeleton':
      return '故事骨架';
    case 'adaptation_strategy':
      return '改编策略';
    case 'director_planning':
      return '导演规划';
    case 'storyboard_table':
      return '分镜表';
    case 'storyboard_panel':
      return '分镜面板';
    case 'video_prompt':
      return '视频提示 / 成片';
    default:
      return s;
  }
}

String shortVideoExportIssueLabelZh(String code) {
  switch (code) {
    case 'candidate_pending':
      return '候选待确认';
    case 'missing_selected_media':
      return '未选成片媒体';
    case 'selected_media_not_video':
      return '所选媒体非视频';
    case 'subtitle_placeholder':
      return '字幕 / 口播文案缺失';
    case 'voiceover_failed':
      return '旁白生成失败';
    case 'voiceover_audio_missing':
      return '旁白音频未就绪';
    case 'duration_not_explicit':
      return '时长未标明（导出默认）';
    case 'duration_unparsable':
      return '时长格式异常';
    case 'completion_uncertain':
      return '成片状态未标「已完成」';
    default:
      return code;
  }
}

/// Space **成片装配**卡：消费 **`GET …/short-video-assembly`**。
ShortVideoAssemblyPanelUi buildShortVideoAssemblyPanelUi({
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectShortVideoAssembly? assembly,
}) {
  if (!projectSelected) {
    return const ShortVideoAssemblyPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return const ShortVideoAssemblyPanelUi(
      visible: true,
      loading: true,
      headline: '正在读取成片装配快照…',
      detail: '数据来自 GET …/short-video-assembly（按剧本顺序汇总分镜与成片要素）。',
    );
  }
  if (assembly == null) {
    return const ShortVideoAssemblyPanelUi(
      visible: true,
      unavailable: true,
      headline: '成片装配快照暂不可用。',
      detail: '可稍后刷新，或在制作工作区确认分镜与时间线后再试。',
    );
  }
  final scripts = assembly.scripts;
  var totalShots = 0;
  for (final g in scripts) {
    totalShots += g.shots.length;
  }
  final headline = scripts.isEmpty
      ? '当前尚无剧本 / 分镜装配数据。'
      : '${scripts.length} 个剧本 · $totalShots 条分镜（导出路径快照）';
  final d = assembly.projectDefaults;
  final eff = assembly.effectiveShortVideoDefaults;
  final defaultParts = <String>[
    (d.voiceProfile ?? '').trim().isEmpty
        ? '配音档案：未写'
        : '配音档案：${d.voiceProfile!.trim()}',
    (d.subtitleStyle ?? '').trim().isEmpty
        ? '字幕：默认'
        : '字幕：${d.subtitleStyle!.trim()}',
    (d.bgmStrategy ?? '').trim().isEmpty
        ? 'BGM：未指定'
        : 'BGM：${d.bgmStrategy!.trim()}',
  ];
  final scriptLines = <String>[];
  for (final g in scripts) {
    final name = (g.scriptName ?? '').trim();
    final title = name.isEmpty
        ? '剧本 #${g.scriptNumericId}'
        : '剧本 #${g.scriptNumericId} · $name';
    final shots = g.shots;
    final withMedia = shots
        .where((sh) => (sh.selectedMediaUrl ?? '').trim().isNotEmpty)
        .length;
    final voReady = shots.where((sh) => sh.voiceoverAssetReady).length;
    scriptLines.add(
      '$title · ${shots.length} 镜 · 已选成片 $withMedia · 旁白就绪 $voReady',
    );
  }
  final q = assembly.candidateQualitySummary;
  final qualityLines = <String>[
    '项目级待验收坏例：${q.projectBadCaseTotal}（与生产概览同源）',
    '当前装配分镜上的评审：${q.assemblyShotReviewTotal} 条 · 坏例 ${q.assemblyShotBadCaseCount} · 涉及分镜 ${q.assemblyShotsWithBadCase}',
    '贴近成片阶段坏例（分镜面板/视频提示）：${q.assemblyLateStageBadCaseCount}',
  ];
  final stageLines = q.badCasesByStage
      .take(6)
      .map(
        (b) =>
            '${shortVideoQualityStageLabelZh(b.stage)} · 坏例 ${b.badCaseCount}',
      )
      .toList(growable: false);
  if (stageLines.isNotEmpty) {
    qualityLines.add('按阶段：${stageLines.join('；')}');
  }
  qualityLines.add(
    '在任务中心侧可按项目筛选质量评审列表，分镜级 target 与装配一致。',
  );
  return ShortVideoAssemblyPanelUi(
    visible: true,
    headline: headline,
    defaultsLine:
        '${defaultParts.join(' · ')}\n生效 TTS（入队/worker）：${eff.ttsVoice}',
    qualityLines: qualityLines,
    scriptLines: scriptLines,
    detail: '来自只读装配接口；导出阻塞结论见下方「导出前检查」。',
  );
}

/// Space **导出前检查**卡：消费 **`GET …/short-video-export-check`**。
ShortVideoExportCheckPanelUi buildShortVideoExportCheckPanelUi({
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectShortVideoExportCheck? exportCheck,
}) {
  if (!projectSelected) {
    return const ShortVideoExportCheckPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return const ShortVideoExportCheckPanelUi(
      visible: true,
      loading: true,
      headline: '正在读取导出前检查…',
      detail: '聚合分镜阻塞与提醒；质量门禁观测字段仅占位展示。',
    );
  }
  if (exportCheck == null) {
    return const ShortVideoExportCheckPanelUi(
      visible: true,
      unavailable: true,
      headline: '导出前检查暂不可用。',
      detail: '可稍后刷新页面，或在制作工作区确认分镜后再试。',
    );
  }
  final s = exportCheck.summary;
  final metrics = <ShortVideoMetricData>[
    ShortVideoMetricData(label: '分镜', value: '${s.storyboardCount}'),
    ShortVideoMetricData(label: '阻塞', value: '${s.blockingIssueCount}'),
    ShortVideoMetricData(label: '提醒', value: '${s.warningIssueCount}'),
    ShortVideoMetricData(
      label: '可导出',
      value: exportCheck.exportReady ? '是' : '否',
    ),
  ];
  final headline = exportCheck.exportReady
      ? '服务端未发现阻塞级问题（仍需在制作侧确认成片）。'
      : '存在阻塞项：建议先在制作工作区补齐后再导出 / 成片。';
  final qg = exportCheck.qualityGatePlaceholder;
  final qualityGateLine = qg.pendingReviewBadCaseCount > 0
      ? '质量观测（占位）：待复核坏例 ${qg.pendingReviewBadCaseCount} 条（当前未强制拦截导出）。'
      : '质量观测（占位）：暂无待复核坏例计数（未强制拦截导出）。';
  final blockingLines = exportCheck.issues
      .where((i) => i.severity == 'blocking')
      .take(14)
      .map((i) {
        final sb = i.sbIndex;
        final sbPart = sb == null ? '' : ' · 序 $sb';
        return '剧本 #${i.scriptNumericId} · 分镜 #${i.storyboardNumericId}$sbPart · ${shortVideoExportIssueLabelZh(i.code)}';
      })
      .toList(growable: false);
  final detail = exportCheck.exportReady
      ? '阻塞计数为 0 时表示服务端聚合路径上暂无硬阻塞（仍以实际导出管线为准）。'
      : '下方列出部分阻塞项；完整列表请在制作工作区逐镜核对。';
  return ShortVideoExportCheckPanelUi(
    visible: true,
    headline: headline,
    metrics: metrics,
    qualityGateLine: qualityGateLine,
    blockingLines: blockingLines,
    detail: detail,
  );
}

/// Space **候选资产确认**卡：消费 **`GET …/assets-overview`** 的 **`candidate_counts`**。
ShortVideoCandidateCardUi buildShortVideoCandidateCardUi({
  required bool projectSelected,
  required bool loadingProjectOverview,
  required ProjectAssetsOverview? assetsOverview,
  VoidCallback? onBatchGenerateCandidateClips,
  bool batchGenerateCandidateClipsBusy = false,
}) {
  if (!projectSelected) {
    return const ShortVideoCandidateCardUi(visible: false);
  }
  if (loadingProjectOverview) {
    return const ShortVideoCandidateCardUi(
      visible: true,
      loading: true,
      headline: '正在读取项目资产…',
      detail: '用于统计候选 workflow：pending / linked / ignored（与 PATCH 资产一致）。',
    );
  }
  if (assetsOverview == null) {
    return const ShortVideoCandidateCardUi(
      visible: true,
      unavailable: true,
      headline: '候选资产摘要暂不可用。',
      detail: '可稍后刷新页面，或直接去项目区查看并编辑资产。',
    );
  }
  final c = assetsOverview.candidateCounts;
  final pending = c.pending;
  final linked = c.linked;
  final ignored = c.ignored;
  final unset = c.unset;
  final tracked = pending + linked + ignored;
  final headline = tracked == 0
      ? '尚未标记 pending / linked / ignored；可在项目区对镜头候选等资产 PATCH candidate_status。'
      : '候选状态已按项目全量聚合（下方计数含未标记）：';
  final detail =
      '项目资产共 ${assetsOverview.totalCount} 条；计数由服务端一次性聚合（不分页）。在项目区可通过 PATCH candidate_status 更新。';
  return ShortVideoCandidateCardUi(
    visible: true,
    pending: pending,
    linked: linked,
    ignored: ignored,
    unset: unset,
    headline: headline,
    detail: detail,
    onBatchGenerateCandidateClips: onBatchGenerateCandidateClips,
    batchGenerateCandidateClipsBusy: batchGenerateCandidateClipsBusy,
  );
}

ShortVideoNextStepPlan buildShortVideoNextStepPlan({
  required bool isAnimated,
  required ProjectRow? project,
  required ProjectStats? stats,
  required TaskCenterGetTaskApiResult? recentProjectTasks,
  required QualityScopeInsightRow? qualityScopeInsight,
  required int sceneAssetCount,
  required int clipAssetCount,
}) {
  final failedCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'failed',
  );
  if (project == null) {
    return const ShortVideoNextStepPlan(
      title: '先选一个短剧项目',
      detail: '选中项目后，Space 才能把模式、任务、质检和工作区上下文收成同一条主链路。',
      buttonLabel: '先去项目区',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (failedCount > 0) {
    return const ShortVideoNextStepPlan(
      title: '先处理失败任务',
      detail: '最近已有失败任务，先去任务中心确认是脚本、素材、出图还是出片环节卡住。',
      buttonLabel: '打开任务中心',
      target: ShortVideoNextStepTarget.tasks,
    );
  }
  if ((qualityScopeInsight?.badCaseCount ?? 0) > 0) {
    return ShortVideoNextStepPlan(
      title: '先看坏例和质检反馈',
      detail: isAnimated
          ? '当前更适合先看角色一致性、画面连续性和镜头节奏的坏例，再决定返工脚本还是分镜。'
          : '当前更适合先看表演自然度、场景真实感和口播镜头质感的坏例，再决定返工脚本还是镜头。',
      buttonLabel: '打开质量评审',
      target: ShortVideoNextStepTarget.quality,
    );
  }
  if (isAnimated && !shortVideoHasVisualStyleSignal(project)) {
    return const ShortVideoNextStepPlan(
      title: '先收口画风与视觉风格',
      detail: '动漫模式先把画风、视觉手册或风格包收口，后面的角色一致性和出图连续性会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && sceneAssetCount <= 0) {
    return const ShortVideoNextStepPlan(
      title: '先补真人场景参考',
      detail: '真人模式先补场景参考，后面的人物走位、真实空间感和镜头衔接会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && clipAssetCount <= 0) {
    return const ShortVideoNextStepPlan(
      title: '先补真人镜头参考',
      detail: '真人模式更依赖 clip / 镜头参考。先补镜头素材，后面的人物表演、景别和口播质感会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && !shortVideoHasDirectionSignal(project)) {
    return const ShortVideoNextStepPlan(
      title: '先收口表演与口播手册',
      detail: '真人模式最好先把口播语气、表演节奏和导演手册收口，后面的配音和镜头演绎会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (stats == null || stats.scriptCount <= 0) {
    return ShortVideoNextStepPlan(
      title: '先生成第一版剧本',
      detail: isAnimated
          ? '先在脚本工作区把动漫短剧的情绪节奏、角色关系和章节改编跑起来。'
          : '先在脚本工作区把真人短剧的对白自然度、口播感和场景调度跑起来。',
      buttonLabel: '打开脚本工作区',
      target: ShortVideoNextStepTarget.scriptWorkspace,
    );
  }
  if (stats.storyboardCount <= 0) {
    return const ShortVideoNextStepPlan(
      title: '先补分镜和镜头结构',
      detail: '剧本已经有了，但还没拆到分镜层；下一步适合继续脚本/分镜规划，再进制作。',
      buttonLabel: '打开脚本工作区',
      target: ShortVideoNextStepTarget.scriptWorkspace,
    );
  }
  if (stats.roleCount <= 0) {
    return ShortVideoNextStepPlan(
      title: isAnimated ? '先补角色与画风资产' : '先补真人参考与角色设定',
      detail: isAnimated
          ? '分镜已经起步，但角色资产偏少，先补角色、画风和参考图会更稳。'
          : '分镜已经起步，但真人参考、角色设定和镜头参考还不够，先补这些会更稳。',
      buttonLabel: '打开制作工作区',
      target: ShortVideoNextStepTarget.productionWorkspace,
    );
  }
  return ShortVideoNextStepPlan(
    title: '可以直接推进制作与出片',
    detail: isAnimated
        ? '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区出图、出视频和复核。'
        : '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区推进真人镜头、视频生成和复核。',
    buttonLabel: '打开制作工作区',
    target: ShortVideoNextStepTarget.productionWorkspace,
  );
}

/// **E10–E13**：消费 **`GET /publish/*`**，编排发布清单 / 矩阵 / 草稿 / 作业。
ShortVideoPublishPanelUi buildShortVideoPublishPanelUi({
  required bool projectSelected,
  required bool loadingProjectOverview,
  required bool publishUnavailable,
  required ProjectShortVideoExportCheck? exportCheck,
  required PublishPlatformMatrixResponse? matrix,
  required List<PublishDraftRow> drafts,
  required PublishPrepareCheckResponse? prepare,
  required List<PublishJobRow> jobs,
  required bool publishBusy,
  VoidCallback? onRefreshPublish,
  VoidCallback? onBootstrapPublishDraft,
  VoidCallback? onEnqueuePublishJob,
  VoidCallback? onConfirmSemiAuto,
}) {
  if (!projectSelected) {
    return const ShortVideoPublishPanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return const ShortVideoPublishPanelUi(
      visible: true,
      loading: true,
      headline: '正在读取导出检查与发布域…',
      detail: '后端路径：`/api/v1/projects/{id}/publish/*`（profiles / drafts / jobs）。',
    );
  }
  if (publishUnavailable) {
    return ShortVideoPublishPanelUi(
      visible: true,
      unavailable: true,
      headline: '发布域接口暂不可用（可能尚未执行数据库迁移）。',
      exportGateHint: exportCheck == null
          ? '导出检查数据缺失，发布面板仅提示占位。'
          : (exportCheck.summary.blockingIssueCount <= 0
                ? '导出检查：当前无阻塞项。'
                : '导出检查：仍有 ${exportCheck.summary.blockingIssueCount} 条阻塞项。'),
      detail:
          '确认 Supabase 已应用 `app_publish_*` 迁移后再试；Rust worker 会在后台消化发布作业队列。',
      onRefreshPublish: onRefreshPublish,
      publishBusy: publishBusy,
    );
  }

  final gate = exportCheck == null
      ? '导出检查数据暂不可用；仍可试着创建发布草稿并校验。'
      : (exportCheck.summary.blockingIssueCount <= 0
            ? '导出检查：无阻塞项（**E13**：可从成片链路进入发布准备）。'
            : '导出检查：仍有 ${exportCheck.summary.blockingIssueCount} 条阻塞项；可先补齐字段再投递作业。');

  final matrixLines = <String>[
    if (matrix != null)
      for (final row in matrix.platforms)
        '${row.labelZh} · ${row.platformId} · ${row.automationMode} · 标题≤${row.titleMaxChars}'
            '${row.requiresCover ? ' · 需封面' : ''}',
  ];

  final prepareLines = <String>[
    if (prepare != null) ...[
      if (prepare.ok) '校验：✓ 当前草稿满足占位规则（仍需真实成片引用才能实际上线）。',
      for (final issue in prepare.issues)
        '${issue.severity}: ${issue.message}'
            '${issue.platformId != null ? ' · ${issue.platformId}' : ''}',
    ] else
      '尚无草稿或未完成 prepare-check（创建草稿后将自动读取第一条）。',
  ];

  final draftLines = drafts
      .map(
        (d) =>
            '${d.title.trim().isEmpty ? '（无标题）' : d.title.trim()} · ${d.draftStatus}'
            '${(d.videoAssetKey ?? '').trim().isEmpty ? ' · 缺 video 引用' : ''}',
      )
      .toList(growable: false);

  final jobLines = jobs
      .map((j) {
        final short = j.id.length > 8 ? '${j.id.substring(0, 8)}…' : j.id;
        final err = (j.errorMessage ?? '').trim();
        return '$short · ${j.status}'
            '${err.isEmpty ? '' : ' · $err'}';
      })
      .toList(growable: false);

  String? awaitingId;
  for (final j in jobs) {
    if (j.status == 'awaiting_confirmation') {
      awaitingId = j.id;
      break;
    }
  }

  return ShortVideoPublishPanelUi(
    visible: true,
    headline: '已连接发布 API：${drafts.length} 张草稿 · ${jobs.length} 条作业。',
    exportGateHint: gate,
    matrixLines: matrixLines,
    prepareLines: prepareLines,
    draftLines: draftLines,
    jobLines: jobLines,
    detail:
        '半自动作业在 `awaiting_confirmation` 时需点「确认」；worker 骨架会写入 `publish_attempts` 占位成功记录。',
    onRefreshPublish: onRefreshPublish,
    publishBusy: publishBusy,
    onBootstrapPublishDraft: onBootstrapPublishDraft,
    onEnqueuePublishJob: onEnqueuePublishJob,
    awaitingSemiAutoJobId: awaitingId,
    onConfirmSemiAuto:
        awaitingId != null ? onConfirmSemiAuto : null,
  );
}
