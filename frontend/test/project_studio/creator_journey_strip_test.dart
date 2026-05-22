import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/creator_journey_strip.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

void main() {
  group('creator journey mapping', () {
    test('creatorJourneyMilestoneNavIndex groups internal steps', () {
      expect(creatorJourneyMilestoneNavIndex(StudioStep.script), 1);
      expect(creatorJourneyMilestoneNavIndex(StudioStep.art), 2);
      expect(creatorJourneyMilestoneNavIndex(StudioStep.assets), 2);
      expect(creatorJourneyMilestoneNavIndex(StudioStep.storyboard), 3);
      expect(creatorJourneyMilestoneNavIndex(StudioStep.video), 3);
      expect(creatorJourneyMilestoneNavIndex(StudioStep.deliver), 4);
      expect(creatorJourneyMilestoneNavIndex(StudioStep.quality), 4);
    });

    test('creatorJourneyCompactBarNextStep uses milestone jumps', () {
      expect(
        creatorJourneyCompactBarNextStep(StudioStep.art),
        StudioStep.storyboard,
      );
      expect(
        creatorJourneyCompactBarNextStep(StudioStep.assets),
        StudioStep.storyboard,
      );
      expect(
        creatorJourneyCompactBarNextStep(StudioStep.storyboard),
        StudioStep.deliver,
      );
    });

    test('creatorJourneyCompactBarPrevStep walks back within milestone', () {
      expect(
        creatorJourneyCompactBarPrevStep(StudioStep.assets),
        StudioStep.art,
      );
      expect(
        creatorJourneyCompactBarPrevStep(StudioStep.storyboard),
        StudioStep.art,
      );
      expect(
        creatorJourneyCompactBarPrevStep(StudioStep.video),
        StudioStep.storyboard,
      );
      expect(
        creatorJourneyCompactBarPrevStep(StudioStep.deliver),
        StudioStep.video,
      );
      expect(
        creatorJourneyCompactBarPrevStep(StudioStep.quality),
        StudioStep.deliver,
      );
    });

    test('creatorJourneyCompactBarNext does not skip deliver for review pack', () {
      expect(
        creatorJourneyCompactBarNextStep(StudioStep.storyboard),
        StudioStep.deliver,
      );
      expect(
        creatorJourneyCompactBarNextStep(StudioStep.video),
        StudioStep.deliver,
      );
      expect(
        creatorJourneyCompactBarNextOpensReviewPack(StudioStep.storyboard),
        isFalse,
      );
      expect(
        creatorJourneyCompactBarNextOpensReviewPack(StudioStep.video),
        isFalse,
      );
      expect(
        creatorJourneyCompactBarNextOpensReviewPack(StudioStep.deliver),
        isTrue,
      );
      expect(
        creatorJourneyCompactBarNextOpensReviewPack(StudioStep.quality),
        isTrue,
      );
    });

    test('creatorJourneyCompactBarFocusUsesStepShortLabel off landing', () {
      expect(
        creatorJourneyCompactBarFocusUsesStepShortLabel(StudioStep.storyboard),
        isFalse,
      );
      expect(
        creatorJourneyCompactBarFocusUsesStepShortLabel(StudioStep.assets),
        isTrue,
      );
      expect(
        creatorJourneyCompactBarFocusUsesStepShortLabel(StudioStep.video),
        isTrue,
      );
      expect(
        creatorJourneyCompactBarFocusUsesStepShortLabel(StudioStep.quality),
        isTrue,
      );
    });

    test('creatorJourneyLandingStep picks canonical tabs', () {
      expect(creatorJourneyLandingStep(0), StudioStep.script);
      expect(creatorJourneyLandingStep(1), StudioStep.script);
      expect(creatorJourneyLandingStep(2), StudioStep.art);
      expect(creatorJourneyLandingStep(3), StudioStep.storyboard);
      expect(creatorJourneyLandingStep(4), StudioStep.deliver);
    });

    test('creatorJourneyTileStatus marks failures on active milestone', () {
      expect(
        creatorJourneyTileStatus(
          milestoneIndex: 2,
          currentStep: StudioStep.art,
          failedJobCount: 2,
        ),
        CreatorJourneyTileStatus.blocked,
      );
      expect(
        creatorJourneyTileStatus(
          milestoneIndex: 3,
          currentStep: StudioStep.art,
          failedJobCount: 2,
        ),
        CreatorJourneyTileStatus.notStarted,
      );
      expect(
        creatorJourneyTileStatus(
          milestoneIndex: 0,
          currentStep: StudioStep.script,
          failedJobCount: 99,
        ),
        CreatorJourneyTileStatus.completed,
      );
    });
  });
}
