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
  static const Set<WorkspaceOperation> _toolOperations = <WorkspaceOperation>{
    WorkspaceOperation.productionFlowProbe,
    WorkspaceOperation.scriptDomainProbe,
    WorkspaceOperation.scriptSubAgentRun,
    WorkspaceOperation.productionSubAgentRun,
  };

  static const Set<WorkspaceOperation> _agentOperations = <WorkspaceOperation>{
    WorkspaceOperation.scriptWorkspaceRun,
    WorkspaceOperation.productionWorkspaceRun,
  };

  static const Set<WorkspaceOperation> _wsOperations = <WorkspaceOperation>{
    ..._agentOperations,
    ..._toolOperations,
  };

  static const Set<WorkspaceOperation> _allOperations = <WorkspaceOperation>{
    WorkspaceOperation.scriptWorkspaceRun,
    WorkspaceOperation.productionWorkspaceRun,
    WorkspaceOperation.productionFlowProbe,
    WorkspaceOperation.scriptDomainProbe,
    WorkspaceOperation.scriptSubAgentRun,
    WorkspaceOperation.productionSubAgentRun,
    WorkspaceOperation.scriptResultWriteback,
    WorkspaceOperation.scriptPlanResultWriteback,
    WorkspaceOperation.productionResultWriteback,
  };

  final Set<WorkspaceOperation> _activeOperations = <WorkspaceOperation>{};

  bool get loadingScriptWorkspaceRun =>
      _activeOperations.contains(WorkspaceOperation.scriptWorkspaceRun);
  bool get loadingProductionWorkspaceRun =>
      _activeOperations.contains(WorkspaceOperation.productionWorkspaceRun);
  bool get loadingProductionFlowProbe =>
      _activeOperations.contains(WorkspaceOperation.productionFlowProbe);
  bool get loadingScriptDomainProbe =>
      _activeOperations.contains(WorkspaceOperation.scriptDomainProbe);
  bool get loadingScriptSubAgentRun =>
      _activeOperations.contains(WorkspaceOperation.scriptSubAgentRun);
  bool get loadingProductionSubAgentRun =>
      _activeOperations.contains(WorkspaceOperation.productionSubAgentRun);
  bool get loadingScriptResultWriteback =>
      _activeOperations.contains(WorkspaceOperation.scriptResultWriteback);
  bool get loadingScriptPlanResultWriteback =>
      _activeOperations.contains(WorkspaceOperation.scriptPlanResultWriteback);
  bool get loadingProductionResultWriteback =>
      _activeOperations.contains(WorkspaceOperation.productionResultWriteback);

  bool get hasPendingWork => _activeOperations.isNotEmpty;

  void setLoading(WorkspaceOperation operation, bool value) {
    final changed = value
        ? _activeOperations.add(operation)
        : _activeOperations.remove(operation);
    if (changed) {
      notifyListeners();
    }
  }

  void clearToolOperations() {
    _clearOperations(_toolOperations);
  }

  void clearAgentOperations() {
    _clearOperations(_agentOperations);
  }

  void resetWsOperations() {
    _clearOperations(_wsOperations);
  }

  void reset() {
    _clearOperations(_allOperations);
  }

  void _clearOperations(Set<WorkspaceOperation> operations) {
    final before = _activeOperations.length;
    _activeOperations.removeAll(operations);
    if (_activeOperations.length != before) {
      notifyListeners();
    }
  }
}
