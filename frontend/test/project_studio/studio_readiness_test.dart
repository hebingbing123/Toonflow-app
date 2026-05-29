import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/rust_api.dart';

const _readiness80 = ProjectShortVideoReadiness(
  schemaVersion: 1,
  rollup: ShortVideoReadinessRollup(
    totalStoryboards: 10,
    readyCount: 8,
    blockedCount: 2,
    byReason: <ShortVideoReadinessReasonRollup>[],
  ),
  storyboards: <StoryboardShortVideoReadiness>[],
);

void main() {
  test('computeStudioCompletedSteps defaults to first step with no data', () {
    expect(computeStudioCompletedSteps(), 1);
  });

  test('resolveStudioProgressRingSteps follows journey on deliver', () {
    expect(
      resolveStudioProgressRingSteps(
        1,
        currentStep: StudioStep.deliver,
      ),
      5,
    );
  });

  test('computeProjectListProgressSteps uses saved studio step', () {
    expect(
      computeProjectListProgressSteps(
        lastVisitedStep: StudioStep.deliver,
      ),
      5,
    );
  });

  test('computeProjectListProgressSteps ignores unset saved step', () {
    expect(
      computeProjectListProgressSteps(lastVisitedStep: null),
      1,
    );
  });

  test('computeStudioCompletedSteps uses readiness rollup', () {
    expect(
      computeStudioCompletedSteps(readiness: _readiness80),
      greaterThanOrEqualTo(5),
    );
  });

  test('computeStudioCompletedSteps falls back to production overview', () {
    const production = ProjectProductionOverview(
      schemaVersion: 1,
      readyStoryboardCount: 0,
      totalStoryboardCount: 4,
      runningGenerationJobCount: 1,
      pendingReviewBadCaseCount: 0,
    );

    expect(computeStudioCompletedSteps(production: production), 4);
  });

  test(
    'computeStudioCompletedSteps marks mostly ready production as step five',
    () {
      const production = ProjectProductionOverview(
        schemaVersion: 1,
        readyStoryboardCount: 3,
        totalStoryboardCount: 5,
        runningGenerationJobCount: 0,
        pendingReviewBadCaseCount: 0,
      );

      expect(computeStudioCompletedSteps(production: production), 5);
    },
  );

  test(
    'computeStudioCompletedSteps marks fully ready storyboards as complete',
    () {
      const production = ProjectProductionOverview(
        schemaVersion: 1,
        readyStoryboardCount: 5,
        totalStoryboardCount: 5,
        runningGenerationJobCount: 0,
        pendingReviewBadCaseCount: 0,
      );

      expect(
        computeStudioCompletedSteps(
          readiness: _readiness80,
          production: production,
        ),
        6,
      );
    },
  );
}
