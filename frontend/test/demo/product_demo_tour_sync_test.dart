import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
    await ProductDemoMode.instance.enable(guest: true);
  });

  tearDown(() async {
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
  });

  test('stale home URI does not rewind index while step is locked', () {
    final tour = ProductDemoTour.instance;
    tour.debugPrimeTourStep(index: 1, lockedStepIndex: 1);

    tour.syncFromShell(
      uri: Uri.parse('/'),
      overlay: StudioOverlayMode.none,
      projectNumericId: 7,
      stepSlug: null,
      pane: ProductWorkspacePane.projects,
    );

    expect(tour.stepIndex, 1);
    expect(tour.lockedStepIndexForTest, 1);
    expect(
      tour.currentStop?.location,
      contains('/projects/7/script'),
    );
  });

  test('unlock when shell reports target studio step', () {
    final tour = ProductDemoTour.instance;
    tour.debugPrimeTourStep(index: 1, lockedStepIndex: 1);

    tour.syncFromShell(
      uri: Uri.parse('/projects/7/script'),
      overlay: StudioOverlayMode.projectStudio,
      projectNumericId: 7,
      stepSlug: StudioStep.script.slug,
      pane: ProductWorkspacePane.projects,
    );

    expect(tour.stepIndex, 1);
    expect(tour.lockedStepIndexForTest, isNull);
  });

  test('stale home URI does not clear lock while advancing to studio step', () {
    final tour = ProductDemoTour.instance;
    tour.debugPrimeTourStep(index: 1, lockedStepIndex: 1);

    tour.syncFromShell(
      uri: Uri.parse('/'),
      overlay: StudioOverlayMode.none,
      projectNumericId: 7,
      stepSlug: null,
      pane: ProductWorkspacePane.projects,
    );

    expect(tour.stepIndex, 1);
    expect(tour.lockedStepIndexForTest, 1);
  });

  test('engaged tour does not rewind index on stale home URI after unlock', () {
    final tour = ProductDemoTour.instance;
    tour.debugPrimeTourStep(index: 1, lockedStepIndex: null);

    tour.syncFromShell(
      uri: Uri.parse('/'),
      overlay: StudioOverlayMode.none,
      projectNumericId: 7,
      stepSlug: null,
      pane: ProductWorkspacePane.projects,
    );

    expect(tour.stepIndex, 1);
    expect(
      tour.currentStop?.location,
      contains('/projects/7/script'),
    );
  });

  test('manual pane navigation updates step index when unlocked', () {
    final tour = ProductDemoTour.instance;
    tour.debugPrimeTourStep(index: 0, lockedStepIndex: null);

    final tasksIndex = ProductDemoTour.buildDefaultStops().indexWhere(
      (s) => s.location.contains('pane=tasks'),
    );
    expect(tasksIndex, greaterThan(0));

    tour.syncFromShell(
      uri: Uri.parse('/?pane=tasks'),
      overlay: StudioOverlayMode.none,
      projectNumericId: 7,
      stepSlug: null,
      pane: ProductWorkspacePane.tasks,
    );

    expect(tour.stepIndex, tasksIndex);
  });

  test('syncFromProjectStudioStep aligns index to SOP step slug', () {
    final tour = ProductDemoTour.instance;
    tour.debugPrimeTourStep(index: 0, lockedStepIndex: null);

    tour.syncFromProjectStudioStep(
      projectNumericId: 7,
      step: StudioStep.assets,
    );

    final assetsIndex = ProductDemoTour.buildDefaultStops().indexWhere(
      (s) => s.location.contains('/projects/7/assets'),
    );
    expect(assetsIndex, greaterThan(0));
    expect(tour.stepIndex, assetsIndex);
    expect(
      tour.currentStop?.location,
      contains('/projects/7/assets'),
    );
  });

  test('syncFromShell uses project path from uri when overlay is none', () {
    final tour = ProductDemoTour.instance;
    tour.debugPrimeTourStep(index: 0, lockedStepIndex: null);

    tour.syncFromShell(
      uri: Uri.parse('/projects/7/art'),
      overlay: StudioOverlayMode.none,
      projectNumericId: 7,
      stepSlug: null,
      pane: ProductWorkspacePane.projects,
    );

    final artIndex = ProductDemoTour.buildDefaultStops().indexWhere(
      (s) => s.location.contains('/projects/7/art'),
    );
    expect(artIndex, greaterThan(0));
    expect(tour.stepIndex, artIndex);
    expect(
      tour.currentStop?.location,
      contains('/projects/7/art'),
    );
  });

  test('script workspace route sync matches pane=script tour stop', () {
    final tour = ProductDemoTour.instance;
    final scriptWorkspaceIndex = ProductDemoTour.buildDefaultStops().indexWhere(
      (s) => s.location.contains('pane=script'),
    );
    expect(scriptWorkspaceIndex, greaterThan(0));

    tour.debugPrimeTourStep(index: 0, lockedStepIndex: null);
    tour.syncFromShell(
      uri: Uri.parse('/projects/7/script'),
      overlay: StudioOverlayMode.none,
      projectNumericId: 7,
      stepSlug: StudioStep.script.slug,
      pane: ProductWorkspacePane.scriptWorkspace,
    );

    expect(tour.stepIndex, scriptWorkspaceIndex);
  });

  test('production storyboard route sync matches pane=production stop', () {
    final tour = ProductDemoTour.instance;
    final productionIndex = ProductDemoTour.buildDefaultStops().indexWhere(
      (s) => s.location.contains('pane=production'),
    );
    expect(productionIndex, greaterThan(0));

    tour.debugPrimeTourStep(index: 0, lockedStepIndex: null);
    tour.syncFromShell(
      uri: Uri.parse('/projects/7/storyboard'),
      overlay: StudioOverlayMode.none,
      projectNumericId: 7,
      stepSlug: StudioStep.storyboard.slug,
      pane: ProductWorkspacePane.productionWorkspace,
    );

    expect(tour.stepIndex, productionIndex);
  });
}
