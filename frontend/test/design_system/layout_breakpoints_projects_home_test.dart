import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/layout_breakpoints.dart';

void main() {
  group('projectsHomeContentMaxWidth', () {
    test('phone uses unconstrained width', () {
      expect(
        projectsHomeContentMaxWidth(400, isPhone: true),
        double.infinity,
      );
    });

    test('desktop tiers cap content width at breakpoints', () {
      expect(
        projectsHomeContentMaxWidth(1279, isPhone: false),
        double.infinity,
      );
      expect(
        projectsHomeContentMaxWidth(1280, isPhone: false),
        kProjectsHomeContentMaxWidth1280,
      );
      expect(
        projectsHomeContentMaxWidth(1440, isPhone: false),
        kProjectsHomeContentMaxWidth1440,
      );
      expect(
        projectsHomeContentMaxWidth(1800, isPhone: false),
        kProjectsHomeContentMaxWidth1800,
      );
      expect(
        projectsHomeContentMaxWidth(2200, isPhone: false),
        kProjectsHomeContentMaxWidth2200,
      );
    });
  });

  group('projectsHomeRecentCardWidth', () {
    test('phone uses fixed handset card width', () {
      expect(
        projectsHomeRecentCardWidth(390, isPhone: true),
        kProjectsHomeRecentCardWidthPhone,
      );
    });

    test('desktop tiers widen recent cards with pane width', () {
      expect(projectsHomeRecentCardWidth(1079, isPhone: false), 260);
      expect(
        projectsHomeRecentCardWidth(1080, isPhone: false),
        kProjectsHomeRecentCardWidth1080,
      );
      expect(
        projectsHomeRecentCardWidth(1440, isPhone: false),
        kProjectsHomeRecentCardWidth1440,
      );
      expect(
        projectsHomeRecentCardWidth(1800, isPhone: false),
        kProjectsHomeRecentCardWidth1800,
      );
    });
  });
}
