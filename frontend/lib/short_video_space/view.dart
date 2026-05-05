import 'package:flutter/material.dart';

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
    required this.readinessIntro,
    required this.readinessCountLabel,
    required this.readinessGapSummary,
    required this.readinessItems,
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
  final String readinessIntro;
  final String readinessCountLabel;
  final String readinessGapSummary;
  final List<ShortVideoReadinessItem> readinessItems;
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
