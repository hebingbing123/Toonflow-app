// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

/// Main product sections builder extension for _HomePageState.
/// This file serves as the entry point for product-related UI building.
/// Implementation details are split across multiple part files for maintainability.
///
/// Related files:
/// - product_scope_management.dart: Project scope selection and management
/// - product_navigation.dart: Deep links and navigation logic
/// - product_studio_overlay.dart: Studio overlay widgets
/// - product_studio_steps.dart: Studio step body builders
/// - product_workbench_launchers.dart: Workbench dialog launchers
/// - product_agent_workspace.dart: Agent workspace pane builder
/// - product_panes_builder.dart: Product pane selector and active panes
extension _HomePageBuildProductSections on _HomePageState {
  List<Widget> _buildProductSections(BuildContext context) {
    return <Widget>[
      _buildProductPaneSelector(context),
      ..._buildActiveProductPaneWidgets(context),
    ];
  }
}
