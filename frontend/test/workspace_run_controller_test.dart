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
      l10nProvider: () => null,
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
        l10nProvider: () => null,
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

  test(
    'workspace run controller records production flow probe invocation context on success',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async => true,
      );

      inputController.projectIdController.text = '5';
      inputController.scriptIdController.text = '7';
      inputController.productionFlowKeyController.text = 'storyboard';
      inputController.productionDomainToolController.text = 'get_flowData';
      inputController.productionDomainArgsController.text = '{}';

      await controller.probeProductionDomainTool();

      outputController.recordToolResult('get_flowData', <String, dynamic>{
        'items': <String>['a'],
      }, currentFlowKey: 'assets');

      expect(outputController.suggestedFlowKey, 'storyboard');
      expect(
        outputController.lastToolArguments,
        containsPair('key', 'storyboard'),
      );
      expect(outputController.lastToolArguments, containsPair('scriptId', 7));
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
      l10nProvider: () => null,
      clearWsLog: () {},
      resetWorkspaceOutputs: () {},
      requestSender: (token, messages) async => true,
    );

    inputController.projectIdController.text = '';
    inputController.projectUuidController.clear();
    inputController.scriptPromptController.text = '';
    await controller.runScriptWorkspaceAgent();

    expect(lastError, 'Enter a project UUID or a positive numeric project id');
    expect(operationController.hasPendingWork, isFalse);
  });

  test(
    'workspace run controller auto-attaches compact script scope to sub-agent calls',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final sent = <List<Map<String, dynamic>>>[];
      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async {
          sent.add(messages);
          return true;
        },
      );

      inputController.projectIdController.text = '42';
      inputController.scriptIdController.text = '8';
      inputController.scriptPromptController.text = '输出下一版剧本。';
      inputController.scriptSubAgentToolController.text =
          'run_sub_agent_script';

      outputController.recordToolInvocation(
        'get_script_content',
        <String, dynamic>{'scriptId': 8, 'relativeOffset': -1},
      );
      outputController.recordToolResult('get_script_content', <String, dynamic>{
        'content': '上一集尾段',
      });
      outputController.recordToolInvocation(
        'get_novel_events',
        <String, dynamic>{'novelId': 21},
      );
      outputController.recordToolResult('get_novel_events', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'numeric_id': 21},
          <String, dynamic>{'numeric_id': 22},
          <String, dynamic>{'numeric_id': 21},
        ],
      });

      await controller.runScriptSubAgentTool();

      expect(sent, hasLength(1));
      expect(sent.single[1]['payload'], <String, dynamic>{
        'name': 'run_sub_agent_script',
        'arguments': <String, dynamic>{
          'prompt': '输出下一版剧本。',
          'scriptId': 8,
          'focusSections': <String>[
            'storySkeleton',
            'adaptationStrategy',
            'script',
          ],
          'novelIds': <int>[21, 22],
        },
      });
    },
  );

  test(
    'workspace run controller normalizes string novel ids for sub-agent scope',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final sent = <List<Map<String, dynamic>>>[];
      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async {
          sent.add(messages);
          return true;
        },
      );

      inputController.projectIdController.text = '42';
      inputController.scriptIdController.text = '8';
      inputController.scriptPromptController.text = '继续。';
      inputController.scriptSubAgentToolController.text =
          'run_sub_agent_script';

      outputController.recordToolInvocation('get_novel_text', <String, dynamic>{
        'novelId': '21',
      });
      outputController.recordToolResult('get_novel_text', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'id': '22'},
          <String, dynamic>{'numeric_id': '23'},
          <String, dynamic>{'id': '0'},
        ],
      });

      await controller.runScriptSubAgentTool();

      expect(sent, hasLength(1));
      expect(
        sent.single[1]['payload'],
        containsPair('arguments', containsPair('novelIds', <int>[21, 22, 23])),
      );
    },
  );

  test(
    'workspace run controller records script sub-agent invocation context on success',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async => true,
      );

      inputController.projectIdController.text = '42';
      inputController.scriptIdController.text = '8';
      inputController.scriptPromptController.text = '继续。';
      inputController.scriptSubAgentToolController.text =
          'run_sub_agent_script';

      await controller.runScriptSubAgentTool();

      outputController.recordToolResult(
        'run_sub_agent_script',
        <String, dynamic>{'result': 'draft body'},
      );

      expect(outputController.lastToolName, 'run_sub_agent_script');
      expect(outputController.lastToolArguments, containsPair('prompt', '继续。'));
      expect(outputController.lastToolArguments, containsPair('scriptId', 8));
    },
  );

  test(
    'workspace run controller sends projectUuid when scope field set',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final sent = <List<Map<String, dynamic>>>[];
      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async {
          sent.add(messages);
          return true;
        },
      );

      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      inputController.projectIdController.clear();
      inputController.projectUuidController.text = uuid;
      inputController.scriptPromptController.text = 'hello';

      await controller.runScriptWorkspaceAgent();

      expect(sent, hasLength(1));
      expect(sent.single[0]['type'], 'agent.script.attach');
      final payload = sent.single[0]['payload'] as Map<String, dynamic>;
      expect(payload['projectUuid'], uuid);
      expect(payload.containsKey('project_id'), isFalse);
    },
  );

  test(
    'workspace run controller drops stale script scope for project-only attach',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final sent = <List<Map<String, dynamic>>>[];
      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async {
          sent.add(messages);
          return true;
        },
      );

      inputController.applyProjectScope(
        42,
        scriptNumericId: 8,
        projectUuid: '550e8400-e29b-41d4-a716-446655440000',
        scriptUuid: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        workspaceId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      );
      inputController.applyProjectScope(
        99,
        projectUuid: '550e8400-e29b-41d4-a716-446655440001',
        workspaceId: 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',
      );
      inputController.scriptPromptController.text = 'project only';

      await controller.runScriptWorkspaceAgent();

      expect(sent, hasLength(1));
      expect(sent.single[0]['type'], 'agent.script.attach');
      final payload = sent.single[0]['payload'] as Map<String, dynamic>;
      expect(payload['projectUuid'], '550e8400-e29b-41d4-a716-446655440001');
      expect(payload['project_id'], 99);
      expect(payload['workspaceUuid'], 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff');
      expect(payload.containsKey('script_id'), isFalse);
      expect(payload.containsKey('scriptUuid'), isFalse);
    },
  );

  test(
    'workspace run controller sends workspaceUuid when scope field set',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final sent = <List<Map<String, dynamic>>>[];
      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async {
          sent.add(messages);
          return true;
        },
      );

      const projectUuid = '550e8400-e29b-41d4-a716-446655440000';
      const workspaceUuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
      inputController.projectIdController.clear();
      inputController.projectUuidController.text = projectUuid;
      inputController.workspaceUuidController.text = workspaceUuid;
      inputController.scriptPromptController.text = 'hello';

      await controller.runScriptWorkspaceAgent();

      expect(sent, hasLength(1));
      final payload = sent.single[0]['payload'] as Map<String, dynamic>;
      expect(payload['workspaceUuid'], workspaceUuid);
    },
  );

  test(
    'workspace run controller rejects invalid workspaceUuid format',
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
        onErrorChanged: (e) => lastError = e,
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async => true,
      );

      inputController.projectIdController.text = '1';
      inputController.workspaceUuidController.text = 'not-a-uuid';
      inputController.scriptPromptController.text = 'x';

      await controller.runScriptWorkspaceAgent();

      expect(lastError, 'Invalid workspace UUID format');
    },
  );

  test(
    'workspace run controller sends production attach payload with uuid scope fields',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final sent = <List<Map<String, dynamic>>>[];
      final controller = WorkspaceRunController(
        inputController: inputController,
        operationController: operationController,
        outputController: outputController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        clearWsLog: () {},
        resetWorkspaceOutputs: () {},
        requestSender: (token, messages) async {
          sent.add(messages);
          return true;
        },
      );

      inputController.applyProjectScope(
        42,
        scriptNumericId: 8,
        projectUuid: '550e8400-e29b-41d4-a716-446655440000',
        scriptUuid: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        workspaceId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      );
      inputController.productionPromptController.text = 'run production';

      await controller.runProductionWorkspaceAgent();

      expect(sent, hasLength(1));
      expect(sent.single[0]['type'], 'agent.production.attach');
      final payload = sent.single[0]['payload'] as Map<String, dynamic>;
      expect(payload['projectUuid'], '550e8400-e29b-41d4-a716-446655440000');
      expect(payload['project_id'], 42);
      expect(payload['scriptUuid'], '6ba7b810-9dad-11d1-80b4-00c04fd430c8');
      expect(payload['script_id'], 8);
      expect(payload['workspaceUuid'], 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee');
    },
  );
}
