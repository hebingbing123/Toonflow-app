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
  return BenchmarkDemoSnapshot(
    cases: const <BenchmarkCaseV1>[
      BenchmarkCaseV1(
        id: 'bench-case-demo-1',
        projectId: 7,
        scriptId: 3,
        stage: 'storyboard_panel',
        caseType: 'bad_case',
        issueTags: <String>['composition', 'emotion'],
        weight: 2,
        summary: '演示：分镜情绪表达偏弱，需加强特写与光影对比',
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
        summary: '演示：视频提示词运动描述清晰，可作为基线',
        lastVerifiedAt: '2026-05-11T10:00:00Z',
      ),
    ],
    experiments: const <ExperimentRunV1>[
      ExperimentRunV1(
        id: 'exp-demo-1',
        name: '分镜提示词 A/B · 演示',
        status: 'completed',
        sampleTier: 'smoke',
        stageScope: <String>['storyboard_panel', 'video_prompt'],
        baselineVariantId: 'baseline',
        createdAt: '2026-05-01T00:00:00Z',
        startedAt: '2026-05-01T00:05:00Z',
        completedAt: '2026-05-01T01:00:00Z',
      ),
    ],
    reviewQueue: const <ReviewQueueItemV1>[
      ReviewQueueItemV1(
        id: 'review-demo-1',
        experimentRunId: 'exp-demo-1',
        experimentResultId: 'result-demo-1',
        reviewType: 'quality_gate',
        status: 'pending',
        priority: 1,
        prompt: '演示：对比 baseline 与 variant 的分镜质量得分',
        submittedScore: null,
      ),
    ],
    statusLine: '演示数据已加载 — 可浏览用例、实验与评审队列；运行/晋升操作在演示模式下不可用。',
  );
}
