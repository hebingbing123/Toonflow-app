import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/project_studio/studio_overlay_resolution.dart';

void main() {
  test('resolveStudioOverlay returns none for no overlay mode', () {
    const mode = StudioOverlayMode.none;
    final resolved = resolveStudioOverlay(
      overlayMode: mode,
      widgetProjectNumericId: null,
      productScopedProjectNumericId: null,
      widgetScriptNumericId: null,
      rowProjectUuid: null,
      workspaceProjectUuid: null,
      accessToken: null,
    );

    expect(resolved.kind, ResolvedStudioOverlayKind.none);
  });

  test('resolveStudioOverlay waits for numeric project id', () {
    final resolved = resolveStudioOverlay(
      overlayMode: StudioOverlayMode.storyboardStudio,
      widgetProjectNumericId: null,
      productScopedProjectNumericId: null,
      widgetScriptNumericId: null,
      rowProjectUuid: null,
      workspaceProjectUuid: null,
      accessToken: null,
    );

    expect(resolved.kind, ResolvedStudioOverlayKind.loading);
  });

  test(
    'resolveStudioOverlay resolves storyboard studio from scoped project',
    () {
      final resolved = resolveStudioOverlay(
        overlayMode: StudioOverlayMode.storyboardStudio,
        widgetProjectNumericId: null,
        productScopedProjectNumericId: 9,
        widgetScriptNumericId: null,
        rowProjectUuid: null,
        workspaceProjectUuid: null,
        accessToken: null,
      );

      expect(resolved.kind, ResolvedStudioOverlayKind.storyboardStudio);
      expect(resolved.projectNumericId, 9);
    },
  );

  test('resolveStudioOverlay defaults episode console script id to one', () {
    final resolved = resolveStudioOverlay(
      overlayMode: StudioOverlayMode.episodeConsole,
      widgetProjectNumericId: 9,
      productScopedProjectNumericId: null,
      widgetScriptNumericId: null,
      rowProjectUuid: null,
      workspaceProjectUuid: null,
      accessToken: null,
    );

    expect(resolved.kind, ResolvedStudioOverlayKind.episodeConsole);
    expect(resolved.projectNumericId, 9);
    expect(resolved.scriptNumericId, 1);
  });

  test('resolveStudioOverlay waits for project studio uuid', () {
    final resolved = resolveStudioOverlay(
      overlayMode: StudioOverlayMode.projectStudio,
      widgetProjectNumericId: 9,
      productScopedProjectNumericId: null,
      widgetScriptNumericId: null,
      rowProjectUuid: '   ',
      workspaceProjectUuid: '',
      accessToken: 'token',
    );

    expect(resolved.kind, ResolvedStudioOverlayKind.loading);
  });

  test('resolveStudioOverlay waits for project studio access token', () {
    final resolved = resolveStudioOverlay(
      overlayMode: StudioOverlayMode.projectStudio,
      widgetProjectNumericId: 9,
      productScopedProjectNumericId: null,
      widgetScriptNumericId: null,
      rowProjectUuid: 'project-9',
      workspaceProjectUuid: null,
      accessToken: ' ',
    );

    expect(resolved.kind, ResolvedStudioOverlayKind.loading);
  });

  test('resolveStudioOverlay resolves project studio from row uuid', () {
    final resolved = resolveStudioOverlay(
      overlayMode: StudioOverlayMode.projectStudio,
      widgetProjectNumericId: 9,
      productScopedProjectNumericId: null,
      widgetScriptNumericId: null,
      rowProjectUuid: 'project-9',
      workspaceProjectUuid: 'workspace-fallback',
      accessToken: 'token',
    );

    expect(resolved.kind, ResolvedStudioOverlayKind.projectStudio);
    expect(resolved.projectNumericId, 9);
    expect(resolved.projectUuid, 'project-9');
  });

  test(
    'resolveStudioOverlay falls back to workspace uuid for project studio',
    () {
      final resolved = resolveStudioOverlay(
        overlayMode: StudioOverlayMode.projectStudio,
        widgetProjectNumericId: 9,
        productScopedProjectNumericId: null,
        widgetScriptNumericId: null,
        rowProjectUuid: null,
        workspaceProjectUuid: ' project-9 ',
        accessToken: 'token',
      );

      expect(resolved.kind, ResolvedStudioOverlayKind.projectStudio);
      expect(resolved.projectUuid, 'project-9');
    },
  );
}
