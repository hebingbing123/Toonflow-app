import 'package:flutter/material.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_workbench_section.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'creator_starter_templates.dart';
import 'creator_starter_templates_strip.dart';
import 'project_studio_cockpit_panel.dart';
import 'studio_agent_quick_bar.dart';
import 'studio_step.dart';
import 'studio_step_model_routing_bar.dart';

/// Collapsible script-step chrome: model routing, starters, quick actions, cockpit.
class ProjectStudioScriptStepSetupPanel extends StatelessWidget {
  const ProjectStudioScriptStepSetupPanel({
    super.key,
    required this.accessToken,
    required this.projectUuid,
    required this.home,
    required this.visibleAgentActions,
    this.onRoutingUpdated,
    this.onOpenProjectSettings,
    this.onOpenGlobalModelVendorSettings,
    required this.onRunHarnessAgent,
    required this.onExecuteHomeAction,
    required this.metricActionBuilder,
    required this.onExecuteStarter,
  });

  final String accessToken;
  final String projectUuid;
  final ProjectHome home;
  final Set<StudioAgentAction> visibleAgentActions;
  final ValueChanged<ProjectModelRoutingResponse>? onRoutingUpdated;
  final VoidCallback? onOpenProjectSettings;
  final VoidCallback? onOpenGlobalModelVendorSettings;
  final void Function(String agentKind) onRunHarnessAgent;
  final ValueChanged<ProjectHomeAction> onExecuteHomeAction;
  final ProjectHomeAction? Function(ProjectHomeMetric metric) metricActionBuilder;
  final ValueChanged<ProjectHomeStarterTemplate> onExecuteStarter;

  Widget _buildQuickBarAndCockpit(BuildContext context) {
    final quickBar = StudioAgentQuickBar(
      visibleActions: visibleAgentActions,
      onRewriteScript: () => onRunHarnessAgent('script_rewriter'),
      onExtractEntities: () => onRunHarnessAgent('extractor'),
      onBreakStoryboard: () => onRunHarnessAgent('storyboard_breaker'),
      onAssignVoices: () => onRunHarnessAgent('voice_assigner'),
      onGridPrompts: () => onRunHarnessAgent('grid_prompt_generator'),
      bottomPadding: 0,
    );
    final cockpit = ProjectStudioCockpitPanel(
      home: home,
      currentStep: StudioStep.script,
      onExecuteAction: onExecuteHomeAction,
      metricActionBuilder: metricActionBuilder,
      onExecuteStarter: onExecuteStarter,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              quickBar,
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              cockpit,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(flex: 3, child: quickBar),
            const SizedBox(width: StudioLayoutSpacing.stackMedium),
            Expanded(flex: 2, child: cockpit),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StudioWorkbenchSection(
      title: l10n.studioScriptStepSetupTitle,
      subtitle: l10n.studioScriptStepSetupSubtitle,
      initiallyExpanded: false,
      expandTooltip: l10n.studioCockpitExpand,
      collapseTooltip: l10n.studioCockpitCollapse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudioStepModelRoutingBar(
            accessToken: accessToken,
            projectId: projectUuid,
            step: StudioStep.script,
            onOpenProjectSettings: onOpenProjectSettings,
            onOpenGlobalModelVendorSettings: onOpenGlobalModelVendorSettings,
            onRoutingUpdated: onRoutingUpdated,
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          Text(
            l10n.studioCreatorStartersTitle,
            style: studioControlLabelStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          Text(
            l10n.studioCreatorStartersSubtitle,
            style: studioHintStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          CreatorStarterTemplatesStrip(
            starters: creatorStarterTemplatesForScript(home.cockpit.starterTemplates),
            onApply: onExecuteStarter,
          ),
          if (visibleAgentActions.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            _buildQuickBarAndCockpit(context),
          ],
        ],
      ),
    );
  }
}
