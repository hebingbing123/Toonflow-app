import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/input_controller.dart';
import 'package:openflow_app/agent_workspaces/operation_controller.dart';
import 'package:openflow_app/agent_workspaces/runtime_output_controller.dart';
import 'package:openflow_app/agent_workspaces/writeback_controller.dart';
import 'package:openflow_app/rust_api/project/overview.dart';
import 'package:openflow_app/rust_api/scripts/storyboards_models.dart';

void main() {
  test('workspace writeback controller updates script result', () async {
    final inputController = WorkspaceInputController();
    final operationController = WorkspaceOperationController();
    final outputController = WorkspaceOutputController();
    addTearDown(inputController.dispose);

    String? lastError = 'seed';
    var updatedContent = '';
    final controller = WorkspaceWritebackController(
      inputController: inputController,
      outputController: outputController,
      operationController: operationController,
      accessTokenProvider: () => 'token',
      onErrorChanged: (error) => lastError = error,
      fetchProjects: (token, projectNumericId) async => const <ProjectRow>[
        ProjectRow(id: 'project-uuid', numericId: 3),
      ],
      updateScript: (token, projectId, scriptNumericId, body) async {
        updatedContent = body['content'] as String;
        return const ScriptRow(
          id: 'script-uuid',
          projectId: 'project-uuid',
          numericId: 8,
          content: 'new script body',
        );
      },
    );

    inputController.projectIdController.text = '3';
    inputController.scriptIdController.text = '8';
    outputController.recordToolResult('run_sub_agent_script', <String, dynamic>{
      'result': 'new script body',
    });

    await controller.writeBackScriptWorkspaceResult();

    expect(lastError, isNull);
    expect(updatedContent, 'new script body');
    expect(outputController.writebackLine, contains('script 8 已更新'));
    expect(operationController.loadingScriptResultWriteback, isFalse);
  });

  test(
    'workspace writeback controller blocks unsafe core flow overwrite',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError;
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
      );

      inputController.projectIdController.text = '1';
      inputController.scriptIdController.text = '2';
      inputController.productionFlowKeyController.text = 'assets';
      outputController.recordToolResult(
        'run_sub_agent_director_plan',
        <String, dynamic>{'result': 'plan'},
      );

      await controller.writeBackProductionFlowResult();

      expect(lastError, contains('不能直接覆盖核心 flow[assets]'));
      expect(operationController.loadingProductionResultWriteback, isFalse);
    },
  );
}
