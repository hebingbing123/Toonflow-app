import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/input_controller.dart';
import 'package:openflow_app/agent_workspaces/operation_controller.dart';
import 'package:openflow_app/agent_workspaces/runtime_output_controller.dart';
import 'package:openflow_app/agent_workspaces/ws_event_controller.dart';
import 'package:openflow_app/skills_harness/controller.dart';

void main() {
  test('workspace ws controller records tool results and clears tool flags', () {
    final inputController = WorkspaceInputController();
    final operationController = WorkspaceOperationController();
    final outputController = WorkspaceOutputController();
    final skillsHarnessController = SkillsHarnessController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      onWsMessage: (_) {},
      onWsLifecycleSettled: () {},
      onWsConnectionChanged: (_) {},
    );
    addTearDown(inputController.dispose);
    addTearDown(skillsHarnessController.dispose);

    skillsHarnessController.loadingWsHarness = true;
    operationController.setLoading(
      WorkspaceOperation.productionFlowProbe,
      true,
    );
    inputController.productionFlowKeyController.text = 'assets';

    final controller = WorkspaceWsEventController(
      skillsHarnessBusyProvider: () => skillsHarnessController.wsProbesBusy,
      resetSkillsHarnessBusyFlags: skillsHarnessController.resetWsBusyFlags,
      clearSkillsHarnessToolProbeFlags:
          skillsHarnessController.clearToolProbeFlags,
      clearSkillsHarnessAgentProbeFlags:
          skillsHarnessController.clearAgentProbeFlags,
      operationController: operationController,
      outputController: outputController,
      inputController: inputController,
    );

    controller.handleRawMessage(
      '{"type":"harness.tool.result","payload":{"name":"get_flowData","result":{"items":["a"]}}}',
    );

    expect(skillsHarnessController.loadingWsHarness, isFalse);
    expect(operationController.loadingProductionFlowProbe, isFalse);
    expect(outputController.lastToolName, 'get_flowData');
    expect(outputController.suggestedFlowKey, 'assets');
  });

  test(
    'workspace ws controller updates assistant output and cancellation state',
    () {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      final skillsHarnessController = SkillsHarnessController(
        accessTokenProvider: () => null,
        onErrorChanged: (_) {},
        onWsMessage: (_) {},
        onWsLifecycleSettled: () {},
        onWsConnectionChanged: (_) {},
      );
      addTearDown(inputController.dispose);
      addTearDown(skillsHarnessController.dispose);

      final controller = WorkspaceWsEventController(
        skillsHarnessBusyProvider: () => skillsHarnessController.wsProbesBusy,
        resetSkillsHarnessBusyFlags: skillsHarnessController.resetWsBusyFlags,
        clearSkillsHarnessToolProbeFlags:
            skillsHarnessController.clearToolProbeFlags,
        clearSkillsHarnessAgentProbeFlags:
            skillsHarnessController.clearAgentProbeFlags,
        operationController: operationController,
        outputController: outputController,
        inputController: inputController,
      );

      outputController.setWritebackLine('seed');
      controller.handleRawMessage(
        '{"type":"harness.agent.started","payload":{}}',
      );
      controller.handleRawMessage(
        '{"type":"chat.content.updated","payload":{"append":"hello"}}',
      );
      controller.handleRawMessage(
        '{"type":"harness.agent.cancelled","payload":{}}',
      );

      expect(outputController.assistantText, 'hello');
      expect(outputController.writebackLine, contains('当前运行已取消'));
    },
  );

  test('workspace ws controller clears all busy flags for terminal errors', () {
    final inputController = WorkspaceInputController();
    final operationController = WorkspaceOperationController();
    final outputController = WorkspaceOutputController();
    final skillsHarnessController = SkillsHarnessController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      onWsMessage: (_) {},
      onWsLifecycleSettled: () {},
      onWsConnectionChanged: (_) {},
    );
    addTearDown(inputController.dispose);
    addTearDown(skillsHarnessController.dispose);

    skillsHarnessController.loadingWs = true;
    skillsHarnessController.loadingWsHarnessAgent = true;
    operationController.setLoading(WorkspaceOperation.scriptWorkspaceRun, true);
    operationController.setLoading(
      WorkspaceOperation.productionFlowProbe,
      true,
    );

    final controller = WorkspaceWsEventController(
      skillsHarnessBusyProvider: () => skillsHarnessController.wsProbesBusy,
      resetSkillsHarnessBusyFlags: skillsHarnessController.resetWsBusyFlags,
      clearSkillsHarnessToolProbeFlags:
          skillsHarnessController.clearToolProbeFlags,
      clearSkillsHarnessAgentProbeFlags:
          skillsHarnessController.clearAgentProbeFlags,
      operationController: operationController,
      outputController: outputController,
      inputController: inputController,
    );

    controller.handleRawMessage(
      '{"type":"error.occurred","payload":{"code":"bad_request"}}',
    );

    expect(skillsHarnessController.wsProbesBusy, isFalse);
    expect(operationController.hasPendingWork, isFalse);
    expect(controller.wsProbesBusy, isFalse);
  });

  test('workspace ws controller ignores non-object websocket payloads', () {
    final inputController = WorkspaceInputController();
    final operationController = WorkspaceOperationController();
    final outputController = WorkspaceOutputController();
    final skillsHarnessController = SkillsHarnessController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      onWsMessage: (_) {},
      onWsLifecycleSettled: () {},
      onWsConnectionChanged: (_) {},
    );
    addTearDown(inputController.dispose);
    addTearDown(skillsHarnessController.dispose);

    final controller = WorkspaceWsEventController(
      skillsHarnessBusyProvider: () => skillsHarnessController.wsProbesBusy,
      resetSkillsHarnessBusyFlags: skillsHarnessController.resetWsBusyFlags,
      clearSkillsHarnessToolProbeFlags:
          skillsHarnessController.clearToolProbeFlags,
      clearSkillsHarnessAgentProbeFlags:
          skillsHarnessController.clearAgentProbeFlags,
      operationController: operationController,
      outputController: outputController,
      inputController: inputController,
    );

    controller.handleRawMessage('[]');
    controller.handleRawMessage('not-json');

    expect(outputController.assistantText, isEmpty);
    expect(outputController.lastToolName, isNull);
  });
}
