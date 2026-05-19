import '../l10n/app_localizations.dart';
import '../l10n/studio_code_labels.dart';

String agentWorkspaceFlowKeyLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'scriptPlan':
      return l10n.agentWorkspacePresetFlowKeyScriptPlan;
    case 'assets':
      return l10n.agentWorkspacePresetFlowKeyAssets;
    case 'script':
      return l10n.agentWorkspacePresetFlowKeyScript;
    case 'storyboardTable':
      return l10n.agentWorkspacePresetFlowKeyStoryboardTable;
    case 'storyboard':
      return l10n.agentWorkspacePresetFlowKeyStoryboard;
    case 'workspaceResult':
      return l10n.agentWorkspacePresetFlowKeyWorkspaceResult;
    default:
      return studioUnknownCodeLabel(l10n, key);
  }
}

String agentWorkspaceProductionDomainToolLabel(
  AppLocalizations l10n,
  String tool,
) {
  switch (tool) {
    case 'get_flowData':
      return l10n.agentWorkspacePresetProductionToolGetFlowData;
    case 'add_deriveAsset':
      return l10n.agentWorkspacePresetProductionToolAddDeriveAsset;
    case 'del_deriveAsset':
      return l10n.agentWorkspacePresetProductionToolDelDeriveAsset;
    case 'generate_deriveAsset':
      return l10n.agentWorkspacePresetProductionToolGenerateDeriveAsset;
    case 'generate_storyboard':
      return l10n.agentWorkspacePresetProductionToolGenerateStoryboard;
    default:
      return studioUnknownCodeLabel(l10n, tool);
  }
}

String agentWorkspaceProductionSubAgentLabel(
  AppLocalizations l10n,
  String tool,
) {
  switch (tool) {
    case 'run_sub_agent_director_plan':
      return l10n.agentWorkspacePresetProductionSubAgentDirectorPlan;
    case 'run_sub_agent_derive_assets':
      return l10n.agentWorkspacePresetProductionSubAgentDeriveAssets;
    case 'run_sub_agent_generate_assets':
      return l10n.agentWorkspacePresetProductionSubAgentGenerateAssets;
    case 'run_sub_agent_production_supervision':
      return l10n.agentWorkspacePresetProductionSubAgentSupervision;
    case 'run_sub_agent_storyboard_gen':
      return l10n.agentWorkspacePresetProductionSubAgentStoryboardGen;
    case 'run_sub_agent_storyboard_panel':
      return l10n.agentWorkspacePresetProductionSubAgentStoryboardPanel;
    case 'run_sub_agent_storyboard_table':
      return l10n.agentWorkspacePresetProductionSubAgentStoryboardTable;
    default:
      return studioUnknownCodeLabel(l10n, tool);
  }
}

String agentWorkspaceScriptDomainToolLabel(AppLocalizations l10n, String tool) {
  switch (tool) {
    case 'get_planData':
      return l10n.agentWorkspacePresetScriptToolGetPlanData;
    case 'get_script_content':
      return l10n.agentWorkspacePresetScriptToolGetScriptContent;
    case 'get_novel_text':
      return l10n.agentWorkspacePresetScriptToolGetNovelText;
    case 'get_novel_events':
      return l10n.agentWorkspacePresetScriptToolGetNovelEvents;
    default:
      return studioUnknownCodeLabel(l10n, tool);
  }
}

String agentWorkspaceScriptSubAgentLabel(AppLocalizations l10n, String tool) {
  switch (tool) {
    case 'run_sub_agent_storySkeleton':
      return l10n.agentWorkspacePresetScriptSubAgentStorySkeleton;
    case 'run_sub_agent_adaptationStrategy':
      return l10n.agentWorkspacePresetScriptSubAgentAdaptationStrategy;
    case 'run_sub_agent_script':
      return l10n.agentWorkspacePresetScriptSubAgentScript;
    case 'run_supervision_agent':
      return l10n.agentWorkspacePresetScriptSubAgentSupervision;
    default:
      return studioUnknownCodeLabel(l10n, tool);
  }
}
