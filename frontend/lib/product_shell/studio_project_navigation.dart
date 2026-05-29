import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../project_studio/studio_step.dart';

/// Opens the six-step project studio route.
///
/// Uses [GoRouter.push] when entering from the projects home grid so title /
/// progress [Hero] flights can run; other entry points keep [go] for deep links.
void openProjectStudioRoute(
  BuildContext context, {
  required int projectNumericId,
  StudioStep step = StudioStep.script,
  bool pushFromProjectsHome = false,
}) {
  final location = '/projects/$projectNumericId/${step.slug}';
  if (pushFromProjectsHome) {
    context.push(location);
    return;
  }
  context.go(location);
}

/// Leaves project studio — pops the pushed projects-home entry when possible.
void exitProjectStudioRoute(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/');
}
