import 'package:flutter/material.dart';

import '../rust_api.dart';

/// Widget for managing benchmark cases (sample pool)
class BenchmarkCasesWorkbench extends StatelessWidget {
  const BenchmarkCasesWorkbench({
    super.key,
    required this.cases,
    required this.projectIdController,
    required this.qualityReviewIdController,
    required this.promoteSummaryController,
    required this.promoteTagsController,
    required this.promoteCaseType,
    required this.busy,
    required this.onFetchCases,
    required this.onPromoteCase,
    required this.onPromoteCaseTypeChanged,
  });

  final List<BenchmarkCaseV1> cases;
  final TextEditingController projectIdController;
  final TextEditingController qualityReviewIdController;
  final TextEditingController promoteSummaryController;
  final TextEditingController promoteTagsController;
  final String promoteCaseType;
  final bool busy;
  final VoidCallback onFetchCases;
  final VoidCallback onPromoteCase;
  final ValueChanged<String> onPromoteCaseTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.benchmarkPromoteCardTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onFetchCases,
              child: Text(l10n.benchmarkActionFetchSamplePool),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: projectIdController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.benchmarkProjectIdOptional,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.benchmarkPromoteCardTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qualityReviewIdController,
                  decoration: InputDecoration(
                    labelText: l10n.benchmarkLabelQualityReviewId,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: promoteCaseType,
                  decoration: InputDecoration(
                    labelText: l10n.benchmarkLabelSampleType,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'bad_case',
                      child: Text(l10n.benchmarkSampleTypeBadCase),
                    ),
                    DropdownMenuItem(
                      value: 'golden',
                      child: Text(l10n.benchmarkSampleTypeGolden),
                    ),
                    DropdownMenuItem(
                      value: 'regression_guard',
                      child: Text(l10n.benchmarkSampleTypeRegressionGuard),
                    ),
                  ],
                  onChanged: busy ? null : (value) {
                    if (value != null) {
                      onPromoteCaseTypeChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: promoteSummaryController,
                  decoration: InputDecoration(
                    labelText: l10n.benchmarkLabelSampleSummary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: promoteTagsController,
                  decoration: InputDecoration(
                    labelText: l10n.benchmarkLabelTagsCommaSeparated,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: busy ||
                          qualityReviewIdController.text.trim().isEmpty ||
                          promoteSummaryController.text.trim().isEmpty
                      ? null
                      : onPromoteCase,
                  child: Text(l10n.benchmarkButtonPromoteToSample),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (cases.isNotEmpty) ...[
          Text(
            l10n.benchmarkSummaryCases(
              cases.length,
              cases
                  .take(3)
                  .map((item) => '#${item.projectId}/${item.caseType}:${item.stage}')
                  .join(', '),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ...cases.take(6).map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item.caseType} · P${item.projectId} · ${item.stage}',
                  ),
                  subtitle: Text(
                    l10n.benchmarkCaseRowSubtitle(
                      item.summary,
                      '${item.weight}',
                      item.issueTags.join('/'),
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
