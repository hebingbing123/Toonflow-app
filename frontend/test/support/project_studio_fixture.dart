import 'package:flutter/material.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

/// Minimal [ProjectStudioHost] on the script step for widget/golden tests.
ProjectStudioHost buildScriptStepStudioHost({
  AppLocalizations? l10n,
  ValueChanged<StudioStep>? onStepChanged,
}) {
  final resolved = l10n;
  return ProjectStudioHost(
    projectNumericId: 7,
    projectUuid: '550e8400-e29b-41d4-a716-446655440007',
    projectName: '演示项目',
    accessToken: 'token',
    initialStep: StudioStep.script,
    completedSteps: 1,
    onExit: () {},
    onStepChanged: onStepChanged ?? (_) {},
    onOpenAgentDrawer: () {},
    onRunHarnessAgent: (_) async {},
    buildStepBody: (step) {
      final body = resolved == null
          ? 'step-${step.slug}'
          : step == StudioStep.script
          ? resolved.studioStepScriptBody
          : 'step-${step.slug}';
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(body),
        ),
      );
    },
  );
}
