import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';

import '../rust_api.dart';

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
        padding: const EdgeInsets.all(12),
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
                  onPressed: busy ? null : onFetchExperiments,
                  child: Text(l10n.benchmarkActionFetchExperiments),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: experimentIdController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelExperimentId,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onFetchExperimentDetail,
                  child: Text(l10n.benchmarkButtonLoadDetail),
                ),
                FilledButton.tonal(
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onStartExperiment,
                  child: Text(l10n.benchmarkButtonStart),
                ),
                FilledButton.tonal(
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onCancelExperiment,
                  child: Text(l10n.benchmarkButtonCancel),
                ),
                FilledButton.tonal(
                  onPressed: busy || experimentIdController.text.trim().isEmpty
                      ? null
                      : onFetchRoi,
                  child: Text(l10n.benchmarkActionFetchRoi),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: experimentNameController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelNewExperimentName,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            TextField(
              controller: stageScopeController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelStageScopeComma,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: baselineLabelController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelBaselineVariantLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: variantsJsonController,
              maxLines: 14,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelVariantsJsonArray,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: busy || experimentNameController.text.trim().isEmpty
                  ? null
                  : onCreateExperiment,
              child: Text(l10n.benchmarkButtonCreateExperiment),
            ),
            const SizedBox(height: 12),
            if (experiments.isNotEmpty) ...[
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
              const SizedBox(height: 8),
              ...experiments.take(6).map(
                    (item) => ListTile(
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
            ],
            if (experimentDetail != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.benchmarkExperimentDetailHeader(
                  experimentDetail!.experiment.name.trim().isEmpty
                      ? experimentDetail!.experiment.id
                      : experimentDetail!.experiment.name,
                  experimentDetail!.variants.length,
                ),
              ),
              const SizedBox(height: 6),
              ...experimentDetail!.variants.map(
                (variant) => Text(
                  '${variant.label} · baseline=${variant.isBaseline} · '
                  'budget=${variant.memoryBudgetSnapshot['budgetTier'] ?? '-'} · '
                  'model=${variant.modelRouteSnapshot['modelName'] ?? '-'}',
                ),
              ),
            ],
            if (roiSummary != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.benchmarkRoiHeader(
                  roiSummary!.overallConclusionType,
                  roiSummary!.overallRationale,
                ),
              ),
              const SizedBox(height: 6),
              ...roiSummary!.variantComparisons.map(
                (item) => Text(
                  l10n.benchmarkRoiVariantLine(
                    item.variantLabel,
                    item.qualityScoreDelta.toStringAsFixed(2),
                    item.tokenDeltaPercent.toStringAsFixed(1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
