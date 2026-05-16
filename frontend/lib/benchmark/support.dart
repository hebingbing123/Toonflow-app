import '../l10n/app_localizations.dart';
import '../rust_api.dart';

String summarizeBenchmarkCases(AppLocalizations l10n, List<BenchmarkCaseV1> cases) {
  if (cases.isEmpty) {
    return l10n.benchmarkSummaryCasesEmpty;
  }
  final preview = cases
      .take(3)
      .map((item) => '#${item.projectId}/${item.caseType}:${item.stage}')
      .join(', ');
  return l10n.benchmarkSummaryCases(cases.length, preview);
}

String summarizeBenchmarkExperiments(
  AppLocalizations l10n,
  List<ExperimentRunV1> experiments,
) {
  if (experiments.isEmpty) {
    return l10n.benchmarkSummaryExperimentsEmpty;
  }
  final preview = experiments
      .take(3)
      .map((item) => '${item.name}(${item.status}/${item.sampleTier})')
      .join(', ');
  return l10n.benchmarkSummaryExperiments(experiments.length, preview);
}

String summarizeBenchmarkReviewQueue(AppLocalizations l10n, List<ReviewQueueItemV1> items) {
  if (items.isEmpty) {
    return l10n.benchmarkSummaryReviewQueueEmpty;
  }
  final pending = items.where((item) => item.status == 'pending').length;
  return l10n.benchmarkSummaryReviewQueue(items.length, pending);
}

String summarizeBenchmarkGate(AppLocalizations l10n, GateDecisionEnvelopeV1? gate) {
  if (gate == null || gate.assessments.isEmpty) {
    return l10n.benchmarkSummaryGateEmpty;
  }
  final blocked = gate.assessments
      .where((item) => item.autoDecision == 'blocked')
      .length;
  final approved = gate.assessments
      .where((item) => item.autoDecision == 'approved')
      .length;
  final limited = gate.assessments
      .where((item) => item.autoDecision == 'approved_limited')
      .length;
  return l10n.benchmarkSummaryGate(gate.assessments.length, approved, limited, blocked);
}

String summarizeBenchmarkTrends(AppLocalizations l10n, BenchmarkTrendsResponseV1? trends) {
  if (trends == null || trends.weeks.isEmpty) {
    return l10n.benchmarkSummaryTrendsEmpty;
  }
  final latest = trends.weeks.last;
  return l10n.benchmarkSummaryTrends(
    trends.weeks.length,
    latest.weekStart,
    latest.avgQualityScore.toStringAsFixed(1),
    '${latest.totalTokens}',
  );
}
