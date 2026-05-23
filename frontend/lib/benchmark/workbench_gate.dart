import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../rust_api.dart';

/// Widget for managing benchmark promotion gate decisions
class BenchmarkGateWorkbench extends StatelessWidget {
  const BenchmarkGateWorkbench({
    super.key,
    required this.gateSummary,
    required this.trends,
    required this.experimentIdController,
    required this.gateVariantIdController,
    required this.gateDecisionController,
    required this.gateNoteController,
    required this.promoteToBaseline,
    required this.busy,
    required this.onFetchGate,
    required this.onFetchTrends,
    required this.onSubmitGateDecision,
    required this.onPromoteToBaselineChanged,
  });

  final GateDecisionEnvelopeV1? gateSummary;
  final BenchmarkTrendsResponseV1? trends;
  final TextEditingController experimentIdController;
  final TextEditingController gateVariantIdController;
  final TextEditingController gateDecisionController;
  final TextEditingController gateNoteController;
  final bool promoteToBaseline;
  final bool busy;
  final VoidCallback onFetchGate;
  final VoidCallback onFetchTrends;
  final VoidCallback onSubmitGateDecision;
  final ValueChanged<bool> onPromoteToBaselineChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.benchmarkGateCardTitle,
              style: Theme.of(context).textTheme.titleSmall,
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
                      : onFetchGate,
                  child: Text(l10n.benchmarkActionFetchGate),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onFetchTrends,
                  child: Text(l10n.benchmarkActionFetchTrends),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.sm),
            TextField(
              controller: gateVariantIdController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelGateVariantId,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: gateDecisionController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelGateDecisionOptionalAuto,
                hintText: l10n.benchmarkGateDecisionHint,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: gateNoteController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelGateDecisionNote,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.benchmarkGatePromoteBaselineTitle),
              subtitle: Text(l10n.benchmarkGatePromoteBaselineSubtitle),
              value: promoteToBaseline,
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) {
                        onPromoteToBaselineChanged(value);
                      }
                    },
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed:
                  busy ||
                      experimentIdController.text.trim().isEmpty ||
                      gateVariantIdController.text.trim().isEmpty
                  ? null
                  : onSubmitGateDecision,
              child: Text(l10n.benchmarkActionSubmitGateDecision),
            ),
            if (gateSummary != null) ...[
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.benchmarkGateAssessmentsSummary(
                  gateSummary!.assessments.length,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              ...gateSummary!.assessments.map(
                (item) => Text(
                  l10n.benchmarkGateAssessmentRow(
                    item.variantLabel,
                    item.autoDecision,
                    item.qualityScoreDelta.toStringAsFixed(2),
                    '${item.severeGuardFailures}',
                  ),
                ),
              ),
            ],
            if (trends != null) ...[
              const SizedBox(height: StudioSpacing.sm),
              Text(l10n.benchmarkTrendsDataSummary(trends!.weeks.length)),
              const SizedBox(height: StudioSpacing.xs),
              ...trends!.weeks.map(
                (item) => Text(
                  l10n.benchmarkTrendWeekRow(
                    item.weekStart,
                    item.avgQualityScore.toStringAsFixed(1),
                    '${item.totalTokens}',
                    '${item.approvedCount}',
                    '${item.blockedCount}',
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
