import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../../rust_api.dart';

part 'agent_memory_view/memory_widgets.dart';

/// Localized tier label for summaries outside this view (e.g. state widget).
String agentMemoryTierDisplayLabel(AppLocalizations l10n, String tier) =>
    _memoryTierLabel(l10n, tier);

class ProjectsAgentMemoryWorkbenchDialogViewModel {
  const ProjectsAgentMemoryWorkbenchDialogViewModel({
    required this.projects,
    required this.memoryRows,
    required this.costOverview,
    required this.memorySummary,
    required this.statusLine,
    required this.loadingProjects,
    required this.loadingMemory,
    required this.loadingCostOverview,
    required this.appendingMemory,
    required this.clearingMemory,
    required this.optimizingMemory,
    required this.canOptimizeVideoMemory,
    required this.queryType,
    required this.clearType,
    required this.memoryTier,
    required this.queryTypeOptions,
    required this.clearTypeOptions,
    required this.memoryTierOptions,
    required this.appendTypeOptions,
    required this.automationModeOptions,
    required this.projectIdCtrl,
    required this.agentTypeCtrl,
    required this.episodesIdCtrl,
    required this.queryTypeCtrl,
    required this.memoryTierCtrl,
    required this.scopeSignatureCtrl,
    required this.appendContentCtrl,
    required this.appendRoleCtrl,
    required this.appendTypeCtrl,
    required this.appendMemoryTierCtrl,
    required this.appendNameCtrl,
    required this.clearTypeCtrl,
    required this.automationModeCtrl,
    required this.appendType,
    required this.appendMemoryTier,
    required this.automationMode,
  });

  final List<ProjectRow> projects;
  final List<AgentMemoryHistoryItem> memoryRows;
  final AgentMemoryCostOverview? costOverview;
  final String? memorySummary;
  final String? statusLine;
  final bool loadingProjects;
  final bool loadingMemory;
  final bool loadingCostOverview;
  final bool appendingMemory;
  final bool clearingMemory;
  final bool optimizingMemory;
  final bool canOptimizeVideoMemory;
  final String queryType;
  final String clearType;
  final String memoryTier;
  final List<String> queryTypeOptions;
  final List<String> clearTypeOptions;
  final List<String> memoryTierOptions;
  final List<String> appendTypeOptions;
  final List<String> automationModeOptions;
  final TextEditingController projectIdCtrl;
  final TextEditingController agentTypeCtrl;
  final TextEditingController episodesIdCtrl;
  final TextEditingController queryTypeCtrl;
  final TextEditingController memoryTierCtrl;
  final TextEditingController scopeSignatureCtrl;
  final TextEditingController appendContentCtrl;
  final TextEditingController appendRoleCtrl;
  final TextEditingController appendTypeCtrl;
  final TextEditingController appendMemoryTierCtrl;
  final TextEditingController appendNameCtrl;
  final TextEditingController clearTypeCtrl;
  final TextEditingController automationModeCtrl;
  final String appendType;
  final String appendMemoryTier;
  final String automationMode;
}

class ProjectsAgentMemoryWorkbenchDialogViewCallbacks {
  const ProjectsAgentMemoryWorkbenchDialogViewCallbacks({
    required this.onReloadProjects,
    required this.onQueryMemory,
    required this.onLoadCostOverview,
    required this.onAppendMemory,
    required this.onClearMemory,
    required this.onOptimizeVideoMemory,
    required this.onQueryTypeChanged,
    required this.onMemoryTierChanged,
    required this.onAppendTypeChanged,
    required this.onAppendMemoryTierChanged,
    required this.onClearTypeChanged,
    required this.onAutomationModeChanged,
    required this.onClose,
  });

  final Future<void> Function() onReloadProjects;
  final Future<void> Function() onQueryMemory;
  final Future<void> Function() onLoadCostOverview;
  final Future<void> Function() onAppendMemory;
  final Future<void> Function() onClearMemory;
  final Future<void> Function() onOptimizeVideoMemory;
  final ValueChanged<String> onQueryTypeChanged;
  final ValueChanged<String> onMemoryTierChanged;
  final ValueChanged<String> onAppendTypeChanged;
  final ValueChanged<String> onAppendMemoryTierChanged;
  final ValueChanged<String> onClearTypeChanged;
  final ValueChanged<String> onAutomationModeChanged;
  final VoidCallback onClose;
}

/// Agent 记忆工作台视图，承载查询结果、追加与清理表单布局。
class ProjectsAgentMemoryWorkbenchDialogView extends StatelessWidget {
  const ProjectsAgentMemoryWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectsAgentMemoryWorkbenchDialogViewModel model;
  final ProjectsAgentMemoryWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    final optimizeEnabled =
        model.canOptimizeVideoMemory && !model.optimizingMemory;
    final memoryInsights = _buildAgentMemoryInsights(model.memoryRows, l10n);
    final memoryPreviewById = <String, _AgentMemoryPreview>{
      for (final preview in memoryInsights.previews) preview.memoryId: preview,
    };
    final memoryTierGroups = _buildMemoryTierGroups(model.memoryRows, l10n);
    final costOverviewLine = _buildCostOverviewLine(l10n, model.costOverview);
    final executionChecklist = _buildScopedExecutionChecklist(
      model,
      memoryInsights,
      l10n,
    );
    return AlertDialog(
      title: Text(l10n.agentMemoryWorkbenchTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.agentMemoryWorkbenchIntro,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.loadingProjects
                        ? null
                        : callbacks.onReloadProjects,
                    child: Text(
                      model.loadingProjects
                          ? l10n.projectsBusyProcessing
                          : l10n.agentMemoryReloadProjects,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingMemory
                        ? null
                        : callbacks.onQueryMemory,
                    child: Text(
                      model.loadingMemory
                          ? l10n.projectsBusyProcessing
                          : l10n.agentMemoryQueryMemory,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingCostOverview
                        ? null
                        : callbacks.onLoadCostOverview,
                    child: Text(
                      model.loadingCostOverview
                          ? l10n.projectsBusyProcessing
                          : l10n.agentMemoryLoadCostOverview,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: optimizeEnabled
                        ? callbacks.onOptimizeVideoMemory
                        : null,
                    child: Text(
                      model.optimizingMemory
                          ? l10n.projectsBusyProcessing
                          : l10n.agentMemoryOptimizeVideo,
                    ),
                  ),
                ],
              ),
              if (model.projects.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.agentMemoryProjectsPreviewLine(
                    model.projects.length,
                    model.projects
                        .take(4)
                        .map(
                          (p) =>
                              '#${p.numericId} ${p.name ?? l10n.agentMemoryUnnamedProject}',
                        )
                        .join(', '),
                    model.projects.length > 4 ? '…' : '',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.projectIdCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agentMemoryFieldProjectNumericId,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: model.agentTypeCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agentMemoryFieldAgentType,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.episodesIdCtrl,
                decoration: InputDecoration(
                  labelText: l10n.agentMemoryFieldEpisodesIdOptional,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.scopeSignatureCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.agentMemoryFieldScopeSignatureOptional,
                  helperText: l10n.agentMemoryFieldScopeSignatureHelper,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: model.queryType,
                decoration: InputDecoration(
                  labelText: l10n.agentMemoryFieldQueryType,
                  helperText: l10n.agentMemoryFieldQueryTypeHelper,
                ),
                items: model.queryTypeOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    callbacks.onQueryTypeChanged(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: model.memoryTier,
                decoration: InputDecoration(
                  labelText: l10n.agentMemoryFieldMemoryTier,
                  helperText: l10n.agentMemoryFieldMemoryTierHelper,
                ),
                items: model.memoryTierOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_memoryTierLabel(l10n, value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    callbacks.onMemoryTierChanged(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: model.automationMode,
                decoration: InputDecoration(
                  labelText: l10n.agentMemoryFieldAutomationMode,
                  helperText: l10n.agentMemoryFieldAutomationModeHelper,
                ),
                items: model.automationModeOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    callbacks.onAutomationModeChanged(value);
                  }
                },
              ),
              const SizedBox(height: 4),
              Text(
                l10n.agentMemoryIsolateHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.agentMemoryOptimizeScopeHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (!model.canOptimizeVideoMemory) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.agentMemoryOptimizeEnableHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (model.memorySummary != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.memorySummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (costOverviewLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  costOverviewLine,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.summary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.summary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.videoSummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.videoSummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.efficiencySummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.efficiencySummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.bucketPrioritySummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.bucketPrioritySummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.recommendation != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.agentMemoryRecommendationPrefix}'
                  '${memoryInsights.recommendation}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (executionChecklist != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        executionChecklist,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: outline),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.agentMemoryCopyChecklistTooltip,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: executionChecklist),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.agentMemoryChecklistCopiedSnack)),
                        );
                      },
                      icon: const Icon(Icons.copy_all_rounded),
                    ),
                  ],
                ),
              ],
              if (model.memoryRows.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.agentMemoryMemoryRowCount(model.memoryRows.length),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ...memoryTierGroups.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        l10n.agentMemoryTierGroupHeader(
                          group.label,
                          group.rows.length,
                          group.lastInjectedLabel,
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      ...group.rows.take(6).map((item) {
                        final preview =
                            memoryPreviewById[item.id] ??
                            _buildAgentMemoryPreview(item);
                        final titleSegments = <String>[
                          if (preview.memoryName.isNotEmpty) preview.memoryName,
                          preview.role,
                          l10n.agentMemoryCharsAbbr(preview.charCount),
                          if (preview.classificationLabel.isNotEmpty)
                            _displayMemoryClass(
                              l10n,
                              preview.classificationLabel,
                            ),
                          if (preview.actionLabel.isNotEmpty)
                            _displayMemoryAction(l10n, preview.actionLabel),
                        ];
                        final subtitleSegments = <String>[
                          if (preview.memoryId.isNotEmpty) preview.memoryId,
                          if (preview.scopeLabel.isNotEmpty) preview.scopeLabel,
                          if (preview.subjectLabel.isNotEmpty)
                            l10n.agentMemorySubjectLabel(preview.subjectLabel),
                          if (preview.signalLabel.isNotEmpty)
                            l10n.agentMemorySignalsLabel(
                              _formatSignalLabelDisplay(
                                l10n,
                                preview.signalLabel,
                              ),
                            ),
                          preview.shortContent,
                        ];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(titleSegments.join(' · ')),
                          subtitle: Text(subtitleSegments.join(' · ')),
                          trailing: preview.isDuplicated
                              ? Chip(
                                  label: Text(l10n.agentMemoryDuplicateChip),
                                  visualDensity: VisualDensity.compact,
                                )
                              : null,
                        );
                      }),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.agentMemoryAppendSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.appendType,
                      decoration: InputDecoration(
                        labelText: l10n.agentMemoryFieldAppendType,
                        helperText: l10n.agentMemoryFieldAppendTypeHelper,
                      ),
                      items: model.appendTypeOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          callbacks.onAppendTypeChanged(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.appendMemoryTier,
                      decoration: InputDecoration(
                        labelText: l10n.agentMemoryFieldAppendMemoryTier,
                        helperText:
                            l10n.agentMemoryFieldAppendMemoryTierHelper,
                      ),
                      items: model.memoryTierOptions
                          .where((value) => value != 'all')
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_memoryTierLabel(l10n, value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          callbacks.onAppendMemoryTierChanged(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.appendRoleCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agentMemoryFieldRole,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: model.appendNameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.agentMemoryFieldNameOptional,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: model.appendingMemory
                          ? null
                          : callbacks.onAppendMemory,
                      child: Text(
                        model.appendingMemory
                            ? l10n.projectsBusyProcessing
                            : l10n.agentMemoryAppendButton,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.appendContentCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.agentMemoryFieldMemoryContent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.agentMemoryClearSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.clearType,
                      decoration: InputDecoration(
                        labelText: l10n.agentMemoryFieldClearType,
                        helperText: l10n.agentMemoryFieldClearTypeHelper,
                      ),
                      items: model.clearTypeOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          callbacks.onClearTypeChanged(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: model.clearingMemory
                          ? null
                          : callbacks.onClearMemory,
                      child: Text(
                        model.clearingMemory
                            ? l10n.projectsBusyProcessing
                            : l10n.agentMemoryClearRun,
                      ),
                    ),
                  ),
                ],
              ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.statusLine!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.helpHubDialogClose),
        ),
      ],
    );
  }
}
