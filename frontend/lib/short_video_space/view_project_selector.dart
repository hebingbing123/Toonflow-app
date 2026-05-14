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
    this.onResetConfirmationDontShowAgain,
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
  final void Function(BuildContext context)? onResetConfirmationDontShowAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final l10n = resolveAppLocalizationsForErrors(context);
    
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shortVideoSpaceTargetConfiguration, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            l10n.shortVideoSpaceConfigurationDescription,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedProjectId,
                  decoration: InputDecoration(
                    labelText: l10n.shortVideoSpaceTargetProject,
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
                label: Text(
                  loadingProjects
                      ? l10n.shortVideoSpaceLoading
                      : l10n.shortVideoSpaceRefreshProjects,
                ),
              ),
            ],
          ),
          if (onResetConfirmationDontShowAgain != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onResetConfirmationDontShowAgain!.call(context),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(l10n.shortVideoSpaceRestoreRiskyConfirmation),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _ModeSegmentedButton(mode: mode, onChanged: onModeChanged),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: '9:16',
                label: Text(l10n.shortVideoSpaceAspectRatioPortrait916),
              ),
              ButtonSegment(
                value: '16:9',
                label: Text(l10n.shortVideoSpaceAspectRatioLandscape169),
              ),
              ButtonSegment(
                value: '1:1',
                label: Text(l10n.shortVideoSpaceAspectRatioSquare11),
              ),
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
          Text(
            l10n.shortVideoSpacePublishMarketPlatformTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('tm-$selectedProjectId'),
            initialValue: targetMarket,
            decoration: InputDecoration(
              labelText: l10n.shortVideoSpaceTargetMarketLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: 'domestic',
                child: Text(l10n.shortVideoSpaceTargetMarketDomestic),
              ),
              DropdownMenuItem(
                value: 'overseas',
                child: Text(l10n.shortVideoSpaceTargetMarketOverseas),
              ),
              DropdownMenuItem(
                value: 'both',
                child: Text(l10n.shortVideoSpaceTargetMarketBoth),
              ),
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
            l10n.shortVideoSpaceTargetPlatformsHint,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kShortVideoPublishPlatformIdsInDisplayOrder
                .map(
                  (id) => FilterChip(
                    label: Text(shortVideoPublishPlatformLabel(l10n, id)),
                    selected: targetPlatforms.contains(id),
                    onSelected: loadingProjects
                        ? null
                        : (_) {
                            onPublishPlatformTapped(id);
                          },
                    showCheckmark: false,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.shortVideoSpaceDurationStrategyTitle,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'short',
                label: Text(l10n.shortVideoSpaceDurationShort),
              ),
              ButtonSegment(
                value: 'medium',
                label: Text(l10n.shortVideoSpaceDurationMedium),
              ),
              ButtonSegment(
                value: 'long',
                label: Text(l10n.shortVideoSpaceDurationLong),
              ),
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
          Text(
            l10n.shortVideoSpaceVoiceSubtitleBgmTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey<String>('vp-$selectedProjectId'),
            initialValue: voiceProfile,
            decoration: InputDecoration(
              labelText: l10n.shortVideoSpaceVoiceProfileLabel,
              hintText: l10n.shortVideoSpaceVoiceProfileHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: onVoiceProfileChanged,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey<String>('ss-$selectedProjectId'),
            initialValue: subtitleStyle,
            decoration: InputDecoration(
              labelText: l10n.shortVideoSpaceSubtitleStyleLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: onSubtitleStyleChanged,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey<String>('bgm-$selectedProjectId'),
            initialValue: bgmStrategy,
            decoration: InputDecoration(
              labelText: l10n.shortVideoSpaceBgmStrategyLabel,
              border: const OutlineInputBorder(),
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
                label: Text(
                  creatingProject
                      ? l10n.shortVideoSpaceCreatingProject
                      : l10n.shortVideoSpaceCreateProjectDirect,
                ),
              ),
              FilledButton.icon(
                onPressed: savingProjectConfig ? null : onSaveProjectConfig,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  savingProjectConfig
                      ? l10n.shortVideoSpaceSavingProjectConfig
                      : l10n.shortVideoSpaceSaveProjectConfigWriteback,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onOpenProjects,
                icon: const Icon(Icons.tune_outlined),
                label: Text(l10n.shortVideoSpaceOpenProjectsRefine),
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
                ? l10n.shortVideoSpaceLoadingProjectReadiness
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
                  _MetricChip(
                    label: l10n.shortVideoSpaceMetricChipVisual,
                    value: visualLabel!,
                  ),
                if (directionLabel != null)
                  _MetricChip(
                    label: l10n.shortVideoSpaceMetricChipManual,
                    value: directionLabel!,
                  ),
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
