import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/creator_journey_menu.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

void main() {
  test('primary and advanced SOP steps partition sopSteps', () {
    expect(
      studioCreatorJourneyPrimarySopSteps,
      <StudioStep>[
        StudioStep.script,
        StudioStep.art,
        StudioStep.storyboard,
        StudioStep.deliver,
      ],
    );
    expect(
      studioCreatorJourneyAdvancedSopSteps,
      <StudioStep>[StudioStep.assets, StudioStep.video, StudioStep.quality],
    );
    expect(
      <StudioStep>[
        ...studioCreatorJourneyPrimarySopSteps,
        ...studioCreatorJourneyAdvancedSopSteps,
      ],
      containsAll(StudioStep.sopSteps),
    );
    expect(StudioStep.sopSteps, isNot(contains(StudioStep.quality)));
  });

  test('CreatorWorkspaceMenuTarget equality', () {
    expect(
      const CreatorWorkspaceMenuTarget.step(StudioStep.art),
      const CreatorWorkspaceMenuTarget.step(StudioStep.art),
    );
    expect(
      const CreatorWorkspaceMenuTarget.reviewPack(),
      isNot(const CreatorWorkspaceMenuTarget.step(StudioStep.deliver)),
    );
  });
}
