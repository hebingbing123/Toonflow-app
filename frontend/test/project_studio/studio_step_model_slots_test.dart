import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/project_studio/studio_step_model_slots.dart';

void main() {
  test('assets step exposes image and text model slots', () {
    expect(
      StudioStep.assets.modelSlotKeys,
      const <String>['image', 'text'],
    );
  });

  test('deliver step has no editable slots', () {
    expect(StudioStep.deliver.modelSlotKeys, isEmpty);
  });
}
