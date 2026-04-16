// ignore_for_file: invalid_use_of_protected_member

part of '../../../home_page.dart';

extension _HomePageAgentWorkspacesController on _HomePageState {
  void _resetWorkspaceOutputs() {
    _workspaceOutputController.reset();
  }

  void _applySuggestedProductionFlowKey() {
    _workspaceInputController.applySuggestedProductionFlowKey(
      _workspaceOutputController.suggestedFlowKey,
    );
    setState(() {});
  }
}
