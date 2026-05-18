import '../project_studio/studio_overlay_mode.dart';
import '../shell/navigation_controller.dart';
import 'studio_shell_branches.dart';

bool shouldShowStudioPipeline({
  required StudioOverlayMode overlayMode,
  required ProductWorkspacePane currentPane,
}) {
  return overlayMode == StudioOverlayMode.none &&
      kStudioUtilityPanes.contains(currentPane);
}
