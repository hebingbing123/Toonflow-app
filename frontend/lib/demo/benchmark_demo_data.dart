import '../rust_api.dart';

/// Preloaded benchmark workbench rows for demo mode (browse-only).
class BenchmarkDemoSnapshot {
  const BenchmarkDemoSnapshot({
    required this.cases,
    required this.experiments,
    required this.reviewQueue,
    required this.statusLine,
  });

  final List<BenchmarkCaseV1> cases;
  final List<ExperimentRunV1> experiments;
  final List<ReviewQueueItemV1> reviewQueue;
  final String statusLine;
}

BenchmarkDemoSnapshot buildDemoBenchmarkSnapshot() {
  final l10n = rustApiLookupL10nFromPlatform();
  return BenchmarkDemoSnapshot(
    cases: <BenchmarkCaseV1>[
      BenchmarkCaseV1(
        id: 'bench-case-demo-1',
        projectId: 7,
        scriptId: 3,
        stage: 'storyboard_panel',
        caseType: 'bad_case',
        issueTags: <String>['composition', 'emotion'],
        weight: 2,
        summary: l10n.demoBenchmarkCase1Summary,
        lastVerifiedAt: '2026-05-10T08:00:00Z',
      ),
      BenchmarkCaseV1(
        id: 'bench-case-demo-2',
        projectId: 7,
        scriptId: 3,
        stage: 'video_prompt',
        caseType: 'golden',
        issueTags: <String>['motion'],
        weight: 1,
        summary: l10n.demoBenchmarkCase2Summary,
        lastVerifiedAt: '2026-05-11T10:00:00Z',
      ),
    ],
    experiments: <ExperimentRunV1>[
      ExperimentRunV1(
        id: 'exp-demo-1',
        name: l10n.demoBenchmarkExperimentName,
        status: 'completed',
        sampleTier: 'smoke',
        stageScope: <String>['storyboard_panel', 'video_prompt'],
        baselineVariantId: 'baseline',
        createdAt: '2026-05-01T00:00:00Z',
        startedAt: '2026-05-01T00:05:00Z',
        completedAt: '2026-05-01T01:00:00Z',
      ),
    ],
    reviewQueue: <ReviewQueueItemV1>[
      ReviewQueueItemV1(
        id: 'review-demo-1',
        experimentRunId: 'exp-demo-1',
        experimentResultId: 'result-demo-1',
        reviewType: 'quality_gate',
        status: 'pending',
        priority: 1,
        prompt: l10n.demoBenchmarkReviewPrompt,
        submittedScore: null,
      ),
    ],
    statusLine: l10n.demoBenchmarkStatusLine,
  );
}
