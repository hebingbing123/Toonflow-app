import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/operation_controller.dart';

void main() {
  test(
    'workspace operation controller tracks pending work and selective resets',
    () {
      final controller = WorkspaceOperationController();

      controller.setLoading(WorkspaceOperation.scriptWorkspaceRun, true);
      controller.setLoading(WorkspaceOperation.scriptResultWriteback, true);
      controller.setLoading(WorkspaceOperation.productionFlowProbe, true);

      expect(controller.hasPendingWork, isTrue);
      expect(controller.loadingScriptWorkspaceRun, isTrue);
      expect(controller.loadingScriptResultWriteback, isTrue);
      expect(controller.loadingProductionFlowProbe, isTrue);

      controller.clearToolOperations();
      expect(controller.loadingProductionFlowProbe, isFalse);
      expect(controller.loadingScriptWorkspaceRun, isTrue);

      controller.clearAgentOperations();
      expect(controller.loadingScriptWorkspaceRun, isFalse);
      expect(controller.loadingScriptResultWriteback, isTrue);

      controller.reset();
      expect(controller.hasPendingWork, isFalse);
      expect(controller.loadingScriptResultWriteback, isFalse);
    },
  );

  test('workspace operation controller notifies only on real changes', () {
    final controller = WorkspaceOperationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setLoading(WorkspaceOperation.scriptWorkspaceRun, false);
    controller.setLoading(WorkspaceOperation.scriptWorkspaceRun, true);
    controller.setLoading(WorkspaceOperation.scriptWorkspaceRun, true);
    controller.clearAgentOperations();
    controller.clearAgentOperations();

    expect(notifications, 2);
  });
}
