import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/product_shell/router.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

void main() {
  test('studio router exposes product entry routes', () {
    final router = createStudioRouter();

    expect(router.routeInformationProvider.value.uri.toString(), '/');
    expect(router.configuration.routes, isNotEmpty);

    router.dispose();
  });

  test('overlay route builders produce expected HomePage config', () {
    final storyboard = buildStoryboardStudioHomePage(projectNumericId: 7);
    expect(storyboard, isA<HomePage>());
    expect(storyboard.studioOverlay, StudioOverlayMode.storyboardStudio);
    expect(storyboard.studioProjectNumericId, 7);

    final console = buildEpisodeConsoleHomePage(
      projectNumericId: 7,
      scriptNumericId: 3,
    );
    expect(console.studioOverlay, StudioOverlayMode.episodeConsole);
    expect(console.studioProjectNumericId, 7);
    expect(console.studioScriptNumericId, 3);

    final studio = buildProjectStudioHomePage(
      projectNumericId: 7,
      stepSlug: 'deliver',
    );
    expect(studio.studioOverlay, StudioOverlayMode.projectStudio);
    expect(studio.studioProjectNumericId, 7);
    expect(studio.studioStepSlug, 'deliver');
    expect(studio.initialProductPane, ProductWorkspacePane.projects);

    final review = buildReviewPackHomePage(projectNumericId: 7);
    expect(review.studioOverlay, StudioOverlayMode.reviewPack);
    expect(review.studioProjectNumericId, 7);
    expect(review.initialProductPane, ProductWorkspacePane.projects);
  });

  test('project root redirect resolves to script step', () {
    expect(studioProjectRootRedirectLocation('42'), '/projects/42/script');
  });

  test('storyboard SOP slug uses project studio overlay', () {
    final studio = buildProjectStudioHomePage(
      projectNumericId: 7,
      stepSlug: 'storyboard',
    );
    expect(studio.studioOverlay, StudioOverlayMode.projectStudio);
    expect(studio.studioStepSlug, 'storyboard');
  });

  test('full-screen storyboard studio has dedicated route helper', () {
    expect(studioStoryboardStudioRoute(7), '/projects/7/storyboard-studio');
  });
}
