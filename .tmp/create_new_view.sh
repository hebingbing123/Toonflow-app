#!/bin/bash

# Create new view.dart with part directives

cat > frontend/lib/short_video_space/view_new.dart << 'EOFHEADER'
import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'publish_copy_editor.dart';
import 'publish_schedule_calendar.dart';

// Part files
part 'view_project_selector.dart';
part 'view_production_panel.dart';
part 'view_candidate_compare.dart';
part 'view_publish_drafts.dart';
part 'view_publish_calendar.dart';
part 'view_publish_jobs.dart';
part 'view_publish_audit.dart';

EOFHEADER

# Extract data models (lines 8-500)
sed -n '8,500p' frontend/lib/short_video_space/view.dart.backup >> frontend/lib/short_video_space/view_new.dart

# Add simplified ShortVideoSpaceView class
cat >> frontend/lib/short_video_space/view_new.dart << 'EOFCLASS'

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
          '参考 MoneyPrinterTurbo 的长处，先把"主题到成片"的链路聚成一个入口，再逐步把脚本、素材、旁白、字幕和质检串成标准流程。',
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
        _ProjectSelectorPanel(
          mode: mode,
          onModeChanged: onModeChanged,
          loadingProjects: loadingProjects,
          projectOptions: projectOptions,
          selectedProjectId: selectedProjectId,
          onProjectChanged: onProjectChanged,
          onRefreshProjects: onRefreshProjects,
          videoRatio: videoRatio,
          onVideoRatioChanged: onVideoRatioChanged,
          targetMarket: targetMarket,
          onTargetMarketChanged: onTargetMarketChanged,
          targetPlatforms: targetPlatforms,
          onPublishPlatformTapped: onPublishPlatformTapped,
          durationStrategy: durationStrategy,
          onDurationStrategyChanged: onDurationStrategyChanged,
          voiceProfile: voiceProfile,
          onVoiceProfileChanged: onVoiceProfileChanged,
          subtitleStyle: subtitleStyle,
          onSubtitleStyleChanged: onSubtitleStyleChanged,
          bgmStrategy: bgmStrategy,
          onBgmStrategyChanged: onBgmStrategyChanged,
          creatingProject: creatingProject,
          onCreateProject: onCreateProject,
          savingProjectConfig: savingProjectConfig,
          onSaveProjectConfig: onSaveProjectConfig,
          onOpenProjects: onOpenProjects,
          projectConfigLine: projectConfigLine,
          loadingProjectOverview: loadingProjectOverview,
          projectReadinessSummary: projectReadinessSummary,
          visualLabel: visualLabel,
          directionLabel: directionLabel,
          projectMetrics: projectMetrics,
        ),
        const SizedBox(height: 16),
        _ProductionPanel(
          spaceOverviewSummary: spaceOverviewSummary,
          overviewMetrics: overviewMetrics,
          qualitySummaryLine: qualitySummaryLine,
          badCaseMetrics: badCaseMetrics,
          recentTaskLines: recentTaskLines,
          assetsOverviewPanelUi: assetsOverviewPanelUi,
          assemblyPanelUi: assemblyPanelUi,
          exportCheckPanelUi: exportCheckPanelUi,
          onOpenProductionForAssemblyExport: onOpenProductionForAssemblyExport,
          onOpenAssemblyClipDeskOps: onOpenAssemblyClipDeskOps,
          onOpenAssemblyDefaultsEditor: onOpenAssemblyDefaultsEditor,
        ),
        _CandidateComparePanel(
          candidateCardUi: candidateCardUi,
          candidateComparePanelUi: candidateComparePanelUi,
          onOpenProjectsForCandidateAssets: onOpenProjectsForCandidateAssets,
        ),
        const SizedBox(height: 16),
        _PublishDraftsPanel(publishPanelUi: publishPanelUi),
        _PublishCalendarPanel(publishPanelUi: publishPanelUi),
        _PublishJobsPanel(publishPanelUi: publishPanelUi),
        _PublishAuditPanel(publishPanelUi: publishPanelUi),
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

EOFCLASS

# Extract helper widgets (lines 2126-end)
sed -n '2126,$p' frontend/lib/short_video_space/view.dart.backup >> frontend/lib/short_video_space/view_new.dart

# Replace old file with new one
mv frontend/lib/short_video_space/view_new.dart frontend/lib/short_video_space/view.dart

echo "Refactored view.dart created successfully!"
wc -l frontend/lib/short_video_space/view.dart
