import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/layout_breakpoints.dart';
import 'package:openflow_app/project_studio/projects_studio_home_layout.dart';

void main() {
  group('ProjectsStudioHomeLayout', () {
    test('phone uses stacked header and standalone single card', () {
      const layout = ProjectsStudioHomeLayout(
        contentWidth: 390,
        shortestSide: 390,
      );
      expect(layout.isPhone, isTrue);
      expect(layout.stackedHeader, isTrue);
      expect(layout.phoneStackedHeader, isTrue);
      expect(layout.useDenseSingleCard, isFalse);
      expect(layout.useStandaloneSingleCard, isTrue);
      expect(layout.useSplitOverview, isFalse);
    });

    test('desktop wide pane uses inline header and dense card', () {
      const layout = ProjectsStudioHomeLayout(
        contentWidth: 1200,
        shortestSide: 900,
      );
      expect(layout.isPhone, isFalse);
      expect(layout.stackedHeader, isFalse);
      expect(layout.useDenseSingleCard, isTrue);
      expect(layout.useStandaloneSingleCard, isFalse);
    });

    test('desktop with sidebar uses content width not viewport', () {
      const layout = ProjectsStudioHomeLayout(
        contentWidth: 700,
        shortestSide: 1080,
      );
      expect(layout.isPhone, isFalse);
      expect(layout.stackedHeader, isTrue);
      expect(layout.useDenseSingleCard, isFalse);
    });

    test('split overview requires wide content pane', () {
      const narrow = ProjectsStudioHomeLayout(
        contentWidth: kProjectsHomeSplitOverviewMinWidth - 1,
        shortestSide: 900,
      );
      const wide = ProjectsStudioHomeLayout(
        contentWidth: kProjectsHomeSplitOverviewMinWidth,
        shortestSide: 900,
      );
      expect(narrow.useSplitOverview, isFalse);
      expect(wide.useSplitOverview, isTrue);
    });
  });
}
