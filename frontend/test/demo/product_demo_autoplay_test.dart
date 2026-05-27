import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:openflow_app/demo/product_demo_tour_anchors.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

void main() {
  test('buildDefaultStops has mainline + launch + utility beats', () {
    final stops = ProductDemoTour.buildDefaultStops();
    expect(stops.length, kProductDemoTourBeatCount);
    expect(stops.where((s) => s.hasRichGuide).length, greaterThanOrEqualTo(16));
    expect(stops.where((s) => s.anchorId != null).length, greaterThanOrEqualTo(12));
    expect(
      stops.every((s) => s.guideForLocale('zh').isNotEmpty),
      isTrue,
    );
  });

  test('buildDefaultStops covers SOP, review pack, and utility panes', () {
    final stops = ProductDemoTour.buildDefaultStops();
    expect(stops.first.location, '/');
    expect(
      stops.where((s) => s.location.contains('/projects/7/')).length,
      greaterThanOrEqualTo(StudioStep.sopSteps.length + 1),
    );
    expect(
      stops.any((s) => s.location.contains('review-pack')),
      isTrue,
    );
    expect(
      stops.any((s) => s.location.contains('pane=tasks')),
      isTrue,
    );
  });

  test('stop clears autoplay state', () {
    final tour = ProductDemoTour.instance;
    tour.stop();
    expect(tour.isAutoplaying, isFalse);
  });

  test('guide copy is locale-aware', () {
    const stop = ProductDemoTourStop(
      location: '/',
      titleZh: '项目',
      titleEn: 'Projects',
      guideZh: '说明',
      guideEn: 'Hint',
      anchorId: ProductDemoTourAnchorIds.projectsGrid,
    );
    expect(stop.titleForLocale('zh'), '项目');
    expect(stop.guideForLocale('en'), 'Hint');
  });
}
