import 'package:flutter/material.dart';

enum WorkspaceOperation {
  scriptWorkspaceRun,
  productionWorkspaceRun,
  productionFlowProbe,
  scriptDomainProbe,
  scriptSubAgentRun,
  productionSubAgentRun,
  scriptResultWriteback,
  scriptPlanResultWriteback,
  productionResultWriteback,
}

class WorkspaceOperationController extends ChangeNotifier {
  bool _loadingScriptWorkspaceRun = false;
  bool _loadingProductionWorkspaceRun = false;
  bool _loadingProductionFlowProbe = false;
  bool _loadingScriptDomainProbe = false;
  bool _loadingScriptSubAgentRun = false;
  bool _loadingProductionSubAgentRun = false;
  bool _loadingScriptResultWriteback = false;
  bool _loadingScriptPlanResultWriteback = false;
  bool _loadingProductionResultWriteback = false;

  bool get loadingScriptWorkspaceRun => _loadingScriptWorkspaceRun;
  bool get loadingProductionWorkspaceRun => _loadingProductionWorkspaceRun;
  bool get loadingProductionFlowProbe => _loadingProductionFlowProbe;
  bool get loadingScriptDomainProbe => _loadingScriptDomainProbe;
  bool get loadingScriptSubAgentRun => _loadingScriptSubAgentRun;
  bool get loadingProductionSubAgentRun => _loadingProductionSubAgentRun;
  bool get loadingScriptResultWriteback => _loadingScriptResultWriteback;
  bool get loadingScriptPlanResultWriteback =>
      _loadingScriptPlanResultWriteback;
  bool get loadingProductionResultWriteback =>
      _loadingProductionResultWriteback;

  bool get hasPendingWork =>
      _loadingScriptWorkspaceRun ||
      _loadingProductionWorkspaceRun ||
      _loadingProductionFlowProbe ||
      _loadingScriptDomainProbe ||
      _loadingScriptSubAgentRun ||
      _loadingProductionSubAgentRun ||
      _loadingScriptResultWriteback ||
      _loadingScriptPlanResultWriteback ||
      _loadingProductionResultWriteback;

  void setLoading(WorkspaceOperation operation, bool value) {
    switch (operation) {
      case WorkspaceOperation.scriptWorkspaceRun:
        if (_loadingScriptWorkspaceRun == value) return;
        _loadingScriptWorkspaceRun = value;
      case WorkspaceOperation.productionWorkspaceRun:
        if (_loadingProductionWorkspaceRun == value) return;
        _loadingProductionWorkspaceRun = value;
      case WorkspaceOperation.productionFlowProbe:
        if (_loadingProductionFlowProbe == value) return;
        _loadingProductionFlowProbe = value;
      case WorkspaceOperation.scriptDomainProbe:
        if (_loadingScriptDomainProbe == value) return;
        _loadingScriptDomainProbe = value;
      case WorkspaceOperation.scriptSubAgentRun:
        if (_loadingScriptSubAgentRun == value) return;
        _loadingScriptSubAgentRun = value;
      case WorkspaceOperation.productionSubAgentRun:
        if (_loadingProductionSubAgentRun == value) return;
        _loadingProductionSubAgentRun = value;
      case WorkspaceOperation.scriptResultWriteback:
        if (_loadingScriptResultWriteback == value) return;
        _loadingScriptResultWriteback = value;
      case WorkspaceOperation.scriptPlanResultWriteback:
        if (_loadingScriptPlanResultWriteback == value) return;
        _loadingScriptPlanResultWriteback = value;
      case WorkspaceOperation.productionResultWriteback:
        if (_loadingProductionResultWriteback == value) return;
        _loadingProductionResultWriteback = value;
    }
    notifyListeners();
  }

  void clearToolOperations() {
    _applyBatchUpdate(() {
      _loadingScriptDomainProbe = false;
      _loadingProductionFlowProbe = false;
      _loadingScriptSubAgentRun = false;
      _loadingProductionSubAgentRun = false;
    });
  }

  void clearAgentOperations() {
    _applyBatchUpdate(() {
      _loadingScriptWorkspaceRun = false;
      _loadingProductionWorkspaceRun = false;
    });
  }

  void resetWsOperations() {
    _applyBatchUpdate(() {
      _loadingScriptWorkspaceRun = false;
      _loadingProductionWorkspaceRun = false;
      _loadingProductionFlowProbe = false;
      _loadingScriptDomainProbe = false;
      _loadingScriptSubAgentRun = false;
      _loadingProductionSubAgentRun = false;
    });
  }

  void reset() {
    _applyBatchUpdate(() {
      _loadingScriptWorkspaceRun = false;
      _loadingProductionWorkspaceRun = false;
      _loadingProductionFlowProbe = false;
      _loadingScriptDomainProbe = false;
      _loadingScriptSubAgentRun = false;
      _loadingProductionSubAgentRun = false;
      _loadingScriptResultWriteback = false;
      _loadingScriptPlanResultWriteback = false;
      _loadingProductionResultWriteback = false;
    });
  }

  void _applyBatchUpdate(VoidCallback apply) {
    final before = (
      _loadingScriptWorkspaceRun,
      _loadingProductionWorkspaceRun,
      _loadingProductionFlowProbe,
      _loadingScriptDomainProbe,
      _loadingScriptSubAgentRun,
      _loadingProductionSubAgentRun,
      _loadingScriptResultWriteback,
      _loadingScriptPlanResultWriteback,
      _loadingProductionResultWriteback,
    );
    apply();
    final after = (
      _loadingScriptWorkspaceRun,
      _loadingProductionWorkspaceRun,
      _loadingProductionFlowProbe,
      _loadingScriptDomainProbe,
      _loadingScriptSubAgentRun,
      _loadingProductionSubAgentRun,
      _loadingScriptResultWriteback,
      _loadingScriptPlanResultWriteback,
      _loadingProductionResultWriteback,
    );
    if (before != after) {
      notifyListeners();
    }
  }
}
