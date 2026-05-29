import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/studio_motion.dart';

void main() {
  test('StudioMotionDurations follow fast < normal < slow', () {
    expect(
      StudioMotionDurations.fast,
      lessThan(StudioMotionDurations.normal),
    );
    expect(
      StudioMotionDurations.normal,
      lessThan(StudioMotionDurations.slow),
    );
    expect(StudioMotionDurations.hoverTransition, StudioMotionDurations.fast);
    expect(
      StudioMotionDurations.dialogTransition,
      StudioMotionDurations.normal,
    );
  });
}
