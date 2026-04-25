import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/input_controller.dart';
import 'package:openflow_app/agent_workspaces/operation_controller.dart';
import 'package:openflow_app/agent_workspaces/run_controller.dart';
import 'package:openflow_app/agent_workspaces/runtime_output_controller.dart';

void main() {
  test('workspace run controller builds script workspace messages', () async {
    final inputController = WorkspaceInputController();
    final operationController = WorkspaceOperationController();
    final outputController = WorkspaceOutputController();
    addTearDown(inputController.dispose);

    final sent = <List<Map<String, dynamic>>>[];
    String? lastError = 'seed';
    var clearWsLogCalls = 0;
    var resetOutputCalls = 0;
    final controller = WorkspaceRunController(
      inputController: inputController,
      operationController: operationController,
      outputController: outputController,
      accessTokenProvider: () => 'token',
      onErrorChanged: (error) => lastError = error,
      clearWsLog: () => clearWsLogCalls++,
      resetWorkspaceOutputs: () => resetOutputCalls++,
      requestSender: (token, messages) async {
        sent.add(messages);
        return true;
      },
    );

    inputController.projectIdController.text = '42';
    inputController.scriptPromptController.text = 'draft script';
    await controller.runScriptWorkspaceAgent();

    expect(lastError, isNull);
    expect(clearWsLogCalls, 1);
    expect(resetOutputCalls, 1);
    expect(operationController.loadingScriptWorkspaceRun, isTrue);
    expect(sent, hasLength(1));
    expect(sent.single[0]['type'], 'agent.script.attach');
    expect(sent.single[0]['payload'], containsPair('project_id', 42));
    expect(sent.single[1]['type'], 'harness.agent.run');
    expect(sent.single[1]['payload'], containsPair('content', 'draft script'));
  });

  test(
    'workspace run controller injects flow key and resets loading on send failure',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError;
      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async {
          expect(messages[1]['payload'], <String, dynamic>{
            'name': 'get_flowData',
            'arguments': <String, dynamic>{'key': 'storyboard', 'scriptId': 7},
          });
          return false;
        },
      );

      inputController.projectIdController.text = '5';
      inputController.scriptIdController.text = '7';
      inputController.productionFlowKeyController.text = 'storyboard';
      inputController.productionDomainArgsController.text = '{}';
      await controller.probeProductionDomainTool();

      expect(lastError, isNull);
      expect(operationController.loadingProductionFlowProbe, isFalse);
    },
  );

  test('workspace run controller reports validation errors', () async {
    final inputController = WorkspaceInputController();
    final operationController = WorkspaceOperationController();
    final outputController = WorkspaceOutputController();
    addTearDown(inputController.dispose);

    String? lastError;
    final controller = WorkspaceRunController(
      inputController: inputController,
      operationController: operationController,
      outputController: outputController,
      accessTokenProvider: () => 'token',
      onErrorChanged: (error) => lastError = error,
      clearWsLog: () {},
      resetWorkspaceOutputs: () {},
      requestSender: (token, messages) async => true,
    );

    inputController.projectIdController.text = '';
    inputController.scriptPromptController.text = '';
    await controller.runScriptWorkspaceAgent();

    expect(lastError, 'project_id 与 prompt 必须有效');
    expect(operationController.hasPendingWork, isFalse);
  });
}
