import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/input_controller.dart';

void main() {
  test('workspace input controller exposes seeded defaults', () {
    final controller = WorkspaceInputController();
    addTearDown(controller.dispose);

    expect(controller.projectIdController.text, '1');
    expect(controller.scriptIdController.text, '1');
    expect(controller.productionFlowKeyController.text, 'assets');
    expect(controller.productionDomainToolController.text, 'get_flowData');
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
}
