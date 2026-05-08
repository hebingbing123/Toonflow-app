import 'package:flutter/widgets.dart';

import '../rust_api.dart';
import 'publish_copy_editor.dart';
import 'publish_schedule_calendar.dart';
import 'view.dart';

/// Maps short-video-export-check machine code to short zh labels for Space lists.
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

int? _parseDurationSecondsLoose(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  final m = RegExp(r'^(\d{1,4})(?:\s*s)?$').firstMatch(normalized);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

String formatDurationHHMMSS(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final secs = s % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}

/// Space 成片装配卡：消费 GET .../short-video-assembly
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
  var shotsWithVideo = 0;
  var shotsWithSubtitle = 0;
  var shotsWithVoiceover = 0;
  var totalDurationSeconds = 0;
  var durationKnownShots = 0;
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
    for (final sh in shots.take(4)) {
      final preview = (sh.selectedMediaUrl ?? '').trim().isNotEmpty ? '预览✓' : '预览×';
      final duration = (sh.duration ?? '').trim();
      final subtitle = (sh.subtitleText ?? '').trim();
      final subtitleState = subtitle.isEmpty ? '字幕×' : '字幕✓';
      final voiceover = sh.voiceoverAssetReady ||
              (sh.voiceoverAudioUrl ?? '').trim().isNotEmpty
          ? '旁白✓'
          : '旁白×';
      final order = sh.sbIndex?.toString() ?? '${sh.storyboardNumericId}';
      scriptLines.add(
        '  镜头[$order] · $preview · ${duration.isEmpty ? '时长?' : duration} · '
        '$subtitleState · $voiceover · '
        'BGM ${(d.bgmStrategy ?? '').trim().isEmpty ? '默认' : d.bgmStrategy!.trim()}',
      );
    }
    for (final sh in shots) {
      if ((sh.selectedMediaUrl ?? '').trim().isNotEmpty) {
        shotsWithVideo += 1;
      }
      if ((sh.subtitleText ?? '').trim().isNotEmpty) {
        shotsWithSubtitle += 1;
      }
      if (sh.voiceoverAssetReady || (sh.voiceoverAudioUrl ?? '').trim().isNotEmpty) {
        shotsWithVoiceover += 1;
      }
      final sec = _parseDurationSecondsLoose(sh.duration ?? '');
      if (sec != null && sec > 0) {
        totalDurationSeconds += sec;
        durationKnownShots += 1;
      }
    }
    if (shots.length > 4) {
      scriptLines.add('  …其余 ${shots.length - 4} 镜请在制作工作区时间线查看');
    }
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
  final hasBgm = (d.bgmStrategy ?? '').trim().isNotEmpty;
  final multiTrackTrackCount = 1 + (shotsWithSubtitle > 0 ? 1 : 0) + (shotsWithVoiceover > 0 ? 1 : 0) + (hasBgm ? 1 : 0);
  final withinLimitedTracks = multiTrackTrackCount <= 4;
  final timelineMinutes = totalDurationSeconds / 60.0;
  final overProfessionalBoundary = !withinLimitedTracks || timelineMinutes > 8.0;
  
  // 更新 headline 以包含总时长信息
  final totalDurationFormatted = formatDurationHHMMSS(totalDurationSeconds);
  final headlineWithDuration = scripts.isEmpty
      ? '当前尚无剧本 / 分镜装配数据。'
      : '${scripts.length} 个剧本 · $totalShots 条分镜（导出路径快照）\n'
        '成片总时长：$totalDurationSeconds秒 ($totalDurationFormatted)';
  
  final multiTrackDecisionLines = <String>[
    '轨道占用估算：视频 1 + 字幕 ${shotsWithSubtitle > 0 ? 1 : 0} + 旁白 ${shotsWithVoiceover > 0 ? 1 : 0} + BGM ${hasBgm ? 1 : 0} = $multiTrackTrackCount 轨。',
    '素材就绪：视频镜头 $shotsWithVideo/$totalShots，字幕镜头 $shotsWithSubtitle/$totalShots，旁白镜头 $shotsWithVoiceover/$totalShots。',
    '时长估算：已识别 $durationKnownShots/$totalShots 镜，总时长约 ${timelineMinutes.toStringAsFixed(1)} 分钟。',
    if (overProfessionalBoundary)
      '导出决策：当前超出受限多轨边界（>4 轨或时长复杂），建议转专业台（需求 8.2）处理。'
    else
      '导出决策：维持受限多轨（<=4 轨）路径，可继续在当前链路导出。',
    '边界说明：Space 仅覆盖"视频 + 单字幕轨 + 旁白 + BGM"受限混排，不替代专业 NLE。',
  ];
  return ShortVideoAssemblyPanelUi(
    visible: true,
    headline: headlineWithDuration,
    defaultsLine:
        '${defaultParts.join(' · ')}\n生效 TTS（入队/worker）：${eff.ttsVoice}',
    qualityLines: qualityLines,
    scriptLines: scriptLines,
    multiTrackDecisionLines: multiTrackDecisionLines,
    detail:
        '只读剪辑台：展示镜头顺序、时长、字幕、旁白、BGM 与预览就绪摘要；导出阻塞结论见下方「导出前检查」。',
  );
}

/// Space 导出前检查卡：消费 GET .../short-video-export-check
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
  final qg = exportCheck.qualityGate;
  
  // Build quality gate line based on strategy
  String qualityGateLine;
  if (qg.strategy == 'off') {
    qualityGateLine = '质量门禁：已关闭（不检查质量问题）。';
  } else if (qg.strategy == 'warn') {
    if (qg.pendingReviewBadCaseCount > 0) {
      qualityGateLine = '质量门禁：警告模式 - 待复核坏例 ${qg.pendingReviewBadCaseCount} 条（允许导出但建议修复）。';
    } else {
      qualityGateLine = '质量门禁：警告模式 - 暂无待复核坏例（允许导出）。';
    }
  } else if (qg.strategy == 'block') {
    if (qg.enforced && qg.pendingReviewBadCaseCount > 0) {
      qualityGateLine = '质量门禁：阻断模式 - 待复核坏例 ${qg.pendingReviewBadCaseCount} 条（阻止导出，需先修复）。';
    } else if (qg.pendingReviewBadCaseCount > 0) {
      qualityGateLine = '质量门禁：阻断模式 - 待复核坏例 ${qg.pendingReviewBadCaseCount} 条（暂未强制执行）。';
    } else {
      qualityGateLine = '质量门禁：阻断模式 - 暂无待复核坏例（允许导出）。';
    }
  } else {
    qualityGateLine = '质量门禁：未知策略 "${qg.strategy}"。';
  }
  
  // Collect blocking reasons if in block mode
  final qualityGateBlockingLines = <String>[];
  if (qg.strategy == 'block' && qg.enforced && qg.blockingReasons != null) {
    for (final reason in qg.blockingReasons!) {
      final routePart = reason.reworkRoute != null ? ' [返工: ${reason.reworkRoute}]' : '';
      qualityGateBlockingLines.add('${reason.code}: ${reason.message}$routePart');
    }
  }
  final blockingLines = exportCheck.issues
      .where((i) => i.severity == 'blocking')
      .take(14)
      .map((i) {
        final sb = i.sbIndex;
        final sbPart = sb == null ? '' : ' · 序 $sb';
        return '剧本 #${i.scriptNumericId} · 分镜 #${i.storyboardNumericId}$sbPart · ${shortVideoExportIssueLabelZh(i.code)} · ${i.detail}';
      })
      .toList(growable: false);
  final warningLines = exportCheck.issues
      .where((i) => i.severity == 'warning')
      .take(14)
      .map((i) {
        final sb = i.sbIndex;
        final sbPart = sb == null ? '' : ' · 序 $sb';
        return '剧本 #${i.scriptNumericId} · 分镜 #${i.storyboardNumericId}$sbPart · ${shortVideoExportIssueLabelZh(i.code)} · ${i.detail}';
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
    qualityGateBlockingLines: qualityGateBlockingLines,
    blockingLines: blockingLines,
    warningLines: warningLines,
    detail: detail,
    exportReady: exportCheck.exportReady,
  );
}

/// Space 候选资产确认卡：消费 GET .../assets-overview 的 candidate_counts
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

/// E10–E13：消费 GET /publish/*，编排发布清单 / 矩阵 / 草稿 / 作业
ShortVideoPublishPanelUi buildShortVideoPublishPanelUi({
  required bool projectSelected,
  required bool loadingProjectOverview,
  required bool publishUnavailable,
  required ProjectShortVideoExportCheck? exportCheck,
  required PublishPlatformMatrixResponse? matrix,
  required List<PublishDraftRow> drafts,
  required PublishPrepareCheckResponse? prepare,
  required List<PublishJobRow> jobs,
  required List<PublishPerformanceAlertRow> performanceAlerts,
  required List<PublishAttemptAuditRow> audits,
  required String? selectedPublishDraftId,
  ValueChanged<String>? onSelectPublishDraft,
  required bool publishBusy,
  VoidCallback? onRefreshPublish,
  VoidCallback? onBootstrapPublishDraft,
  VoidCallback? onEnqueuePublishJob,
  VoidCallback? onEnqueueAllDrafts,
  VoidCallback? onRetryFailedPublishJobs,
  VoidCallback? onConfirmSemiAuto,
  VoidCallback? onSuggestPublishCopy,
  VoidCallback? onClearPublishSchedule,
  VoidCallback? onOpenPublishTroubleshooting,
  List<String> publishTargetPlatformIds = const [],
  Map<String, String> publishAutomationModesByPlatform =
      const <String, String>{},
  void Function(String platformId, String automationMode)?
      onChangePublishAutomationMode,
  List<String> publishBatchResultLines = const <String>[],
  int publishCopyEditorRevision = 0,
  PublishPlatformCopyCommit? onCommitPublishPlatformCopy,
  void Function(BuildContext context)? onScheduleFirstDraft,
  void Function(BuildContext context)? onScheduleAllDraftsSameTime,
  PublishCalendarDayCallback? onPublishCalendarDayBulkSchedule,
  // P8: Multi-select parameters
  bool multiSelectMode = false,
  Set<String> selectedDraftIds = const <String>{},
  VoidCallback? onToggleMultiSelectMode,
  ValueChanged<String>? onToggleDraftSelection,
  VoidCallback? onSelectAllDrafts,
  VoidCallback? onClearDraftSelection,
  void Function(BuildContext context)? onBatchScheduleDrafts,
  VoidCallback? onBatchPublishDrafts,
  VoidCallback? onBatchArchiveDrafts,
  VoidCallback? onCompareDrafts,
  PublishBatchValidationResponse? batchValidation,
  // P11: Delivery mode parameters
  Map<String, int> jobsByDeliveryMode = const <String, int>{},
  String? deliveryModeFilter,
  ValueChanged<String>? onDeliveryModeFilterChanged,
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
      exportReady: exportCheck?.exportReady ?? true,
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
  
  final exportReadyStatus = exportCheck?.exportReady ?? true;

  final matrixDomesticLines = <String>[];
  final matrixOverseasLines = <String>[];
  if (matrix != null) {
    for (final row in matrix.platforms) {
      final line =
          '${row.labelZh} · ${row.platformId} · ${row.automationMode} · 标题≤${row.titleMaxChars}'
          ' · 标签≤${row.tagsMax} · 简介≤${row.descriptionMaxChars}'
          '${row.requiresCover ? ' · 需封面' : ''}';
      if (row.marketRegion == 'overseas') {
        matrixOverseasLines.add(line);
      } else {
        matrixDomesticLines.add(line);
      }
    }
  }

  String? activeDraftId = selectedPublishDraftId;
  final selectedOk = activeDraftId != null &&
      activeDraftId.trim().isNotEmpty &&
      drafts.any((d) => d.id == activeDraftId);
  if (!selectedOk) {
    activeDraftId = drafts.length == 1 ? drafts.first.id : null;
  }
  PublishDraftRow? activeDraft;
  if (activeDraftId != null) {
    for (final d in drafts) {
      if (d.id == activeDraftId) {
        activeDraft = d;
        break;
      }
    }
  }

  final prepareLines = <String>[
    if (activeDraft != null) 
      '当前草稿：${activeDraft.title.trim().isEmpty ? "（无标题）" : activeDraft.title.trim()}'
    else if (drafts.isNotEmpty)
      '⚠️ 请明确选择草稿（不再自动使用第一条）',
    if (activeDraft != null && prepare != null) ...[
      if (prepare.ok) '校验：✓ 当前草稿满足占位规则（仍需真实成片引用才能实际上线）。',
      for (final issue in prepare.issues)
        '${issue.severity}: ${issue.message}'
            '${issue.platformId != null ? ' · ${issue.platformId}' : ''}',
    ]     else if (activeDraft == null && drafts.length > 1)
      '多张草稿时请先在「当前操作草稿」中选择一张，再显示 prepare-check。'
    else if (activeDraft == null && drafts.isNotEmpty)
      '选择草稿后将显示 prepare-check 校验结果。'
    else
      '尚无草稿或未完成 prepare-check。',
  ];

  final draftLines = drafts
      .map(
        (d) =>
            '${d.title.trim().isEmpty ? '（无标题）' : d.title.trim()} · ${d.draftStatus}'
            '${(d.videoAssetKey ?? '').trim().isEmpty ? ' · 缺 video 引用' : ''}'
            '${(d.scheduledAt ?? '').trim().isEmpty ? '' : ' · 定时 ${d.scheduledAt}'}',
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
  final succeededJobCount = jobs.where((j) => j.status == 'succeeded').length;
  final failedJobCount = jobs
      .where((j) => j.status == 'failed' || j.status == 'partial_failed')
      .length;
  final waitingConfirmCount =
      jobs.where((j) => j.status == 'awaiting_confirmation').length;
  final scheduledDraftCount = drafts
      .where((d) => (d.scheduledAt ?? '').trim().isNotEmpty)
      .length;
  final labels = Map<String, String>.from(kShortVideoPublishPlatformLabels);
  if (matrix != null) {
    for (final p in matrix.platforms) {
      labels[p.platformId] = p.labelZh;
    }
  }

  final publishOverviewLines = <String>[
    '成功作业：$succeededJobCount · 失败/部分失败：$failedJobCount',
    '待确认：$waitingConfirmCount · 已定时草稿：$scheduledDraftCount/${drafts.length}',
    if (audits.isNotEmpty)
      '投递模式：${audits.take(8).map((a) => a.deliveryMode).toSet().join(" / ")}',
    if (performanceAlerts.isNotEmpty)
      '低表现预警：${performanceAlerts.length} 条（建议进入任务中心排障并改写文案）',
    ...performanceAlerts
        .take(3)
        .map(
          (a) =>
              '${kShortVideoPublishPlatformLabels[a.platformId] ?? a.platformId}'
              ' · 播放 ${a.views} · 完播 ${(a.completionRate * 100).toStringAsFixed(0)}%',
        ),
    ...audits.take(3).map((a) {
      final p = kShortVideoPublishPlatformLabels[a.platformId] ?? a.platformId;
      return '审计：$p · ${a.status} · mode=${a.deliveryMode}';
    }),
    if (publishAutomationModesByPlatform.isNotEmpty)
      '目标自动化：${publishAutomationModesByPlatform.entries.map((e) => "${labels[e.key] ?? e.key}=${e.value}").join("；")}',
  ];

  String? awaitingId;
  for (final j in jobs) {
    if (j.status == 'awaiting_confirmation') {
      awaitingId = j.id;
      break;
    }
  }

  final domesticTargetIds = <String>[];
  final overseasTargetIds = <String>[];
  if (matrix != null && publishTargetPlatformIds.isNotEmpty) {
    final domesticSet = matrix.platforms
        .where((p) => p.marketRegion != 'overseas')
        .map((p) => p.platformId)
        .toSet();
    final overseasSet = matrix.platforms
        .where((p) => p.marketRegion == 'overseas')
        .map((p) => p.platformId)
        .toSet();
    for (final id in publishTargetPlatformIds) {
      if (domesticSet.contains(id)) {
        domesticTargetIds.add(id);
      } else if (overseasSet.contains(id)) {
        overseasTargetIds.add(id);
      } else {
        domesticTargetIds.add(id);
      }
    }
  }

  final primaryDraftId = activeDraft?.id ?? '';
  final platformCopySnap = activeDraft != null
      ? Map<String, dynamic>.from(activeDraft.platformCopy ?? {})
      : <String, dynamic>{};

  final jobsByDeliveryModeMap = <String, int>{};
  for (final job in jobs) {
    final mode = job.deliveryMode ?? 'unknown';
    jobsByDeliveryModeMap[mode] = (jobsByDeliveryModeMap[mode] ?? 0) + 1;
  }

  return ShortVideoPublishPanelUi(
    visible: true,
    headline: '已连接发布 API：${drafts.length} 张草稿 · ${jobs.length} 条作业。',
    exportGateHint: gate,
    exportReady: exportReadyStatus,
    matrixDomesticLines: matrixDomesticLines,
    matrixOverseasLines: matrixOverseasLines,
    prepareLines: prepareLines,
    draftLines: draftLines,
    jobLines: jobLines,
    publishOverviewLines: publishOverviewLines,
    detail:
        '半自动作业在 `awaiting_confirmation` 时需点「确认」；worker 骨架会写入 `publish_attempts` 占位成功记录。',
    onRefreshPublish: onRefreshPublish,
    publishBusy: publishBusy,
    onBootstrapPublishDraft: onBootstrapPublishDraft,
    onEnqueuePublishJob: onEnqueuePublishJob,
    awaitingSemiAutoJobId: awaitingId,
    onConfirmSemiAuto:
        awaitingId != null ? onConfirmSemiAuto : null,
    onSuggestPublishCopy: onSuggestPublishCopy,
    onClearPublishSchedule: onClearPublishSchedule,
    publishPrimaryDraftId: primaryDraftId,
    publishDomesticTargetIds: domesticTargetIds,
    publishOverseasTargetIds: overseasTargetIds,
    publishPlatformLabels: labels,
    publishPlatformCopySnapshot: platformCopySnap,
    publishCopyEditorRevision: publishCopyEditorRevision,
    onCommitPublishPlatformCopy: onCommitPublishPlatformCopy,
    onScheduleFirstDraft: onScheduleFirstDraft,
    onScheduleAllDraftsSameTime: onScheduleAllDraftsSameTime,
    onEnqueueAllDrafts: onEnqueueAllDrafts,
    onRetryFailedPublishJobs: onRetryFailedPublishJobs,
    publishBatchResultLines: publishBatchResultLines,
    publishAutomationModesByPlatform: publishAutomationModesByPlatform,
    onChangePublishAutomationMode: onChangePublishAutomationMode,
    publishDraftOptions: drafts,
    selectedPublishDraftId: activeDraftId,
    onSelectPublishDraft: onSelectPublishDraft,
    publishScheduleCalendarDrafts: drafts.isEmpty ? null : drafts,
    onPublishCalendarDayBulkSchedule:
        drafts.isEmpty ? null : onPublishCalendarDayBulkSchedule,
    onOpenPublishTroubleshooting: onOpenPublishTroubleshooting,
    multiSelectMode: multiSelectMode,
    selectedDraftIds: selectedDraftIds,
    onToggleMultiSelectMode: onToggleMultiSelectMode,
    onToggleDraftSelection: onToggleDraftSelection,
    onSelectAllDrafts: onSelectAllDrafts,
    onClearDraftSelection: onClearDraftSelection,
    onBatchScheduleDrafts: onBatchScheduleDrafts,
    onBatchPublishDrafts: onBatchPublishDrafts,
    onBatchArchiveDrafts: onBatchArchiveDrafts,
    onCompareDrafts: onCompareDrafts,
    batchValidation: batchValidation,
    jobsByDeliveryMode: jobsByDeliveryModeMap,
    deliveryModeFilter: deliveryModeFilter,
    onDeliveryModeFilterChanged: onDeliveryModeFilterChanged,
  );
}
