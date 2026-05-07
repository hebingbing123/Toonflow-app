part of 'view.dart';

/// Project selector and configuration panel widget
class _ProjectSelectorPanel extends StatelessWidget {
  const _ProjectSelectorPanel({
    required this.mode,
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
    required this.operationFeedbackIsSuccess,
    required this.loadingProjectOverview,
    required this.projectReadinessSummary,
    required this.visualLabel,
    required this.directionLabel,
    required this.projectMetrics,
  });

  final ShortVideoMode mode;
  final ValueChanged<ShortVideoMode> onModeChanged;
  final bool loadingProjects;
  final List<ShortVideoProjectOption> projectOptions;
  final String? selectedProjectId;
  final ValueChanged<String?> onProjectChanged;
  final VoidCallback onRefreshProjects;
  final String videoRatio;
  final ValueChanged<String> onVideoRatioChanged;
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
  final bool creatingProject;
  final VoidCallback onCreateProject;
  final bool savingProjectConfig;
  final VoidCallback onSaveProjectConfig;
  final VoidCallback onOpenProjects;
  final String? projectConfigLine;
  final bool? operationFeedbackIsSuccess;
  final bool loadingProjectOverview;
  final String projectReadinessSummary;
  final String? visualLabel;
  final String? directionLabel;
  final List<ShortVideoMetricData> projectMetrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('短视频目标配置', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '把创作模式和画幅直接写回项目,后面的脚本与制作流程就能基于同一份项目配置继续工作。',
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: operationFeedbackIsSuccess == true
                    ? theme.colorScheme.primaryContainer
                    : operationFeedbackIsSuccess == false
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: operationFeedbackIsSuccess == true
                      ? theme.colorScheme.primary
                      : operationFeedbackIsSuccess == false
                          ? theme.colorScheme.error
                          : theme.colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    operationFeedbackIsSuccess == true
                        ? Icons.check_circle_outline
                        : operationFeedbackIsSuccess == false
                            ? Icons.error_outline
                            : Icons.info_outline,
                    size: 20,
                    color: operationFeedbackIsSuccess == true
                        ? theme.colorScheme.primary
                        : operationFeedbackIsSuccess == false
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      projectConfigLine!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: operationFeedbackIsSuccess == true
                            ? theme.colorScheme.onPrimaryContainer
                            : operationFeedbackIsSuccess == false
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    );
  }
}
