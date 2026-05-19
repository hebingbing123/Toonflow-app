import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/product_shell/studio_shell_layout.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

void main() {
  test(
    'shouldShowStudioPipeline shows pipeline for production flow panes on shell home',
    () {
      expect(
        shouldShowStudioPipeline(
          overlayMode: StudioOverlayMode.none,
          currentPane: ProductWorkspacePane.projects,
        ),
        isTrue,
      );
      expect(
        shouldShowStudioPipeline(
          overlayMode: StudioOverlayMode.none,
          currentPane: ProductWorkspacePane.shortVideoSpace,
        ),
        isTrue,
      );
    },
  );

  test('shouldShowStudioPipeline hides pipeline for utility panes', () {
    expect(
      shouldShowStudioPipeline(
        overlayMode: StudioOverlayMode.none,
        currentPane: ProductWorkspacePane.helpHub,
      ),
      isFalse,
    );
    expect(
      shouldShowStudioPipeline(
        overlayMode: StudioOverlayMode.none,
        currentPane: ProductWorkspacePane.notifications,
      ),
      isFalse,
    );
  });

  test('shouldShowStudioPipeline hides pipeline while overlay is active', () {
    expect(
      shouldShowStudioPipeline(
        overlayMode: StudioOverlayMode.projectStudio,
        currentPane: ProductWorkspacePane.projects,
      ),
      isFalse,
    );
    expect(
      shouldShowStudioPipeline(
        overlayMode: StudioOverlayMode.storyboardStudio,
        currentPane: ProductWorkspacePane.notifications,
      ),
      isFalse,
    );
  });
}
