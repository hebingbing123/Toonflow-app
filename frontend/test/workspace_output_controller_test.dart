import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/runtime_output_controller.dart';

void main() {
  test('workspace output controller records tool results and suggestions', () {
    final controller = WorkspaceOutputController();

    controller.recordToolResult('get_flowData', <String, dynamic>{
      'key': 'assets',
      'items': <String>['a'],
    }, currentFlowKey: 'assets');

    expect(controller.lastToolName, 'get_flowData');
    expect(controller.suggestedFlowKey, 'assets');
    expect(controller.lastToolResultLine, contains('get_flowData =>'));
  });

  test(
    'workspace output controller tracks assistant and writeback candidates',
    () {
      final controller = WorkspaceOutputController();

      controller.markAgentStarted();
      controller.appendAssistantText('hello');
      controller.recordToolResult('run_sub_agent_script', <String, dynamic>{
        'result': 'draft body',
      });
      controller.recordToolResult('get_planData', <String, dynamic>{
        'planId': 17,
        'data': <String, dynamic>{'storySkeleton': 'beat'},
      });
      controller.markCancelled();

      expect(controller.assistantText, 'hello');
      expect(controller.scriptWritebackCandidate, 'draft body');
      expect(controller.scriptPlanRowId, 17);
      expect(
        controller.scriptPlanWritebackCandidate,
        containsPair('planId', 17),
      );
      expect(controller.writebackLine, contains('当前运行已取消'));
    },
  );
}
