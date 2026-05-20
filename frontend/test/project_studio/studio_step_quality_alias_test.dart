import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

void main() {
  test('quality slug maps to deliver stack index', () {
    expect(StudioStep.quality.sopStackIndex, StudioStep.deliver.order);
    expect(
      StudioStep.quality.highlightsSopStep(StudioStep.deliver),
      isTrue,
    );
    expect(
      StudioStep.quality.highlightsSopStep(StudioStep.script),
      isFalse,
    );
  });

  test('quality is not in sopSteps bar', () {
    expect(StudioStep.sopSteps.contains(StudioStep.quality), isFalse);
    expect(StudioStep.fromSlug('quality'), StudioStep.quality);
  });
}
