import 'package:flutter/widgets.dart';

import '../rust_api.dart';
import 'support_project_api.dart';
import 'view.dart';

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

ShortVideoCandidateComparePanelUi buildShortVideoCandidateComparePanelUi({
  required bool projectSelected,
  required bool loadingProjectOverview,
  required List<ProductionStoryboardItemV1> storyboardRows,
  required ProjectShortVideoReadiness? readiness,
  required List<QualityReview> reviews,
  required bool isLiveAction,
  required void Function(ProductionStoryboardItemV1 row)? onSetCurrent,
  required VoidCallback? onOpenProductionWorkspace,
}) {
  if (!projectSelected) {
    return const ShortVideoCandidateComparePanelUi(visible: false);
  }
  if (loadingProjectOverview) {
    return const ShortVideoCandidateComparePanelUi(
      visible: true,
      loading: true,
      headline: '正在整理分镜候选与当前版本…',
      detail: '会按分镜聚合参考图、当前视频、readiness 与质量评审摘要。',
    );
  }
  if (storyboardRows.isEmpty) {
    return const ShortVideoCandidateComparePanelUi(
      visible: true,
      unavailable: true,
      headline: '当前还没有可对比的分镜候选。',
      detail: '先在制作工作区生成镜头或补参考图，再回到 Space 查看对比。',
    );
  }

  final readinessByStoryboard = <int, StoryboardShortVideoReadiness>{};
  for (final row in readiness?.storyboards ?? const <StoryboardShortVideoReadiness>[]) {
    readinessByStoryboard[row.storyboardNumericId] = row;
  }
  final reviewsByStoryboard = <String, List<QualityReview>>{};
  for (final row in reviews) {
    final targetId = (row.targetId ?? '').trim();
    if (targetId.isEmpty) continue;
    reviewsByStoryboard.putIfAbsent(targetId, () => <QualityReview>[]).add(row);
  }

  final sortedRows = List<ProductionStoryboardItemV1>.from(storyboardRows)
    ..sort((a, b) {
      final ar = readinessByStoryboard[a.id];
      final br = readinessByStoryboard[b.id];
      final aBlocked = ar != null && !ar.readyForGeneration;
      final bBlocked = br != null && !br.readyForGeneration;
      if (aBlocked != bBlocked) {
        return aBlocked ? -1 : 1;
      }
      final byScript = (a.scriptId ?? 0).compareTo(b.scriptId ?? 0);
      if (byScript != 0) return byScript;
      return (a.sbIndex ?? a.id).compareTo(b.sbIndex ?? b.id);
    });

  final items = sortedRows.take(4).map((row) {
    final shotReadiness = readinessByStoryboard[row.id];
    final shotReviews = reviewsByStoryboard[row.id.toString()] ?? const <QualityReview>[];
    final badCases = shotReviews.where((review) => review.isBadCase).length;
    final passed = shotReviews.where((review) => review.passed == true).length;
    final readinessLine = shotReadiness == null
        ? 'readiness 暂无数据'
        : shotReadiness.readyForGeneration
        ? '已就绪，可继续生成/导出'
        : '待补 ${shotReadiness.blockingReasons.map(labelShortVideoBlockingReason).join('、')}';
    final qualityLine = shotReviews.isEmpty
        ? (isLiveAction
              ? '暂无质检记录，先盯表演自然度、真实感和口播镜头质感。'
              : '暂无质检记录，先盯角色一致性、画面连续性和镜头节奏。')
        : '评审 ${shotReviews.length} 条 · 通过 $passed 条 · 坏例 $badCases 条';
    return ShortVideoCandidateCompareItemUi(
      storyboardNumericId: row.id,
      scriptNumericId: row.scriptId,
      referenceImageUrl: row.mediaSlots?.referenceOrPreviewFrameUrl,
      selectedVideoUrl: row.mediaSlots?.currentVideoUrl,
      liveActionReferenceShotUrls: row.liveActionReferenceShotUrls,
      readinessLine: readinessLine,
      qualityLine: qualityLine,
      onSetCurrent: (row.mediaSlots?.currentVideoUrl ?? '').trim().isEmpty
          ? null
          : () => onSetCurrent?.call(row),
      onOpenRework: onOpenProductionWorkspace,
    );
  }).toList(growable: false);

  return ShortVideoCandidateComparePanelUi(
    visible: true,
    headline: '优先对比 ${items.length} 条分镜的当前版本、参考图与质检状态。',
    detail: isLiveAction
        ? '真人模式会额外展示参考镜头与表演/口播约束命中情况，方便先锁住真实感与演员感。'
        : '先看哪几条分镜缺参考、缺当前视频或命中过多坏例，再决定去制作台局部返工。',
    items: items,
  );
}
