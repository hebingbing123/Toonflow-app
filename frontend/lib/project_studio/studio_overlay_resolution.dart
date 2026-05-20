import 'studio_overlay_mode.dart';

enum ResolvedStudioOverlayKind {
  none,
  loading,
  storyboardStudio,
  episodeConsole,
  projectStudio,
  reviewPack,
}

class ResolvedStudioOverlay {
  const ResolvedStudioOverlay._({
    required this.kind,
    this.projectNumericId,
    this.scriptNumericId,
    this.projectUuid,
  });

  const ResolvedStudioOverlay.none()
    : this._(kind: ResolvedStudioOverlayKind.none);

  const ResolvedStudioOverlay.loading()
    : this._(kind: ResolvedStudioOverlayKind.loading);

  const ResolvedStudioOverlay.storyboardStudio({required int projectNumericId})
    : this._(
        kind: ResolvedStudioOverlayKind.storyboardStudio,
        projectNumericId: projectNumericId,
      );

  const ResolvedStudioOverlay.episodeConsole({
    required int projectNumericId,
    required int scriptNumericId,
  }) : this._(
         kind: ResolvedStudioOverlayKind.episodeConsole,
         projectNumericId: projectNumericId,
         scriptNumericId: scriptNumericId,
       );

  const ResolvedStudioOverlay.projectStudio({
    required int projectNumericId,
    required String projectUuid,
  }) : this._(
         kind: ResolvedStudioOverlayKind.projectStudio,
         projectNumericId: projectNumericId,
         projectUuid: projectUuid,
       );

  const ResolvedStudioOverlay.reviewPack({
    required int projectNumericId,
    required String projectUuid,
  }) : this._(
         kind: ResolvedStudioOverlayKind.reviewPack,
         projectNumericId: projectNumericId,
         projectUuid: projectUuid,
       );

  final ResolvedStudioOverlayKind kind;
  final int? projectNumericId;
  final int? scriptNumericId;
  final String? projectUuid;
}

ResolvedStudioOverlay resolveStudioOverlay({
  required StudioOverlayMode overlayMode,
  required int? widgetProjectNumericId,
  required int? productScopedProjectNumericId,
  required int? widgetScriptNumericId,
  required String? rowProjectUuid,
  required String? workspaceProjectUuid,
  required String? accessToken,
}) {
  if (overlayMode == StudioOverlayMode.none) {
    return const ResolvedStudioOverlay.none();
  }

  final numericId = widgetProjectNumericId ?? productScopedProjectNumericId;
  if (numericId == null) {
    return const ResolvedStudioOverlay.loading();
  }

  if (overlayMode == StudioOverlayMode.storyboardStudio) {
    return ResolvedStudioOverlay.storyboardStudio(projectNumericId: numericId);
  }

  if (overlayMode == StudioOverlayMode.episodeConsole) {
    return ResolvedStudioOverlay.episodeConsole(
      projectNumericId: numericId,
      scriptNumericId: widgetScriptNumericId ?? 1,
    );
  }

  final projectUuid = (rowProjectUuid ?? workspaceProjectUuid ?? '').trim();
  if (projectUuid.isEmpty) {
    return const ResolvedStudioOverlay.loading();
  }

  final token = accessToken?.trim() ?? '';
  if (token.isEmpty) {
    return const ResolvedStudioOverlay.loading();
  }

  if (overlayMode == StudioOverlayMode.reviewPack) {
    return ResolvedStudioOverlay.reviewPack(
      projectNumericId: numericId,
      projectUuid: projectUuid,
    );
  }

  return ResolvedStudioOverlay.projectStudio(
    projectNumericId: numericId,
    projectUuid: projectUuid,
  );
}
