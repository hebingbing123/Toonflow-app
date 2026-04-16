// ignore_for_file: invalid_use_of_protected_member

part of '../../../home_page.dart';

extension _HomePageAgentWorkspacesController on _HomePageState {
  int? _parsePositiveInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _resetWorkspaceOutputs() {
    _workspaceOutputController.reset();
  }

  void _applySuggestedProductionFlowKey() {
    final suggested = _workspaceOutputController.suggestedFlowKey?.trim();
    if (suggested == null || suggested.isEmpty) {
      return;
    }
    setState(() => _productionFlowKeyCtrl.text = suggested);
  }
}
