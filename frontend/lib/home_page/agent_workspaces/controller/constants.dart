part of '../../../home_page.dart';

extension _HomePageAgentWorkspacesControllerConstants on _HomePageState {
  static const Set<String> _coreProductionFlowKeys = <String>{
    'assets',
    'script',
    'scriptPlan',
    'storyboardTable',
    'storyboard',
  };

  static const Map<String, String> _toolRefreshableCoreFlowKey =
      <String, String>{
        'add_deriveAsset': 'assets',
        'del_deriveAsset': 'assets',
        'generate_deriveAsset': 'assets',
        'generate_storyboard': 'storyboard',
        'run_sub_agent_derive_assets': 'assets',
        'run_sub_agent_generate_assets': 'assets',
        'run_sub_agent_storyboard_gen': 'storyboard',
        'run_sub_agent_storyboard_panel': 'storyboard',
        'run_sub_agent_storyboard_table': 'storyboardTable',
        'run_sub_agent_director_plan': 'scriptPlan',
      };
}
