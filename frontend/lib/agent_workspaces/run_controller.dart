import 'dart:convert';

import 'input_controller.dart';
import 'operation_controller.dart';
import 'runtime_output_controller.dart';

part 'run_controller_helpers.dart';

typedef WorkspaceRunAccessTokenProvider = String? Function();
typedef WorkspaceRunErrorSink = void Function(String? error);
typedef WorkspaceRunStateReset = void Function();
typedef WorkspaceRunRequestSender =
    Future<bool> Function(String token, List<Map<String, dynamic>> messages);

class WorkspaceRunController {
  WorkspaceRunController({
    required WorkspaceInputController inputController,
    required WorkspaceOperationController operationController,
    required WorkspaceOutputController outputController,
    required WorkspaceRunAccessTokenProvider accessTokenProvider,
    required WorkspaceRunErrorSink onErrorChanged,
    required WorkspaceRunStateReset clearWsLog,
    required WorkspaceRunStateReset resetWorkspaceOutputs,
    required WorkspaceRunRequestSender requestSender,
  }) : _inputController = inputController,
       _operationController = operationController,
       _outputController = outputController,
       _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _clearWsLog = clearWsLog,
       _resetWorkspaceOutputs = resetWorkspaceOutputs,
       _requestSender = requestSender;

  final WorkspaceInputController _inputController;
  final WorkspaceOperationController _operationController;
  final WorkspaceOutputController _outputController;
  final WorkspaceRunAccessTokenProvider _accessTokenProvider;
  final WorkspaceRunErrorSink _onErrorChanged;
  final WorkspaceRunStateReset _clearWsLog;
  final WorkspaceRunStateReset _resetWorkspaceOutputs;
  final WorkspaceRunRequestSender _requestSender;

  Future<void> runScriptWorkspaceAgent() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final prompt = _inputController.scriptPromptController.text.trim();
    if (projectId == null || prompt.isEmpty) {
      _onErrorChanged('project_id 与 prompt 必须有效');
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
        'payload': <String, dynamic>{
          'isolation_key': 'flutter-script-workspace',
          'project_id': projectId,
        },
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
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final normalizedTool = toolName.trim();
    if (projectId == null || normalizedTool.isEmpty) {
      _onErrorChanged('project_id/tool 必须有效');
      return;
    }
    if (normalizedTool == 'get_script_content' && scriptId == null) {
      _onErrorChanged('get_script_content 需要有效 script_id');
      return;
    }

    final args = _parseJsonObject(
      rawArgs,
      objectError: 'script tool arguments 必须是 JSON object',
      parseError: 'script tool arguments JSON 解析失败',
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
        'payload': <String, dynamic>{
          'isolation_key': 'flutter-script-domain-probe',
          'project_id': projectId,
        },
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
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final prompt = _inputController.scriptPromptController.text.trim();
    final toolName = _inputController.scriptSubAgentToolController.text.trim();
    if (projectId == null || prompt.isEmpty || toolName.isEmpty) {
      _onErrorChanged('project_id/prompt/tool 必须有效');
      return;
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(WorkspaceOperation.scriptSubAgentRun, true);
    final arguments = <String, dynamic>{'prompt': prompt, 'scriptId': scriptId}
      ..removeWhere((_, Object? value) => value == null);
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': <String, dynamic>{
          'isolation_key': 'flutter-script-sub-agent-tool',
          'project_id': projectId,
        },
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
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final prompt = _inputController.productionPromptController.text.trim();
    if (projectId == null || scriptId == null || prompt.isEmpty) {
      _onErrorChanged('project_id/script_id/prompt 必须有效');
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
        'payload': <String, dynamic>{
          'isolation_key': 'flutter-production-workspace',
          'project_id': projectId,
          'script_id': scriptId,
        },
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
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final toolName = _inputController.productionDomainToolController.text
        .trim();
    if (projectId == null || scriptId == null || toolName.isEmpty) {
      _onErrorChanged('project_id/script_id/tool 必须有效');
      return;
    }

    final args = _parseJsonObject(
      _inputController.productionDomainArgsController.text,
      objectError: 'production tool arguments 必须是 JSON object',
      parseError: 'production tool arguments JSON 解析失败',
      onErrorChanged: _onErrorChanged,
    );
    if (args == null) {
      return;
    }
    if (toolName == 'get_flowData') {
      final key = _inputController.productionFlowKeyController.text.trim();
      if (key.isEmpty) {
        _onErrorChanged('get_flowData 需要有效 key');
        return;
      }
      args.putIfAbsent('key', () => key);
      args.putIfAbsent('scriptId', () => scriptId);
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
        'payload': <String, dynamic>{
          'isolation_key': 'flutter-production-flow-probe',
          'project_id': projectId,
          'script_id': scriptId,
        },
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
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final prompt = _inputController.productionPromptController.text.trim();
    final toolName = _inputController.productionSubAgentToolController.text
        .trim();
    if (projectId == null ||
        scriptId == null ||
        prompt.isEmpty ||
        toolName.isEmpty) {
      _onErrorChanged('project_id/script_id/prompt/tool 必须有效');
      return;
    }

    _prepareWorkspaceRun();
    _operationController.setLoading(
      WorkspaceOperation.productionSubAgentRun,
      true,
    );
    final arguments = <String, dynamic>{'prompt': prompt, 'scriptId': scriptId};
    final sent = await _requestSender(token, <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'agent.production.attach',
        'schema_version': 1,
        'payload': <String, dynamic>{
          'isolation_key': 'flutter-production-sub-agent-tool',
          'project_id': projectId,
          'script_id': scriptId,
        },
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
