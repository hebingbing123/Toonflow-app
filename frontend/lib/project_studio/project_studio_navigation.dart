import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'studio_step.dart';

/// Canonical `/projects/:id/:step` path for studio-step navigation.
String projectStudioStepPath(int projectNumericId, StudioStep step) {
  return projectStudioStepUri(projectNumericId, step).toString();
}

/// Canonical URI for a project-studio SOP step (quality uses deliver + tab).
Uri projectStudioStepUri(int projectNumericId, StudioStep step) {
  final base = '/projects/$projectNumericId';
  if (step == StudioStep.quality) {
    return Uri(
      path: '$base/${StudioStep.deliver.slug}',
      queryParameters: const <String, String>{'tab': 'quality'},
    );
  }
  return Uri(path: '$base/${step.slug}');
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
}) {
  if (projectNumericId == null || projectNumericId <= 0) {
    return;
  }
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    return;
  }
  final target = projectStudioStepUri(projectNumericId, step);
  final current = GoRouterState.of(context).uri;
  if (current.path == target.path &&
      current.queryParameters['tab'] == target.queryParameters['tab']) {
    return;
  }
  context.go(target.toString());
}
