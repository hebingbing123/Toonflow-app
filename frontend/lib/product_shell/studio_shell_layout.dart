import '../project_studio/studio_overlay_mode.dart';
import '../shell/navigation_controller.dart';

bool shouldShowStudioPipeline({
  required StudioOverlayMode overlayMode,
  required ProductWorkspacePane currentPane,
}) {
  if (overlayMode != StudioOverlayMode.none) {
    return false;
  }
  // Pipeline strip is for production flow; utility panes (通知/设置/帮助) stay uncluttered.
  // Workspace / project scope remains in the product title bar on all signed-in panes.
  return currentPane == ProductWorkspacePane.projects ||
      currentPane == ProductWorkspacePane.scriptWorkspace ||
      currentPane == ProductWorkspacePane.productionWorkspace ||
      currentPane == ProductWorkspacePane.tasks ||
      currentPane == ProductWorkspacePane.jobs ||
      currentPane == ProductWorkspacePane.quality ||
      currentPane == ProductWorkspacePane.shortVideoSpace;
}
