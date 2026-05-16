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
      expect(
        controller.writebackLine,
        anyOf(contains('当前运行已取消'), contains('Run was cancelled')),
      );
    },
  );

  test(
    'workspace output controller clears stale script writeback candidate on empty script tool result',
    () {
      final controller = WorkspaceOutputController();

      controller.recordToolResult('run_sub_agent_script', <String, dynamic>{
        'result': 'draft body',
      });
      expect(controller.scriptWritebackCandidate, 'draft body');
      expect(
        controller.scriptWritebackSource,
        contains('run_sub_agent_script'),
      );

      controller.recordToolResult('get_script_content', <String, dynamic>{
        'content': '   ',
      });

      expect(controller.scriptWritebackCandidate, isNull);
      expect(controller.scriptWritebackSource, isNull);
    },
  );

  test(
    'workspace output controller clears stale plan writeback state on invalid plan result',
    () {
      final controller = WorkspaceOutputController();

      controller.recordToolResult('get_planData', <String, dynamic>{
        'planId': 17,
        'data': <String, dynamic>{'storySkeleton': 'beat'},
      });
      expect(controller.scriptPlanRowId, 17);
      expect(controller.scriptPlanWritebackCandidate, isNotNull);

      controller.recordToolResult('get_planData', <String, dynamic>{
        'planId': 18,
        'data': 'not-an-object',
      });

      expect(controller.scriptPlanWritebackCandidate, isNull);
      expect(controller.scriptPlanRowId, isNull);
    },
  );

  test(
    'workspace output controller accepts string plan ids from plan results',
    () {
      final controller = WorkspaceOutputController();

      controller.recordToolResult('get_planData', <String, dynamic>{
        'planId': '55',
        'data': <String, dynamic>{'storySkeleton': 'beat'},
      });

      expect(controller.scriptPlanRowId, 55);
      expect(controller.scriptPlanWritebackCandidate, isNotNull);
    },
  );

  test(
    'workspace output controller normalizes wrapped persisted plan results',
    () {
      final controller = WorkspaceOutputController();

      controller.recordToolResult('get_planData', <String, dynamic>{
        'data': <String, dynamic>{
          'id': '18',
          'data': <String, dynamic>{
            'story_skeleton': '三幕结构',
            'adaptation_strategy': '先压后扬',
            'script': const <Map<String, dynamic>>[
              <String, dynamic>{'id': 7, 'content': '正文'},
            ],
          },
        },
      });

      expect(controller.scriptPlanRowId, 18);
      expect(controller.scriptPlanWritebackCandidate, <String, dynamic>{
        'planId': 18,
        'data': <String, dynamic>{
          'storySkeleton': '三幕结构',
          'adaptationStrategy': '先压后扬',
          'script': const <Map<String, dynamic>>[
            <String, dynamic>{'id': 7, 'content': '正文'},
          ],
        },
      });
    },
  );

  test(
    'workspace output controller prefers invoked flow key over current input key',
    () {
      final controller = WorkspaceOutputController();

      controller.recordToolInvocation('get_flowData', <String, dynamic>{
        'key': 'storyboard',
        'scriptId': 9,
      });
      controller.recordToolResult('get_flowData', <String, dynamic>{
        'items': <String>['a'],
      }, currentFlowKey: 'assets');

      expect(controller.suggestedFlowKey, 'storyboard');
      expect(controller.lastToolArguments, containsPair('key', 'storyboard'));
    },
  );
}
