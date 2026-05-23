import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'studio_step.dart';

/// Query key for pre-selecting a script on the storyboard studio step.
const String kProjectStudioStoryboardScriptIdQuery = 'scriptId';

/// Canonical `/projects/:id/:step` path for studio-step navigation.
String projectStudioStepPath(
  int projectNumericId,
  StudioStep step, {
  int? storyboardScriptNumericId,
}) {
  return projectStudioStepUri(
    projectNumericId,
    step,
    storyboardScriptNumericId: storyboardScriptNumericId,
  ).toString();
}

/// Canonical URI for a project-studio SOP step (quality uses deliver + tab).
Uri projectStudioStepUri(
  int projectNumericId,
  StudioStep step, {
  int? storyboardScriptNumericId,
}) {
  final base = '/projects/$projectNumericId';
  if (step == StudioStep.quality) {
    return Uri(
      path: '$base/${StudioStep.deliver.slug}',
      queryParameters: const <String, String>{'tab': 'quality'},
    );
  }
  final query = <String, String>{};
  if (step == StudioStep.storyboard &&
      storyboardScriptNumericId != null &&
      storyboardScriptNumericId > 0) {
    query[kProjectStudioStoryboardScriptIdQuery] =
        storyboardScriptNumericId.toString();
  }
  return Uri(
    path: '$base/${step.slug}',
    queryParameters: query.isEmpty ? null : query,
  );
}

/// Parses `scriptId` from a project-studio storyboard step URI.
int? projectStudioStoryboardScriptIdFromUri(Uri uri) {
  final raw = uri.queryParameters[kProjectStudioStoryboardScriptIdQuery]?.trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

bool projectStudioStepUrisEquivalent(Uri a, Uri b) {
  if (a.path != b.path) return false;
  if (a.queryParameters['tab'] != b.queryParameters['tab']) return false;
  if (a.queryParameters[kProjectStudioStoryboardScriptIdQuery] !=
      b.queryParameters[kProjectStudioStoryboardScriptIdQuery]) {
    return false;
  }
  return true;
}

/// Studio step that should open when a harness agent chip runs in project context.
StudioStep? studioStepForHarnessAgentKind(String kind) {
  return switch (kind.trim()) {
    'script_rewriter' || 'extractor' => StudioStep.script,
    'storyboard_breaker' || 'grid_prompt_generator' => StudioStep.storyboard,
    'voice_assigner' => StudioStep.assets,
    _ => null,
  };
}

/// Navigates to [step] when [projectNumericId] is valid; no-op otherwise.
void goProjectStudioStepIfScoped(
  BuildContext context, {
  required int? projectNumericId,
  required StudioStep step,
  int? storyboardScriptNumericId,
}) {
  if (projectNumericId == null || projectNumericId <= 0) {
    return;
  }
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    return;
  }
  final target = projectStudioStepUri(
    projectNumericId,
    step,
    storyboardScriptNumericId: storyboardScriptNumericId,
  );
  final current = GoRouterState.of(context).uri;
  if (projectStudioStepUrisEquivalent(current, target)) {
    return;
  }
  context.go(target.toString());
}

/// Opens the storyboard SOP step with [scriptNumericId] pre-selected (no dialog stack).
void goProjectStudioStoryboardForScript(
  BuildContext context, {
  required int projectNumericId,
  required int scriptNumericId,
}) {
  goProjectStudioStepIfScoped(
    context,
    projectNumericId: projectNumericId,
    step: StudioStep.storyboard,
    storyboardScriptNumericId: scriptNumericId,
  );
}
