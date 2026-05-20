import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'studio_step.dart';

enum ProjectStudioAssetEditorTargetKind {
  overview,
  buildRoleLibrary,
  defineProjectCharacters,
  anchorCharacters,
  confirmCandidates,
  reviewRoleReuse,
}

class ProjectStudioAssetEditorTarget {
  const ProjectStudioAssetEditorTarget({
    required this.kind,
    this.preferredScriptNumericId,
    this.preferredAssetNumericId,
    this.preferredStoryboardNumericId,
    this.notice,
  });

  final ProjectStudioAssetEditorTargetKind kind;
  final int? preferredScriptNumericId;
  final int? preferredAssetNumericId;
  final int? preferredStoryboardNumericId;
  final String? notice;
}

/// Callbacks and step bodies for [ProjectStudioPage].
class ProjectStudioHost {
  const ProjectStudioHost({
    required this.projectNumericId,
    required this.projectUuid,
    required this.projectName,
    required this.accessToken,
    required this.onExit,
    required this.onStepChanged,
    required this.onOpenAgentDrawer,
    required this.onRunHarnessAgent,
    required this.buildStepBody,
    this.onOpenTasks,
    this.home,
    this.assetsOverview,
    this.readiness,
    this.onOpenAssetEditor,
    this.initialStep = StudioStep.script,
    this.completedSteps = 0,
    this.runningJobCount = 0,
    this.failedJobCount = 0,
    this.conflictMessage,
    this.onRefreshAfterConflict,
    this.onOpenProjectSettings,
    this.onOpenGlobalModelVendorSettings,
  });

  final int projectNumericId;
  final String projectUuid;
  final String? projectName;
  final String? accessToken;
  final ProjectHome? home;
  final ProjectAssetsOverview? assetsOverview;
  final ProjectShortVideoReadiness? readiness;
  final VoidCallback? onOpenTasks;
  final ValueChanged<ProjectStudioAssetEditorTarget>? onOpenAssetEditor;
  final StudioStep initialStep;
  final int completedSteps;
  final int runningJobCount;
  final int failedJobCount;
  final String? conflictMessage;
  final VoidCallback? onRefreshAfterConflict;
  final VoidCallback? onOpenProjectSettings;
  final VoidCallback? onOpenGlobalModelVendorSettings;
  final VoidCallback onExit;
  final ValueChanged<StudioStep> onStepChanged;
  final VoidCallback onOpenAgentDrawer;
  final Future<void> Function(String agentKind) onRunHarnessAgent;
  final Widget Function(StudioStep step) buildStepBody;
}
