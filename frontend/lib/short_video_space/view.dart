import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'publish_copy_editor.dart';
import 'publish_schedule_calendar.dart';

enum ShortVideoMode { animated, liveAction }

class ShortVideoProjectOption {
  const ShortVideoProjectOption({required this.id, required this.label});

  final String id;
  final String label;
}

class ShortVideoMetricData {
  const ShortVideoMetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class ShortVideoReadinessItem {
  const ShortVideoReadinessItem({
    required this.label,
    required this.ready,
    required this.detail,
  });

  final String label;
  final bool ready;
  final String detail;
}

/// Candidate asset confirmation summary (**`GET …/assets-overview`** `candidate_counts`; 旧版列表聚合已废弃)。
class ShortVideoCandidateCardUi {
  const ShortVideoCandidateCardUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.pending = 0,
    this.linked = 0,
    this.ignored = 0,
    this.unset = 0,
    this.headline = '',
    this.detail = '',
    this.onBatchGenerateCandidateClips,
    this.batchGenerateCandidateClipsBusy = false,
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final int pending;
  final int linked;
  final int ignored;
  /// `candidate_status` 为空或非 pending/linked/ignored（与后端 `unset` 一致）。
  final int unset;
  final String headline;
  final String detail;
  final VoidCallback? onBatchGenerateCandidateClips;
  final bool batchGenerateCandidateClipsBusy;
}

/// Space 内嵌 **统一资产总览**（C9）：按类型分组 + 关联剧本号摘要。
class ShortVideoAssetsOverviewPanelUi {
  const ShortVideoAssetsOverviewPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.typeLines = const <String>[],
    this.detail = '',
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final List<String> typeLines;
  final String detail;
}

/// D4：**成片装配**快照（**`GET …/short-video-assembly`**）。
class ShortVideoAssemblyPanelUi {
  const ShortVideoAssemblyPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.defaultsLine = '',
    this.qualityLines = const <String>[],
    this.scriptLines = const <String>[],
    this.multiTrackDecisionLines = const <String>[],
    this.detail = '',
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final String defaultsLine;
  /// L3：质量验收摘要行（与 **`candidate_quality_summary`** 对齐）。
  final List<String> qualityLines;
  final List<String> scriptLines;
  final List<String> multiTrackDecisionLines;
  final String detail;
}

/// D4：**导出前检查**摘要（**`GET …/short-video-export-check`**）。
class ShortVideoExportCheckPanelUi {
  const ShortVideoExportCheckPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.metrics = const <ShortVideoMetricData>[],
    this.qualityGateLine = '',
    this.blockingLines = const <String>[],
    this.detail = '',
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final List<ShortVideoMetricData> metrics;
  final String qualityGateLine;
  final List<String> blockingLines;
  final String detail;
}

class ShortVideoCandidateCompareItemUi {
  const ShortVideoCandidateCompareItemUi({
    required this.storyboardNumericId,
    this.scriptNumericId,
    this.referenceImageUrl,
    this.selectedVideoUrl,
    this.liveActionReferenceShotUrls = const <String>[],
    required this.readinessLine,
    required this.qualityLine,
    this.onSetCurrent,
    this.onOpenRework,
  });

  final int storyboardNumericId;
  final int? scriptNumericId;
  final String? referenceImageUrl;
  final String? selectedVideoUrl;
  final List<String> liveActionReferenceShotUrls;
  final String readinessLine;
  final String qualityLine;
  final VoidCallback? onSetCurrent;
  final VoidCallback? onOpenRework;
}

class ShortVideoCandidateComparePanelUi {
  const ShortVideoCandidateComparePanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.detail = '',
    this.items = const <ShortVideoCandidateCompareItemUi>[],
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final String detail;
  final List<ShortVideoCandidateCompareItemUi> items;
}

/// **E10–E13**：发布准备清单、平台矩阵、草稿与作业（**`/publish/*`**）。
class ShortVideoPublishPanelUi {
  const ShortVideoPublishPanelUi({
    this.visible = false,
    this.loading = false,
    this.unavailable = false,
    this.headline = '',
    this.exportGateHint = '',
    this.detail = '',
    this.matrixDomesticLines = const <String>[],
    this.matrixOverseasLines = const <String>[],
    this.prepareLines = const <String>[],
    this.publishOverviewLines = const <String>[],
    this.draftLines = const <String>[],
    this.jobLines = const <String>[],
    this.onRefreshPublish,
    this.publishBusy = false,
    this.onBootstrapPublishDraft,
    this.onEnqueuePublishJob,
    this.awaitingSemiAutoJobId,
    this.onConfirmSemiAuto,
    this.onSuggestPublishCopy,
    this.onClearPublishSchedule,
    this.publishPrimaryDraftId = '',
    this.publishDomesticTargetIds = const <String>[],
    this.publishOverseasTargetIds = const <String>[],
    this.publishPlatformLabels = const <String, String>{},
    this.publishPlatformCopySnapshot = const <String, dynamic>{},
    this.publishCopyEditorRevision = 0,
    this.onCommitPublishPlatformCopy,
    this.onScheduleFirstDraft,
    this.onScheduleAllDraftsSameTime,
    this.publishScheduleCalendarDrafts,
    this.onPublishCalendarDayBulkSchedule,
    this.onOpenPublishTroubleshooting,
  });

  final bool visible;
  final bool loading;
  final bool unavailable;
  final String headline;
  final String exportGateHint;
  final String detail;
  final List<String> matrixDomesticLines;
  final List<String> matrixOverseasLines;
  final List<String> prepareLines;
  final List<String> publishOverviewLines;
  final List<String> draftLines;
  final List<String> jobLines;
  final VoidCallback? onRefreshPublish;
  final bool publishBusy;
  final VoidCallback? onBootstrapPublishDraft;
  final VoidCallback? onEnqueuePublishJob;
  final String? awaitingSemiAutoJobId;
  final VoidCallback? onConfirmSemiAuto;
  final VoidCallback? onSuggestPublishCopy;
  final VoidCallback? onClearPublishSchedule;
  final String publishPrimaryDraftId;
  final List<String> publishDomesticTargetIds;
  final List<String> publishOverseasTargetIds;
  final Map<String, String> publishPlatformLabels;
  final Map<String, dynamic> publishPlatformCopySnapshot;
  final int publishCopyEditorRevision;
  final PublishPlatformCopyCommit? onCommitPublishPlatformCopy;
  final void Function(BuildContext context)? onScheduleFirstDraft;
  final void Function(BuildContext context)? onScheduleAllDraftsSameTime;
  /// When null, treat as no drafts for calendar (keeps panel `const` paths valid).
  final List<PublishDraftRow>? publishScheduleCalendarDrafts;
  final PublishCalendarDayCallback? onPublishCalendarDayBulkSchedule;
  final VoidCallback? onOpenPublishTroubleshooting;
}

/// Server-backed shot readiness slice for Space (see **`GET …/short-video-readiness`**).
class ShotReadinessUi {
  const ShotReadinessUi({
    this.loading = false,
    this.unavailable = false,
    this.headline,
    this.reasonLines = const <String>[],
    this.shotDetailLines = const <String>[],
  });

  final bool loading;
  final bool unavailable;
  final String? headline;
  final List<String> reasonLines;
  final List<String> shotDetailLines;
}

class ShortVideoStageCardData {
  const ShortVideoStageCardData({
    required this.title,
    required this.status,
    required this.detail,
  });

  final String title;
  final String status;
  final String detail;
}

/// 与后端 `validate_target_platforms` 约定的平台 id → 展示名（需求：全矩阵勾选）。
const Map<String, String> kShortVideoPublishPlatformLabels = {
  'douyin': '抖音',
  'bilibili': '哔哩哔哩',
  'xiaohongshu': '小红书',
  'weixin_channels': '视频号',
  'kuaishou': '快手',
  'tiktok': 'TikTok',
  'youtube_shorts': 'YouTube Shorts',
  'instagram_reels': 'Instagram Reels',
  'facebook_reels': 'Facebook Reels',
};

class ShortVideoSpaceView extends StatelessWidget {
  const ShortVideoSpaceView({
    super.key,
    required this.mode,
    required this.modeTitle,
    required this.modeSummary,
    required this.modeAdvice,
    required this.onModeChanged,
    required this.loadingProjects,
    required this.projectOptions,
    required this.selectedProjectId,
    required this.onProjectChanged,
    required this.onRefreshProjects,
    required this.videoRatio,
    required this.onVideoRatioChanged,
    required this.targetMarket,
    required this.onTargetMarketChanged,
    required this.targetPlatforms,
    required this.onPublishPlatformTapped,
    required this.durationStrategy,
    required this.onDurationStrategyChanged,
    required this.voiceProfile,
    required this.onVoiceProfileChanged,
    required this.subtitleStyle,
    required this.onSubtitleStyleChanged,
    required this.bgmStrategy,
    required this.onBgmStrategyChanged,
    required this.creatingProject,
    required this.onCreateProject,
    required this.savingProjectConfig,
    required this.onSaveProjectConfig,
    required this.onOpenProjects,
    required this.projectConfigLine,
    required this.loadingProjectOverview,
    required this.projectReadinessSummary,
    required this.visualLabel,
    required this.directionLabel,
    required this.projectMetrics,
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
    required this.assetsOverviewPanelUi,
    required this.assemblyPanelUi,
    required this.exportCheckPanelUi,
    required this.publishPanelUi,
    this.onOpenProductionForAssemblyExport,
    this.onOpenAssemblyClipDeskOps,
    this.onOpenAssemblyDefaultsEditor,
    required this.candidateCardUi,
    required this.candidateComparePanelUi,
    this.onOpenProjectsForCandidateAssets,
    required this.readinessIntro,
    required this.readinessCountLabel,
    required this.readinessGapSummary,
    required this.readinessItems,
    required this.shotReadinessUi,
    this.onOpenProductionForShotReadiness,
    required this.nextStepTitle,
    required this.nextStepDetail,
    required this.onNextStep,
    required this.nextStepButtonLabel,
    required this.stageCards,
    required this.migrationSummary,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
  });

  final String targetMarket;
  final ValueChanged<String> onTargetMarketChanged;
  final List<String> targetPlatforms;
  final ValueChanged<String> onPublishPlatformTapped;
  final String durationStrategy;
  final ValueChanged<String> onDurationStrategyChanged;
  final String voiceProfile;
  final ValueChanged<String> onVoiceProfileChanged;
  final String subtitleStyle;
  final ValueChanged<String> onSubtitleStyleChanged;
  final String bgmStrategy;
  final ValueChanged<String> onBgmStrategyChanged;

  final ShortVideoMode mode;
  final String modeTitle;
  final String modeSummary;
  final String modeAdvice;
  final ValueChanged<ShortVideoMode> onModeChanged;
  final bool loadingProjects;
  final List<ShortVideoProjectOption> projectOptions;
  final String? selectedProjectId;
  final ValueChanged<String?> onProjectChanged;
  final VoidCallback onRefreshProjects;
  final String videoRatio;
  final ValueChanged<String> onVideoRatioChanged;
  final bool creatingProject;
  final VoidCallback onCreateProject;
  final bool savingProjectConfig;
  final VoidCallback onSaveProjectConfig;
  final VoidCallback onOpenProjects;
  final String? projectConfigLine;
  final bool loadingProjectOverview;
  final String projectReadinessSummary;
  final String? visualLabel;
  final String? directionLabel;
  final List<ShortVideoMetricData> projectMetrics;
  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;
  final ShortVideoAssetsOverviewPanelUi assetsOverviewPanelUi;
  final ShortVideoAssemblyPanelUi assemblyPanelUi;
  final ShortVideoExportCheckPanelUi exportCheckPanelUi;
  final ShortVideoPublishPanelUi publishPanelUi;
  final VoidCallback? onOpenProductionForAssemblyExport;
  final VoidCallback? onOpenAssemblyClipDeskOps;
  final VoidCallback? onOpenAssemblyDefaultsEditor;
  final ShortVideoCandidateCardUi candidateCardUi;
  final ShortVideoCandidateComparePanelUi candidateComparePanelUi;
  final VoidCallback? onOpenProjectsForCandidateAssets;
  final String readinessIntro;
  final String readinessCountLabel;
  final String readinessGapSummary;
  final List<ShortVideoReadinessItem> readinessItems;
  final ShotReadinessUi shotReadinessUi;
  final VoidCallback? onOpenProductionForShotReadiness;
  final String nextStepTitle;
  final String nextStepDetail;
  final VoidCallback onNextStep;
  final String nextStepButtonLabel;
  final List<ShortVideoStageCardData> stageCards;
  final String migrationSummary;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('短视频 Space', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '参考 MoneyPrinterTurbo 的长处，先把“主题到成片”的链路聚成一个入口，再逐步把脚本、素材、旁白、字幕和质检串成标准流程。',
          style: theme.textTheme.bodyMedium?.copyWith(color: outline),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('创作模式', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _ModeSegmentedButton(mode: mode, onChanged: onModeChanged),
              const SizedBox(height: 12),
              Text(modeTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                modeSummary,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Text(modeAdvice, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('短视频目标配置', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                '把创作模式和画幅直接写回项目，后面的脚本与制作流程就能基于同一份项目配置继续工作。',
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: '目标项目',
                        border: OutlineInputBorder(),
                      ),
                      items: projectOptions
                          .map(
                            (project) => DropdownMenuItem<String>(
                              value: project.id,
                              child: Text(project.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: loadingProjects ? null : onProjectChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: loadingProjects ? null : onRefreshProjects,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(loadingProjects ? '读取中' : '刷新项目'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ModeSegmentedButton(mode: mode, onChanged: onModeChanged),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '9:16', label: Text('竖屏 9:16')),
                  ButtonSegment(value: '16:9', label: Text('横屏 16:9')),
                  ButtonSegment(value: '1:1', label: Text('方屏 1:1')),
                ],
                selected: {videoRatio},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  onVideoRatioChanged(selection.first);
                },
              ),
              const SizedBox(height: 16),
              Text('默认发布市场 / 平台', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('tm-$selectedProjectId'),
                initialValue: targetMarket,
                decoration: const InputDecoration(
                  labelText: '目标市场',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'domestic', child: Text('国内')),
                  DropdownMenuItem(value: 'overseas', child: Text('海外')),
                  DropdownMenuItem(value: 'both', child: Text('双端')),
                ],
                onChanged: loadingProjects
                    ? null
                    : (value) {
                        if (value != null) {
                          onTargetMarketChanged(value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              Text(
                '目标平台（至少选一个；写回项目供分发与校验共用）',
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: kShortVideoPublishPlatformLabels.entries
                    .map(
                      (e) => FilterChip(
                        label: Text(e.value),
                        selected: targetPlatforms.contains(e.key),
                        onSelected: loadingProjects
                            ? null
                            : (_) {
                                onPublishPlatformTapped(e.key);
                              },
                        showCheckmark: false,
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Text('时长策略', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'short', label: Text('短')),
                  ButtonSegment(value: 'medium', label: Text('中')),
                  ButtonSegment(value: 'long', label: Text('长')),
                ],
                selected: {durationStrategy},
                onSelectionChanged: (selection) {
                  if (loadingProjects || selection.isEmpty) {
                    return;
                  }
                  onDurationStrategyChanged(selection.first);
                },
              ),
              const SizedBox(height: 16),
              Text('旁白 / 字幕 / BGM（项目级默认）', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey<String>('vp-$selectedProjectId'),
                initialValue: voiceProfile,
                decoration: const InputDecoration(
                  labelText: '声线标识 voice_profile',
                  hintText: '如 default_narrator（可留空）',
                  border: OutlineInputBorder(),
                ),
                onChanged: onVoiceProfileChanged,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: ValueKey<String>('ss-$selectedProjectId'),
                initialValue: subtitleStyle,
                decoration: const InputDecoration(
                  labelText: '字幕样式 subtitle_style',
                  border: OutlineInputBorder(),
                ),
                onChanged: onSubtitleStyleChanged,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: ValueKey<String>('bgm-$selectedProjectId'),
                initialValue: bgmStrategy,
                decoration: const InputDecoration(
                  labelText: 'BGM 策略 bgm_strategy',
                  border: OutlineInputBorder(),
                ),
                onChanged: onBgmStrategyChanged,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: creatingProject ? null : onCreateProject,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(creatingProject ? '新建中' : '直接新建短剧项目'),
                  ),
                  FilledButton.icon(
                    onPressed: savingProjectConfig ? null : onSaveProjectConfig,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(savingProjectConfig ? '保存中' : '写回项目配置'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenProjects,
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('打开项目区继续细化'),
                  ),
                ],
              ),
              if (projectConfigLine != null) ...[
                const SizedBox(height: 10),
                Text(projectConfigLine!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Text(
                loadingProjectOverview
                    ? '正在读取当前项目准备度…'
                    : projectReadinessSummary,
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (visualLabel != null || directionLabel != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (visualLabel != null)
                      _MetricChip(label: '视觉', value: visualLabel!),
                    if (directionLabel != null)
                      _MetricChip(label: '手册', value: directionLabel!),
                  ],
                ),
              ],
              if (projectMetrics.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: projectMetrics
                      .map(
                        (item) =>
                            _MetricChip(label: item.label, value: item.value),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前项目概览', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                spaceOverviewSummary,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: overviewMetrics
                    .map(
                      (item) =>
                          _MetricChip(label: item.label, value: item.value),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Text(qualitySummaryLine, style: theme.textTheme.bodySmall),
              if (badCaseMetrics.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('最近坏例倾向', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badCaseMetrics
                      .map(
                        (item) =>
                            _MetricChip(label: item.label, value: item.value),
                      )
                      .toList(growable: false),
                ),
              ],
              if (recentTaskLines.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('最近任务流', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                for (final line in recentTaskLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 10,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(line, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (assetsOverviewPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('资产总览', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (assetsOverviewPanelUi.loading)
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (assetsOverviewPanelUi.unavailable)
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  if (assetsOverviewPanelUi.typeLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final line in assetsOverviewPanelUi.typeLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  assetsOverviewPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ),
          ),
        ],
        if (assemblyPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成片装配快照', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (assemblyPanelUi.loading)
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (assemblyPanelUi.unavailable)
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  if (assemblyPanelUi.defaultsLine.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      assemblyPanelUi.defaultsLine,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (assemblyPanelUi.qualityLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '成片候选验收（质量评审）',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    for (final line in assemblyPanelUi.qualityLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: 16,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (assemblyPanelUi.scriptLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final line in assemblyPanelUi.scriptLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.movie_filter_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (assemblyPanelUi.multiTrackDecisionLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('受限多轨导出决策（K5）', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    for (final line in assemblyPanelUi.multiTrackDecisionLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.alt_route_outlined,
                              size: 16,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  assemblyPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (onOpenProductionForAssemblyExport != null &&
                    assemblyPanelUi.visible &&
                    !assemblyPanelUi.loading &&
                    !assemblyPanelUi.unavailable) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onOpenProductionForAssemblyExport,
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: const Text('打开制作工作区'),
                      ),
                      if (onOpenAssemblyClipDeskOps != null)
                        OutlinedButton.icon(
                          onPressed: onOpenAssemblyClipDeskOps,
                          icon: const Icon(Icons.tune_outlined),
                          label: const Text('镜头基础操作'),
                        ),
                      if (onOpenAssemblyDefaultsEditor != null)
                        OutlinedButton.icon(
                          onPressed: onOpenAssemblyDefaultsEditor,
                          icon: const Icon(Icons.subtitles_outlined),
                          label: const Text('成片样式调整'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (exportCheckPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导出前检查', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (exportCheckPanelUi.loading)
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (exportCheckPanelUi.unavailable)
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  if (exportCheckPanelUi.metrics.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: exportCheckPanelUi.metrics
                          .map(
                            (m) =>
                                _MetricChip(label: m.label, value: m.value),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (exportCheckPanelUi.qualityGateLine.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      exportCheckPanelUi.qualityGateLine,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (exportCheckPanelUi.blockingLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '阻塞项（按接口顺序节选）',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final line in exportCheckPanelUi.blockingLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  exportCheckPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ),
          ),
        ],
        if (publishPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('发布准备', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (publishPanelUi.exportGateHint.trim().isNotEmpty) ...[
                  Text(
                    publishPanelUi.exportGateHint,
                    style: theme.textTheme.bodySmall?.copyWith(color: outline),
                  ),
                  const SizedBox(height: 8),
                ],
                if (publishPanelUi.loading)
                  Text(
                    publishPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (publishPanelUi.unavailable)
                  Text(
                    publishPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    publishPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  if (publishPanelUi.matrixDomesticLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '国内平台矩阵（占位约束）',
                      style: theme.textTheme.labelSmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 6),
                    for (final line in publishPanelUi.matrixDomesticLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                  if (publishPanelUi.matrixOverseasLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '海外平台矩阵（占位约束）',
                      style: theme.textTheme.labelSmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 6),
                    for (final line in publishPanelUi.matrixOverseasLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                  if (publishPanelUi.prepareLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '发布准备校验',
                      style: theme.textTheme.labelSmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 6),
                    for (final line in publishPanelUi.prepareLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                  if (publishPanelUi.draftLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '发布单（草稿）',
                      style: theme.textTheme.labelSmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 6),
                    for (final line in publishPanelUi.draftLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                  if (!publishPanelUi.loading &&
                      !publishPanelUi.unavailable &&
                      (publishPanelUi.publishScheduleCalendarDrafts?.isNotEmpty ??
                          false) &&
                      publishPanelUi.onPublishCalendarDayBulkSchedule !=
                          null) ...[
                    const SizedBox(height: 14),
                    Text(
                      '排程月历（按本地日历日计数；点选某日批量写入定时）',
                      style:
                          theme.textTheme.labelSmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 8),
                    PublishScheduleCalendar(
                      drafts:
                          publishPanelUi.publishScheduleCalendarDrafts ?? [],
                      busy: publishPanelUi.publishBusy,
                      onDayTap:
                          publishPanelUi.onPublishCalendarDayBulkSchedule!,
                    ),
                  ],
                  if (!publishPanelUi.loading &&
                      !publishPanelUi.unavailable &&
                      publishPanelUi.publishPrimaryDraftId.isNotEmpty &&
                      (publishPanelUi.publishDomesticTargetIds.isNotEmpty ||
                          publishPanelUi.publishOverseasTargetIds
                              .isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    PublishPlatformCopyEditor(
                      key: ValueKey(
                        '${publishPanelUi.publishPrimaryDraftId}_${publishPanelUi.publishCopyEditorRevision}',
                      ),
                      draftId: publishPanelUi.publishPrimaryDraftId,
                      domesticPlatformIds:
                          publishPanelUi.publishDomesticTargetIds,
                      overseasPlatformIds:
                          publishPanelUi.publishOverseasTargetIds,
                      platformLabels: publishPanelUi.publishPlatformLabels,
                      platformCopy: publishPanelUi.publishPlatformCopySnapshot,
                      busy: publishPanelUi.publishBusy,
                      onCommit: publishPanelUi.onCommitPublishPlatformCopy,
                    ),
                  ],
                  if (publishPanelUi.jobLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '发布作业',
                      style: theme.textTheme.labelSmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 6),
                    for (final line in publishPanelUi.jobLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                  if (publishPanelUi.publishOverviewLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '发布概览',
                      style: theme.textTheme.labelSmall?.copyWith(color: outline),
                    ),
                    const SizedBox(height: 6),
                    for (final line in publishPanelUi.publishOverviewLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                  if (publishPanelUi.awaitingSemiAutoJobId != null &&
                      publishPanelUi.onConfirmSemiAuto != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onConfirmSemiAuto,
                      icon: publishPanelUi.publishBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: const Text('确认半自动发布（服务端闸门）'),
                    ),
                  ],
                  if (publishPanelUi.onBootstrapPublishDraft != null ||
                      publishPanelUi.onEnqueuePublishJob != null ||
                      publishPanelUi.onRefreshPublish != null ||
                      publishPanelUi.onSuggestPublishCopy != null ||
                      publishPanelUi.onClearPublishSchedule != null ||
                      publishPanelUi.onScheduleFirstDraft != null ||
                      publishPanelUi.onScheduleAllDraftsSameTime != null ||
                      publishPanelUi.onOpenPublishTroubleshooting != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (publishPanelUi.onRefreshPublish != null)
                          OutlinedButton.icon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onRefreshPublish,
                            icon: const Icon(Icons.refresh),
                            label: const Text('刷新发布数据'),
                          ),
                        if (publishPanelUi.onBootstrapPublishDraft != null)
                          FilledButton.tonalIcon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onBootstrapPublishDraft,
                            icon: publishPanelUi.publishBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.note_add_outlined),
                            label: const Text('创建发布草稿并写入平台目标'),
                          ),
                        if (publishPanelUi.onEnqueuePublishJob != null)
                          FilledButton.icon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onEnqueuePublishJob,
                            icon: publishPanelUi.publishBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),
                            label: const Text('投递发布作业'),
                          ),
                        if (publishPanelUi.onSuggestPublishCopy != null)
                          OutlinedButton.icon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onSuggestPublishCopy,
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Text('生成差异化文案'),
                          ),
                        if (publishPanelUi.onClearPublishSchedule != null)
                          OutlinedButton.icon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onClearPublishSchedule,
                            icon: const Icon(Icons.schedule_outlined),
                            label: const Text('清除定时（允许入队）'),
                          ),
                        if (publishPanelUi.onScheduleFirstDraft != null &&
                            publishPanelUi.publishPrimaryDraftId.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : () => publishPanelUi.onScheduleFirstDraft
                                    ?.call(context),
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text('定时首张草稿…'),
                          ),
                        if (publishPanelUi.onScheduleAllDraftsSameTime !=
                                null &&
                            publishPanelUi.draftLines.length > 1)
                          OutlinedButton.icon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : () => publishPanelUi
                                    .onScheduleAllDraftsSameTime
                                    ?.call(context),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: const Text('批量定时全部草稿…'),
                          ),
                        if (publishPanelUi.onOpenPublishTroubleshooting != null)
                          OutlinedButton.icon(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onOpenPublishTroubleshooting,
                            icon: const Icon(Icons.bug_report_outlined),
                            label: const Text('打开发布排障入口'),
                          ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  publishPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ),
          ),
        ],
        if (candidateCardUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('候选资产确认', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (candidateCardUi.loading)
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (candidateCardUi.unavailable)
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(
                        label: '待确认',
                        value: '${candidateCardUi.pending}',
                      ),
                      _MetricChip(
                        label: '已关联',
                        value: '${candidateCardUi.linked}',
                      ),
                      _MetricChip(
                        label: '已忽略',
                        value: '${candidateCardUi.ignored}',
                      ),
                      _MetricChip(
                        label: '未标记',
                        value: '${candidateCardUi.unset}',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  candidateCardUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (candidateCardUi.onBatchGenerateCandidateClips != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: candidateCardUi.batchGenerateCandidateClipsBusy
                        ? null
                        : candidateCardUi.onBatchGenerateCandidateClips,
                    icon: candidateCardUi.batchGenerateCandidateClipsBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.movie_creation_outlined),
                    label: Text(
                      candidateCardUi.batchGenerateCandidateClipsBusy
                          ? '正在批量投递候选成片任务…'
                          : '一键批量生成候选成片（按项目默认参数）',
                    ),
                  ),
                ],
                if (onOpenProjectsForCandidateAssets != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenProjectsForCandidateAssets,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('打开项目区维护资产'),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (candidateComparePanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('候选对比', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  candidateComparePanelUi.headline,
                  style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                ),
                const SizedBox(height: 8),
                Text(
                  candidateComparePanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (!candidateComparePanelUi.loading &&
                    !candidateComparePanelUi.unavailable &&
                    candidateComparePanelUi.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: candidateComparePanelUi.items
                        .map((item) => _CandidateCompareCard(item: item))
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('模式准备度', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                readinessIntro,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(label: '已就绪', value: readinessCountLabel),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                readinessGapSummary,
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              for (final item in readinessItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReadinessRow(item: item),
                ),
              const SizedBox(height: 16),
              Text('分镜生成就绪（服务端）', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (shotReadinessUi.loading)
                Text(
                  '正在读取分镜就绪聚合…',
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                )
              else if (shotReadinessUi.unavailable)
                Text(
                  '分镜就绪摘要暂不可用，其余概览仍有效。',
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                )
              else ...[
                if (shotReadinessUi.headline != null)
                  Text(
                    shotReadinessUi.headline!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                if (shotReadinessUi.reasonLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final line in shotReadinessUi.reasonLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              line,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (shotReadinessUi.shotDetailLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '优先处理的分镜',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  for (final line in shotReadinessUi.shotDetailLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.movie_filter_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(line, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                ],
                if (onOpenProductionForShotReadiness != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenProductionForShotReadiness,
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: const Text('打开制作工作区分镜'),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('建议下一步', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(nextStepTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                nextStepDetail,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onNextStep,
                icon: const Icon(Icons.arrow_forward_outlined),
                label: Text(nextStepButtonLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stageCards
              .map(
                (item) => _StageCard(
                  title: item.title,
                  status: item.status,
                  detail: item.detail,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('建议迁移顺序', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(migrationSummary, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onOpenProjects,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('项目'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenScriptWorkspace,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('脚本工作区'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenProductionWorkspace,
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: const Text('制作工作区'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenTasks,
                    icon: const Icon(Icons.checklist_outlined),
                    label: const Text('任务中心'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenQuality,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('质量评审'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _ModeSegmentedButton extends StatelessWidget {
  const _ModeSegmentedButton({required this.mode, required this.onChanged});

  final ShortVideoMode mode;
  final ValueChanged<ShortVideoMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ShortVideoMode>(
      segments: const [
        ButtonSegment(
          value: ShortVideoMode.animated,
          icon: Icon(Icons.auto_awesome_outlined),
          label: Text('动漫短剧'),
        ),
        ButtonSegment(
          value: ShortVideoMode.liveAction,
          icon: Icon(Icons.person_outline),
          label: Text('真人短剧'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        onChanged(selection.first);
      },
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.title,
    required this.status,
    required this.detail,
  });

  final String title;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              status,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CandidateCompareCard extends StatelessWidget {
  const _CandidateCompareCard({required this.item});

  final ShortVideoCandidateCompareItemUi item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分镜 #${item.storyboardNumericId}'
              '${item.scriptNumericId != null ? ' · 脚本 #${item.scriptNumericId}' : ''}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(item.readinessLine, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              item.qualityLine,
              style: theme.textTheme.bodySmall?.copyWith(color: outline),
            ),
            if ((item.referenceImageUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.referenceImageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Text('参考图不可预览'),
                  ),
                ),
              ),
            ],
            if (item.liveActionReferenceShotUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '真人参考镜头 ${item.liveActionReferenceShotUrls.length} 条',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                item.liveActionReferenceShotUrls.take(2).join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
            ],
            if ((item.selectedVideoUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('当前视频', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                item.selectedVideoUrl!,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.onSetCurrent != null)
                  FilledButton.tonal(
                    onPressed: item.onSetCurrent,
                    child: const Text('设为当前'),
                  ),
                if (item.onOpenRework != null)
                  OutlinedButton(
                    onPressed: item.onOpenRework,
                    child: const Text('局部返工'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $value', style: theme.textTheme.labelMedium),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({required this.item});

  final ShortVideoReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.ready
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          item.ready
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                item.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
