import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/product_shell/studio_route_guards.dart';

void main() {
  test('studioProjectStepRedirectLocation rejects unknown slug', () {
    expect(
      studioProjectStepRedirectLocation(
        projectNumericId: '1',
        stepSlug: 'bad-step',
        validSlugs: {'script'},
      ),
      '/projects/1',
    );
  });

  test('studioProjectStepRedirectLocation allows valid slug', () {
    expect(
      studioProjectStepRedirectLocation(
        projectNumericId: '1',
        stepSlug: 'script',
        validSlugs: {'script'},
      ),
      isNull,
    );
  });
}
