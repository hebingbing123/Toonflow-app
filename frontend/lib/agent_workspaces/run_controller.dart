import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'input_controller.dart';
import 'operation_controller.dart';
import 'runtime_output_controller.dart';

part 'run_controller_helpers.dart';

typedef WorkspaceRunAccessTokenProvider = String? Function();
typedef WorkspaceRunErrorSink = void Function(String? error);
typedef WorkspaceRunStateReset = void Function();
typedef WorkspaceRunL10nProvider = AppLocalizations? Function();
typedef WorkspaceRunRequestSender =
    Future<bool> Function(String token, List<Map<String, dynamic>> messages);

class WorkspaceRunController {
  WorkspaceRunController({
    required WorkspaceInputController inputController,
    required WorkspaceOperationController operationController,
    required WorkspaceOutputController outputController,
    required WorkspaceRunAccessTokenProvider accessTokenProvider,
    required WorkspaceRunErrorSink onErrorChanged,
    required WorkspaceRunL10nProvider l10nProvider,
    required WorkspaceRunStateReset clearWsLog,
    required WorkspaceRunStateReset resetWorkspaceOutputs,
    required WorkspaceRunRequestSender requestSender,
  }) : _inputController = inputController,
       _operationController = operationController,
       _outputController = outputController,
       _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider,
       _clearWsLog = clearWsLog,
       _resetWorkspaceOutputs = resetWorkspaceOutputs,
       _requestSender = requestSender;

  final WorkspaceInputController _inputController;
  final WorkspaceOperationController _operationController;
  final WorkspaceOutputController _outputController;
  final WorkspaceRunAccessTokenProvider _accessTokenProvider;
  final WorkspaceRunErrorSink _onErrorChanged;
  final WorkspaceRunL10nProvider _l10nProvider;
  final WorkspaceRunStateReset _clearWsLog;
  final WorkspaceRunStateReset _resetWorkspaceOutputs;
  final WorkspaceRunRequestSender _requestSender;

  AppLocalizations get _l10nResolved =>
      _l10nProvider() ?? lookupAppLocalizations(const Locale('en'));

  Future<void> runScriptWorkspaceAgent() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final proj = _parseProjectAttachInputs(_inputController, loc);
    if (proj.error != null) {
      _onErrorChanged(proj.error);
      return;
    }
    final wsScope = _parseOptionalWorkspaceUuid(_inputController, loc);
    if (wsScope.error != null) {
      _onErrorChanged(wsScope.error);
      return;
    }
    final prompt = _inputController.scriptPromptController.text.trim();
    if (prompt.isEmpty) {
      _onErrorChanged(loc.agentWorkspaceRunPromptRequired);
      return;
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(
      WorkspaceOperation.scriptWorkspaceRun,
      true,
    );
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': _scriptAttachPayload(
          isolationKey: 'flutter-script-workspace',
          projectUuid: proj.projectUuid,
          projectNumeric: proj.projectNumeric,
          workspaceUuid: wsScope.workspaceUuid,
        ),
      },
      <String, dynamic>{
        'type': 'harness.agent.run',
        'schema_version': 1,
        'payload': <String, dynamic>{'content': prompt, 'max_tool_rounds': 12},
      },
    ]);
    if (!sent) {
      _operationController.setLoading(
        WorkspaceOperation.scriptWorkspaceRun,
        false,
      );
    }
  }

  Future<void> probeScriptDomainTool(String toolName, String rawArgs) async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final proj = _parseProjectAttachInputs(_inputController, loc);
    if (proj.error != null) {
      _onErrorChanged(proj.error);
      return;
    }
    final wsScope = _parseOptionalWorkspaceUuid(_inputController, loc);
    if (wsScope.error != null) {
      _onErrorChanged(wsScope.error);
      return;
    }
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final normalizedTool = toolName.trim();
    if (normalizedTool.isEmpty) {
      _onErrorChanged(loc.agentWorkspaceRunToolNameRequired);
      return;
    }
    if (normalizedTool == 'get_script_content' && scriptId == null) {
      _onErrorChanged(loc.agentWorkspaceRunGetScriptContentNeedsScriptId);
      return;
    }

    final args = _parseJsonObject(
      rawArgs,
      objectError: loc.agentWorkspaceRunScriptArgsMustBeObject,
      parseError: loc.agentWorkspaceRunScriptArgsJsonInvalid,
      onErrorChanged: _onErrorChanged,
    );
    if (args == null) {
      return;
    }
    if (normalizedTool == 'get_script_content' && scriptId != null) {
      args.putIfAbsent('scriptId', () => scriptId);
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(WorkspaceOperation.scriptDomainProbe, true);
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': _scriptAttachPayload(
          isolationKey: 'flutter-script-domain-probe',
          projectUuid: proj.projectUuid,
          projectNumeric: proj.projectNumeric,
          workspaceUuid: wsScope.workspaceUuid,
        ),
      },
      <String, dynamic>{
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': <String, dynamic>{'name': normalizedTool, 'arguments': args},
      },
    ]);
    if (sent) {
      _outputController.recordToolInvocation(toolName, args);
    }
    if (!sent) {
      _operationController.setLoading(
        WorkspaceOperation.scriptDomainProbe,
        false,
      );
    }
  }

  Future<void> runScriptSubAgentTool() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final proj = _parseProjectAttachInputs(_inputController, loc);
    if (proj.error != null) {
      _onErrorChanged(proj.error);
      return;
    }
    final wsScopeSub = _parseOptionalWorkspaceUuid(_inputController, loc);
    if (wsScopeSub.error != null) {
      _onErrorChanged(wsScopeSub.error);
      return;
    }
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final prompt = _inputController.scriptPromptController.text.trim();
    final toolName = _inputController.scriptSubAgentToolController.text.trim();
    if (prompt.isEmpty || toolName.isEmpty) {
      _onErrorChanged(loc.agentWorkspaceRunPromptAndToolRequired);
      return;
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(WorkspaceOperation.scriptSubAgentRun, true);
    final arguments = _buildScriptSubAgentArguments(
      toolName: toolName,
      prompt: prompt,
      scriptId: scriptId,
      lastToolName: _outputController.lastToolName,
      lastToolResult: _outputController.lastToolResultData,
      lastToolArguments: _outputController.lastToolArguments,
    );
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': _scriptAttachPayload(
          isolationKey: 'flutter-script-sub-agent-tool',
          projectUuid: proj.projectUuid,
          projectNumeric: proj.projectNumeric,
          workspaceUuid: wsScopeSub.workspaceUuid,
        ),
      },
      <String, dynamic>{
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': <String, dynamic>{'name': toolName, 'arguments': arguments},
      },
    ]);
    if (!sent) {
      _operationController.setLoading(
        WorkspaceOperation.scriptSubAgentRun,
        false,
      );
    }
  }

  Future<void> runProductionWorkspaceAgent() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final proj = _parseProjectAttachInputs(_inputController, loc);
    if (proj.error != null) {
      _onErrorChanged(proj.error);
      return;
    }
    final wsScopeProd = _parseOptionalWorkspaceUuid(_inputController, loc);
    if (wsScopeProd.error != null) {
      _onErrorChanged(wsScopeProd.error);
      return;
    }
    final scr = _parseScriptAttachInputs(_inputController, loc);
    if (scr.error != null) {
      _onErrorChanged(scr.error);
      return;
    }
    final prompt = _inputController.productionPromptController.text.trim();
    if (prompt.isEmpty) {
      _onErrorChanged(loc.agentWorkspaceRunPromptRequired);
      return;
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(
      WorkspaceOperation.productionWorkspaceRun,
      true,
    );
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.production.attach',
        'schema_version': 1,
        'payload': _productionAttachPayload(
          isolationKey: 'flutter-production-workspace',
          projectUuid: proj.projectUuid,
          projectNumeric: proj.projectNumeric,
          scriptUuid: scr.scriptUuid,
          scriptNumeric: scr.scriptNumeric,
          workspaceUuid: wsScopeProd.workspaceUuid,
        ),
      },
      <String, dynamic>{
        'type': 'harness.agent.run',
        'schema_version': 1,
        'payload': <String, dynamic>{'content': prompt, 'max_tool_rounds': 12},
      },
    ]);
    if (!sent) {
      _operationController.setLoading(
        WorkspaceOperation.productionWorkspaceRun,
        false,
      );
    }
  }

  Future<void> probeProductionDomainTool() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final proj = _parseProjectAttachInputs(_inputController, loc);
    if (proj.error != null) {
      _onErrorChanged(proj.error);
      return;
    }
    final wsScopeFlow = _parseOptionalWorkspaceUuid(_inputController, loc);
    if (wsScopeFlow.error != null) {
      _onErrorChanged(wsScopeFlow.error);
      return;
    }
    final scr = _parseScriptAttachInputs(_inputController, loc);
    if (scr.error != null) {
      _onErrorChanged(scr.error);
      return;
    }
    final toolName = _inputController.productionDomainToolController.text
        .trim();
    if (toolName.isEmpty) {
      _onErrorChanged(loc.agentWorkspaceRunToolNameRequired);
      return;
    }

    final args = _parseJsonObject(
      _inputController.productionDomainArgsController.text,
      objectError: loc.agentWorkspaceRunProductionArgsMustBeObject,
      parseError: loc.agentWorkspaceRunProductionArgsJsonInvalid,
      onErrorChanged: _onErrorChanged,
    );
    if (args == null) {
      return;
    }
    if (toolName == 'get_flowData') {
      final key = _inputController.productionFlowKeyController.text.trim();
      if (key.isEmpty) {
        _onErrorChanged(loc.agentWorkspaceRunGetFlowDataNeedsKey);
        return;
      }
      args.putIfAbsent('key', () => key);
      final scriptNumeric = scr.scriptNumeric;
      if (scriptNumeric != null) {
        args.putIfAbsent('scriptId', () => scriptNumeric);
      }
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(
      WorkspaceOperation.productionFlowProbe,
      true,
    );
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.production.attach',
        'schema_version': 1,
        'payload': _productionAttachPayload(
          isolationKey: 'flutter-production-flow-probe',
          projectUuid: proj.projectUuid,
          projectNumeric: proj.projectNumeric,
          scriptUuid: scr.scriptUuid,
          scriptNumeric: scr.scriptNumeric,
          workspaceUuid: wsScopeFlow.workspaceUuid,
        ),
      },
      <String, dynamic>{
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': <String, dynamic>{'name': toolName, 'arguments': args},
      },
    ]);
    if (!sent) {
      _operationController.setLoading(
        WorkspaceOperation.productionFlowProbe,
        false,
      );
    }
  }

  Future<void> runProductionSubAgentTool() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final proj = _parseProjectAttachInputs(_inputController, loc);
    if (proj.error != null) {
      _onErrorChanged(proj.error);
      return;
    }
    final wsScopePa = _parseOptionalWorkspaceUuid(_inputController, loc);
    if (wsScopePa.error != null) {
      _onErrorChanged(wsScopePa.error);
      return;
    }
    final scr = _parseScriptAttachInputs(_inputController, loc);
    if (scr.error != null) {
      _onErrorChanged(scr.error);
      return;
    }
    final prompt = _inputController.productionPromptController.text.trim();
    final toolName = _inputController.productionSubAgentToolController.text
        .trim();
    final extraArgs = _parseJsonObject(
      _inputController.productionSubAgentArgsController.text,
      objectError: loc.agentWorkspaceRunProductionSubAgentArgsMustBeObject,
      parseError: loc.agentWorkspaceRunProductionSubAgentArgsJsonInvalid,
      onErrorChanged: _onErrorChanged,
    );
    if (prompt.isEmpty || toolName.isEmpty || extraArgs == null) {
      _onErrorChanged(loc.agentWorkspaceRunPromptAndToolRequired);
      return;
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(
      WorkspaceOperation.productionSubAgentRun,
      true,
    );
    final arguments = <String, dynamic>{'prompt': prompt, ...extraArgs};
    final scriptNumeric = scr.scriptNumeric;
    if (scriptNumeric != null) {
      arguments['scriptId'] = scriptNumeric;
    }
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.production.attach',
        'schema_version': 1,
        'payload': _productionAttachPayload(
          isolationKey: 'flutter-production-sub-agent-tool',
          projectUuid: proj.projectUuid,
          projectNumeric: proj.projectNumeric,
          scriptUuid: scr.scriptUuid,
          scriptNumeric: scr.scriptNumeric,
          workspaceUuid: wsScopePa.workspaceUuid,
        ),
      },
      <String, dynamic>{
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': <String, dynamic>{'name': toolName, 'arguments': arguments},
      },
    ]);
    if (sent) {
      _outputController.recordToolInvocation(toolName, arguments);
    }
    if (!sent) {
      _operationController.setLoading(
        WorkspaceOperation.productionSubAgentRun,
        false,
      );
    }
  }

  void _prepareWorkspaceRun() {
    _prepareWorkspaceRunState(
      clearWsLog: _clearWsLog,
      resetWorkspaceOutputs: _resetWorkspaceOutputs,
      onErrorChanged: _onErrorChanged,
    );
  }
}
