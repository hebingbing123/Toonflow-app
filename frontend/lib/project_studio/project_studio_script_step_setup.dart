import 'package:flutter/material.dart';

import '../design_system/components/studio_entrance_motion.dart';
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

/// Script-step setup: model routing, starters, quick actions, cockpit.
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
    this.sheetPresentation = false,
    this.includeModelRouting = true,
    this.onOpenModelRoutingSettings,
  });

  /// When true, renders only the body (for a full-height bottom sheet).
  final bool sheetPresentation;

  /// Script focus mode keeps routing off the canvas (use [onOpenModelRoutingSettings]).
  final bool includeModelRouting;
  final VoidCallback? onOpenModelRoutingSettings;

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

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (includeModelRouting) ...<Widget>[
          StudioStepModelRoutingBar(
            accessToken: accessToken,
            projectId: projectUuid,
            step: StudioStep.script,
            onOpenProjectSettings: onOpenProjectSettings,
            onOpenGlobalModelVendorSettings: onOpenGlobalModelVendorSettings,
            onRoutingUpdated: onRoutingUpdated,
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
        ] else if (onOpenModelRoutingSettings != null) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenModelRoutingSettings,
              icon: const Icon(Icons.hub_outlined, size: StudioIconSize.sm),
              label: Text(l10n.studioScriptStepModelRoutingSettingsLink),
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
        ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = _buildBody(context);
    if (sheetPresentation) {
      return body;
    }

    return StudioWorkbenchSection(
      title: l10n.studioScriptStepSetupTitle,
      subtitle: l10n.studioScriptStepSetupSubtitle,
      initiallyExpanded: false,
      expandTooltip: l10n.studioCockpitExpand,
      collapseTooltip: l10n.studioCockpitCollapse,
      child: body,
    );
  }
}

/// Opens step prep in a tall sheet (script or generic panel).
Future<void> showProjectStudioStepSetupSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Widget body,
}) {
  final tokens = StudioTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.chromeActionGap, StudioSpacing.sm, StudioSpacing.md),
              children: studioStaggeredChildren(
                <Widget>[
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  Text(
                    subtitle,
                    style: studioHintStyle(sheetContext),
                  ),
                  const SizedBox(height: StudioLayoutSpacing.stackMedium),
                  body,
                ],
                entranceKey: title,
              ),
            ),
          );
        },
      );
    },
  );
}

/// Script step prep sheet.
Future<void> showProjectStudioScriptStepSetupSheet(
  BuildContext context, {
  required ProjectStudioScriptStepSetupPanel panel,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showProjectStudioStepSetupSheet(
    context,
    title: l10n.studioScriptStepSetupTitle,
    subtitle: l10n.studioScriptStepSetupSubtitle,
    body: panel,
  );
}
