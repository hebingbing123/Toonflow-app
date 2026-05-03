import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/benchmark/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('summarizeBenchmarkCases formats preview', () {
    final summary = summarizeBenchmarkCases([
      const BenchmarkCaseV1(
        id: 'c1',
        projectId: 7,
        scriptId: 2,
        stage: 'video_prompt',
        caseType: 'bad_case',
        issueTags: ['人物一致性'],
        weight: 3,
        summary: '脸漂了',
        lastVerifiedAt: null,
      ),
    ]);
    expect(summary, contains('样本 1 条'));
    expect(summary, contains('#7/bad_case:video_prompt'));
  });

  test('summarizeBenchmarkGate includes decision counts', () {
    final summary = summarizeBenchmarkGate(
      GateDecisionEnvelopeV1(
        experimentRunId: 'exp-1',
        assessments: const [
          GateAssessmentV1(
            variantId: 'v1',
            variantLabel: 'baseline',
            autoDecision: 'approved',
            avgQualityScore: 8.1,
            qualityScoreDelta: 0.0,
            totalTokens: 1000,
            tokenDeltaPercent: 0,
            severeGuardFailures: 0,
          ),
          GateAssessmentV1(
            variantId: 'v2',
            variantLabel: 'candidate',
            autoDecision: 'blocked',
            avgQualityScore: 7.2,
            qualityScoreDelta: -0.5,
            totalTokens: 1300,
            tokenDeltaPercent: 30,
            severeGuardFailures: 1,
          ),
        ],
        latestDecisions: const [],
      ),
    );
    expect(summary, contains('approved 1'));
    expect(summary, contains('blocked 1'));
  });

  test('benchmark trend model parses numbers', () {
    final response = BenchmarkTrendsResponseV1.fromJson({
      'weeks': [
        {
          'weekStart': '2026-04-27',
          'completedResults': 4,
          'avgQualityScore': 8.3,
          'totalTokens': 10000,
          'badCaseFailures': 1,
          'approvedCount': 2,
          'blockedCount': 0,
        },
      ],
    });
    expect(response.weeks.single.weekStart, '2026-04-27');
    expect(response.weeks.single.totalTokens, 10000);
  });

  test('summarizeBenchmarkGate counts limited approvals separately', () {
    final summary = summarizeBenchmarkGate(
      GateDecisionEnvelopeV1(
        experimentRunId: 'exp-2',
        assessments: const [
          GateAssessmentV1(
            variantId: 'v1',
            variantLabel: 'candidate-a',
            autoDecision: 'approved_limited',
            avgQualityScore: 8.6,
            qualityScoreDelta: 0.2,
            totalTokens: 1200,
            tokenDeltaPercent: 18,
            severeGuardFailures: 0,
          ),
        ],
        latestDecisions: const [],
      ),
    );
    expect(summary, contains('limited 1'));
  });
}
