import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../design_system/tokens.dart';
import '../design_system/components/studio_surfaces.dart';
import 'project_studio_cockpit_panel.dart';
import 'studio_agent_quick_bar.dart';
import 'studio_step.dart';
import '../rust_api.dart';

/// Secondary chrome for non-script steps (quick actions, cockpit) — opened from sheet.
class ProjectStudioGenericStepSetupPanel extends StatelessWidget {
  const ProjectStudioGenericStepSetupPanel({
    super.key,
    required this.step,
    required this.home,
    required this.visibleAgentActions,
    required this.onRunHarnessAgent,
    required this.onExecuteHomeAction,
    required this.metricActionBuilder,
    required this.onExecuteStarter,
    this.onOpenModelRoutingSettings,
  });

  final StudioStep step;
  final ProjectHome home;
  final Set<StudioAgentAction> visibleAgentActions;
  final Future<void> Function(String agentKind) onRunHarnessAgent;
  final ValueChanged<ProjectHomeAction> onExecuteHomeAction;
  final ProjectHomeAction? Function(ProjectHomeMetric metric) metricActionBuilder;
  final ValueChanged<ProjectHomeStarterTemplate> onExecuteStarter;
  final VoidCallback? onOpenModelRoutingSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (onOpenModelRoutingSettings != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: studioFormTextButtonIconStyle(context),
              onPressed: onOpenModelRoutingSettings,
              icon: const Icon(Icons.hub_outlined, size: StudioIconSize.sm),
              label: Text(l10n.studioScriptStepModelRoutingSettingsLink),
            ),
          ),
        if (visibleAgentActions.isNotEmpty) ...<Widget>[
          StudioAgentQuickBar(
            visibleActions: visibleAgentActions,
            onRewriteScript: () => onRunHarnessAgent('script_rewriter'),
            onExtractEntities: () => onRunHarnessAgent('extractor'),
            onBreakStoryboard: () => onRunHarnessAgent('storyboard_breaker'),
            onAssignVoices: () => onRunHarnessAgent('voice_assigner'),
            onGridPrompts: () => onRunHarnessAgent('grid_prompt_generator'),
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
        ],
        ProjectStudioCockpitPanel(
          home: home,
          currentStep: step,
          onExecuteAction: onExecuteHomeAction,
          metricActionBuilder: metricActionBuilder,
          onExecuteStarter: onExecuteStarter,
        ),
      ],
    );
  }
}
