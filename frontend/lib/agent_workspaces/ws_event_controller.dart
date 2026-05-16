import 'dart:convert';

import '../shell/workspace_ws_event_resolution.dart';
import 'input_controller.dart';
import 'operation_controller.dart';
import 'runtime_output_controller.dart';

typedef WorkspaceWsBusyProvider = bool Function();
typedef WorkspaceWsFlagReset = void Function();
typedef WorkspaceWsRawEventHandler = void Function(Map<String, dynamic> event);

class WorkspaceWsEventController {
  WorkspaceWsEventController({
    required WorkspaceWsBusyProvider skillsHarnessBusyProvider,
    required WorkspaceWsFlagReset resetSkillsHarnessBusyFlags,
    required WorkspaceWsFlagReset clearSkillsHarnessToolProbeFlags,
    required WorkspaceWsFlagReset clearSkillsHarnessAgentProbeFlags,
    required WorkspaceOperationController operationController,
    required WorkspaceOutputController outputController,
    required WorkspaceInputController inputController,
    WorkspaceWsRawEventHandler? onRawEvent,
  }) : _skillsHarnessBusyProvider = skillsHarnessBusyProvider,
       _resetSkillsHarnessBusyFlags = resetSkillsHarnessBusyFlags,
       _clearSkillsHarnessToolProbeFlags = clearSkillsHarnessToolProbeFlags,
       _clearSkillsHarnessAgentProbeFlags = clearSkillsHarnessAgentProbeFlags,
       _operationController = operationController,
       _outputController = outputController,
       _inputController = inputController,
       _onRawEvent = onRawEvent;

  final WorkspaceWsBusyProvider _skillsHarnessBusyProvider;
  final WorkspaceWsFlagReset _resetSkillsHarnessBusyFlags;
  final WorkspaceWsFlagReset _clearSkillsHarnessToolProbeFlags;
  final WorkspaceWsFlagReset _clearSkillsHarnessAgentProbeFlags;
  final WorkspaceOperationController _operationController;
  final WorkspaceOutputController _outputController;
  final WorkspaceInputController _inputController;
  final WorkspaceWsRawEventHandler? _onRawEvent;

  bool get wsProbesBusy =>
      _skillsHarnessBusyProvider() || _operationController.hasPendingWork;

  void resetWsOperationFlags() {
    _operationController.resetWsOperations();
  }

  void handleRawMessage(String raw) {
    final decoded = _tryDecodeWsJson(raw);
    if (decoded != null) {
      _ingestWorkspaceWsEvent(decoded);
    }
  }

  Map<String, dynamic>? _tryDecodeWsJson(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  void _ingestWorkspaceWsEvent(Map<String, dynamic> event) {
    _onRawEvent?.call(event);
    final resolution = resolveWorkspaceWsEvent(event);
    if (resolution.clearAllOperations) {
      _resetSkillsHarnessBusyFlags();
      _operationController.resetWsOperations();
    } else {
      if (resolution.clearToolOperations) {
        _clearSkillsHarnessToolProbeFlags();
        _operationController.clearToolOperations();
      }
      if (resolution.clearAgentOperations) {
        _clearSkillsHarnessAgentProbeFlags();
        _operationController.clearAgentOperations();
      }
    }

    final type = event['type'];
    if (type is! String || type.isEmpty) {
      return;
    }
    final payload = event['payload'];
    final payloadMap = payload is Map<String, dynamic> ? payload : null;

    if (type == 'harness.agent.started') {
      _outputController.markAgentStarted();
      return;
    }

    if (type == 'chat.content.updated' && payloadMap != null) {
      final append = payloadMap['append'];
      if (append is String && append.isNotEmpty) {
        _outputController.appendAssistantText(append);
      }
      return;
    }

    if (type == 'harness.tool.result' && payloadMap != null) {
      final name = payloadMap['name'];
      final result = payloadMap['result'];
      if (name is String) {
        _outputController.recordToolResult(
          name,
          result,
          currentFlowKey: _inputController.productionFlowKeyController.text,
        );
      }
      return;
    }

    if (type == 'harness.agent.cancelled') {
      _outputController.markCancelled();
    }
  }
}
