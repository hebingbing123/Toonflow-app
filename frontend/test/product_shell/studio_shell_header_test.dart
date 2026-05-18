import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_shell_header.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('overlay header prefers project name when present', () {
    final title = resolveStudioShellHeaderTitle(
      l10n: l10n,
      overlayMode: StudioOverlayMode.projectStudio,
      projectName: '  Project Delta  ',
      studioProjectNumericId: 7,
      productScopedProjectNumericId: null,
      currentPane: ProductWorkspacePane.notifications,
    );

    expect(title, 'Project Delta');
  });

  test('overlay header falls back to unnamed project label', () {
    final title = resolveStudioShellHeaderTitle(
      l10n: l10n,
      overlayMode: StudioOverlayMode.storyboardStudio,
      projectName: ' ',
      studioProjectNumericId: null,
      productScopedProjectNumericId: 12,
      currentPane: ProductWorkspacePane.notifications,
    );

    expect(title, l10n.projectsUnnamedProject(12));
  });

  test('non-overlay header uses current workspace pane title', () {
    final title = resolveStudioShellHeaderTitle(
      l10n: l10n,
      overlayMode: StudioOverlayMode.none,
      projectName: 'Project Delta',
      studioProjectNumericId: 7,
      productScopedProjectNumericId: null,
      currentPane: ProductWorkspacePane.helpHub,
    );

    expect(title, l10n.productNavHelp);
  });

  test('overlay without project identity still uses current pane title', () {
    final title = resolveStudioShellHeaderTitle(
      l10n: l10n,
      overlayMode: StudioOverlayMode.episodeConsole,
      projectName: null,
      studioProjectNumericId: null,
      productScopedProjectNumericId: null,
      currentPane: ProductWorkspacePane.projects,
    );

    expect(title, l10n.productNavProjects);
  });
}
