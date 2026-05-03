import '../rust_api.dart';

String summarizeBenchmarkCases(List<BenchmarkCaseV1> cases) {
  if (cases.isEmpty) return '当前没有基线样本';
  final preview = cases
      .take(3)
      .map((item) => '#${item.projectId}/${item.caseType}:${item.stage}')
      .join(', ');
  return '样本 ${cases.length} 条 · $preview';
}

String summarizeBenchmarkExperiments(List<ExperimentRunV1> experiments) {
  if (experiments.isEmpty) return '当前没有实验运行';
  final preview = experiments
      .take(3)
      .map((item) => '${item.name}(${item.status}/${item.sampleTier})')
      .join(', ');
  return '实验 ${experiments.length} 条 · $preview';
}

String summarizeBenchmarkReviewQueue(List<ReviewQueueItemV1> items) {
  if (items.isEmpty) return '当前没有待复核队列';
  final pending = items.where((item) => item.status == 'pending').length;
  return '复核 ${items.length} 条 · 待处理 $pending 条';
}

String summarizeBenchmarkGate(GateDecisionEnvelopeV1? gate) {
  if (gate == null || gate.assessments.isEmpty) return '尚未读取放行门结果';
  final blocked = gate.assessments
      .where((item) => item.autoDecision == 'blocked')
      .length;
  final approved = gate.assessments
      .where((item) => item.autoDecision == 'approved')
      .length;
  final limited = gate.assessments
      .where((item) => item.autoDecision == 'approved_limited')
      .length;
  return '放行评估 ${gate.assessments.length} 个 · approved $approved / limited $limited / blocked $blocked';
}

String summarizeBenchmarkTrends(BenchmarkTrendsResponseV1? trends) {
  if (trends == null || trends.weeks.isEmpty) return '尚未读取趋势';
  final latest = trends.weeks.last;
  return '趋势 ${trends.weeks.length} 周 · 最新 ${latest.weekStart} 质量 ${latest.avgQualityScore.toStringAsFixed(1)} / token ${latest.totalTokens}';
}
