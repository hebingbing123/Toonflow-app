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
