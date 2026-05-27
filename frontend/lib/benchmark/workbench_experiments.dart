import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../rust_api.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// Widget for managing benchmark experiments
class BenchmarkExperimentsWorkbench extends StatelessWidget {
  const BenchmarkExperimentsWorkbench({
    super.key,
    required this.experiments,
    required this.experimentDetail,
    required this.roiSummary,
    required this.experimentIdController,
    required this.experimentNameController,
    required this.stageScopeController,
    required this.baselineLabelController,
    required this.variantsJsonController,
    required this.sampleTier,
    required this.busy,
    required this.onFetchExperiments,
    required this.onFetchExperimentDetail,
    required this.onStartExperiment,
    required this.onCancelExperiment,
    required this.onFetchRoi,
    required this.onCreateExperiment,
    required this.onSampleTierChanged,
    required this.onExperimentSelected,
  });

  final List<ExperimentRunV1> experiments;
  final ExperimentDetailV1? experimentDetail;
  final RoiEvidenceSummaryV1? roiSummary;
  final TextEditingController experimentIdController;
  final TextEditingController experimentNameController;
  final TextEditingController stageScopeController;
  final TextEditingController baselineLabelController;
  final TextEditingController variantsJsonController;
  final String sampleTier;
  final bool busy;
  final VoidCallback onFetchExperiments;
  final VoidCallback onFetchExperimentDetail;
  final VoidCallback onStartExperiment;
  final VoidCallback onCancelExperiment;
  final VoidCallback onFetchRoi;
  final VoidCallback onCreateExperiment;
  final ValueChanged<String> onSampleTierChanged;
  final ValueChanged<String> onExperimentSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.benchmarkExperimentCardTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: busy ? null : onFetchExperiments,
                  child: Text(l10n.benchmarkActionFetchExperiments),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: experimentIdController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelExperimentId,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            StudioDenseActionRow(
              spacing: StudioSpacing.xs,
              children: [
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onFetchExperimentDetail,
                  child: Text(l10n.benchmarkButtonLoadDetail),
                ),
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onStartExperiment,
                  child: Text(l10n.benchmarkButtonStart),
                ),
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onCancelExperiment,
                  child: Text(l10n.benchmarkButtonCancel),
                ),
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onFetchRoi,
                  child: Text(l10n.benchmarkActionFetchRoi),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.sm),
            TextField(
              controller: experimentNameController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelNewExperimentName,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            StudioDropdownButtonFormField<String>(
              initialValue: sampleTier,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSampleTierSet,
              ),
              items: [
                DropdownMenuItem(
                  value: 'smoke',
                  child: Text(l10n.benchmarkExperimentSuiteSmoke),
                ),
                DropdownMenuItem(
                  value: 'core',
                  child: Text(l10n.benchmarkExperimentSuiteCore),
                ),
                DropdownMenuItem(
                  value: 'full',
                  child: Text(l10n.benchmarkExperimentSuiteFull),
                ),
              ],
              onChanged: busy ? null : (value) {
                if (value != null) {
                  onSampleTierChanged(value);
                }
              },
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: stageScopeController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelStageScopeComma,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: baselineLabelController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelBaselineVariantLabel,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: variantsJsonController,
              maxLines: 14,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelVariantsJsonArray,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: busy || experimentNameController.text.trim().isEmpty
                  ? null
                  : onCreateExperiment,
              child: Text(l10n.benchmarkButtonCreateExperiment),
            ),
            const SizedBox(height: StudioSpacing.sm),
            if (experiments.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.benchmarkSummaryExperimentsEmpty,
                icon: Icons.science_outlined,
                actionLabel: l10n.benchmarkActionFetchExperiments,
                onAction: busy ? null : onFetchExperiments,
              )
            else ...[
              Text(
                l10n.benchmarkSummaryExperiments(
                  experiments.length,
                  experiments
                      .take(3)
                      .map((item) => '${item.name}(${item.status}/${item.sampleTier})')
                      .join(', '),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: StudioSpacing.xs),
              ...studioStaggeredChildren(
                experiments.take(6).map(
                      (item) => StudioListRow(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.l10nBatch_c084376ea9(item.name, item.status)),
                        subtitle: Text(
                          l10n.benchmarkExperimentRowSubtitle(
                            item.sampleTier,
                            item.stageScope.join(', '),
                            item.id,
                          ),
                        ),
                        onTap: () => onExperimentSelected(item.id),
                      ),
                    ),
                entranceKey: experiments.length,
              ),
            ],
            if (experimentDetail != null) ...[
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.benchmarkExperimentDetailHeader(
                  experimentDetail!.experiment.name.trim().isEmpty
                      ? experimentDetail!.experiment.id
                      : experimentDetail!.experiment.name,
                  experimentDetail!.variants.length,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              ...studioStaggeredChildren(
                experimentDetail!.variants.map(
                  (variant) => Text(
                    '${variant.label} · baseline=${variant.isBaseline} · '
                    'budget=${variant.memoryBudgetSnapshot['budgetTier'] ?? '-'} · '
                    'model=${variant.modelRouteSnapshot['modelName'] ?? '-'}',
                  ),
                ),
                entranceKey: experimentDetail!.variants.length,
              ),
            ],
            if (roiSummary != null) ...[
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.benchmarkRoiHeader(
                  roiSummary!.overallConclusionType,
                  roiSummary!.overallRationale,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              ...studioStaggeredChildren(
                roiSummary!.variantComparisons.map(
                  (item) => Text(
                    l10n.benchmarkRoiVariantLine(
                      item.variantLabel,
                      item.qualityScoreDelta.toStringAsFixed(2),
                      item.tokenDeltaPercent.toStringAsFixed(1),
                    ),
                  ),
                ),
                entranceKey: roiSummary!.variantComparisons.length,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
