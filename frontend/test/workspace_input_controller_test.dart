import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/input_controller.dart';

void main() {
  test('workspace input controller exposes seeded defaults', () {
    final controller = WorkspaceInputController();
    addTearDown(controller.dispose);

    expect(controller.projectIdController.text, '1');
    expect(controller.scriptIdController.text, '1');
    expect(controller.productionFlowKeyController.text, 'scriptPlan');
    expect(controller.productionDomainToolController.text, 'get_flowData');
    expect(
      controller.productionPromptController.text,
      contains('key=scriptPlan'),
    );
    expect(
      controller.scriptSubAgentToolController.text,
      'run_sub_agent_storySkeleton',
    );
  });

  test('workspace input controller applies normalized suggested flow key', () {
    final controller = WorkspaceInputController();
    addTearDown(controller.dispose);

    controller.applySuggestedProductionFlowKey(' storyboard ');
    expect(controller.productionFlowKeyController.text, 'storyboard');

    controller.applySuggestedProductionFlowKey('   ');
    expect(controller.productionFlowKeyController.text, 'storyboard');
  });

  test('workspace input controller can sync and clear project scope', () {
    final controller = WorkspaceInputController();
    addTearDown(controller.dispose);

    controller.applyProjectScope(23);
    expect(controller.projectIdController.text, '23');
    expect(controller.scriptIdController.text, '1');

    controller.applyProjectScope(23, scriptNumericId: 7);
    expect(controller.projectIdController.text, '23');
    expect(controller.scriptIdController.text, '7');

    controller.clearScriptScope();
    expect(controller.scriptIdController.text, isEmpty);
  });
}
