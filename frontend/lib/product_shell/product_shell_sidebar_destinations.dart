import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';
import 'navigation.dart';
import 'studio_shell_navigation.dart';

/// Full sidebar destination list for desktop three-column product shell.
List<ProductShellDestination> productShellSidebarDestinations({
  required AppLocalizations l10n,
  required bool jobsPaneEnabled,
  required bool qualityPaneEnabled,
  required bool useFourItemShell,
}) {
  if (useFourItemShell) {
    final primary = studioShellPrimaryDestinations(unreadNotifications: 0);
    final secondary = studioShellSecondaryDestinations(
      l10n,
      jobsPaneEnabled: jobsPaneEnabled,
      qualityPaneEnabled: qualityPaneEnabled,
    );
    return <ProductShellDestination>[...primary, ...secondary];
  }
  return primaryProductShellDestinations(
    jobsPaneEnabled: jobsPaneEnabled,
    qualityPaneEnabled: qualityPaneEnabled,
  );
}

/// Index of [pane] in [destinations], or -1 when absent.
int productShellSidebarSelectedIndex(
  List<ProductShellDestination> destinations,
  ProductWorkspacePane pane,
) {
  return destinations.indexWhere((dest) => dest.pane == pane);
}
