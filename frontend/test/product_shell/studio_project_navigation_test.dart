import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';

void main() {
  test('project hero tags are stable per numeric id', () {
    expect(
      studioHeroTagProjectTitle(42),
      studioHeroTagProjectTitle(42),
    );
    expect(
      studioHeroTagProjectProgress(42),
      'studio.hero.project.progress.42',
    );
    expect(
      studioHeroTagProjectTitle(7),
      isNot(studioHeroTagProjectTitle(8)),
    );
  });
}
