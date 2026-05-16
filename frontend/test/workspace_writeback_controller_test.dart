import 'dart:async';

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
      l10nProvider: () => null,
      fetchProjects: (token, projectNumericId) async => const <ProjectRow>[
        ProjectRow(
          id: 'project-uuid',
          numericId: 3,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
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
    expect(outputController.writebackLine, contains('script 8'));
    expect(
      outputController.writebackLine,
      anyOf(contains('已更新'), contains('updated')),
    );
    expect(operationController.loadingScriptResultWriteback, isFalse);
  });

  test(
    'workspace writeback controller falls back to assistant text for script writeback',
    () async {
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
        l10nProvider: () => null,
        fetchProjects: (token, projectNumericId) async => const <ProjectRow>[
          ProjectRow(
            id: 'project-uuid',
            numericId: 3,
            projectAccessMode: 'inherited',
            projectAccessRole: 'member',
          ),
        ],
        updateScript: (token, projectId, scriptNumericId, body) async {
          updatedContent = body['content'] as String;
          return const ScriptRow(
            id: 'script-uuid',
            projectId: 'project-uuid',
            numericId: 8,
            content: 'assistant draft',
          );
        },
      );

      inputController.projectIdController.text = '3';
      inputController.scriptIdController.text = '8';
      outputController.appendAssistantText('assistant draft');

      await controller.writeBackScriptWorkspaceResult();

      expect(lastError, isNull);
      expect(updatedContent, 'assistant draft');
      expect(
        outputController.writebackLine,
        anyOf(contains('Assistant'), contains('助手')),
      );
      expect(operationController.loadingScriptResultWriteback, isFalse);
    },
  );

  test(
    'workspace writeback controller prefers project uuid without fetching projects',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError = 'seed';
      var fetchProjectsCalls = 0;
      String? updatedProjectId;
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
        l10nProvider: () => null,
        fetchProjects: (token, projectNumericId) async {
          fetchProjectsCalls += 1;
          return const <ProjectRow>[];
        },
        updateScript: (token, projectId, scriptNumericId, body) async {
          updatedProjectId = projectId;
          return const ScriptRow(
            id: 'script-uuid',
            projectId: '550e8400-e29b-41d4-a716-446655440000',
            numericId: 12,
            content: 'uuid first body',
          );
        },
      );

      inputController.projectIdController.clear();
      inputController.projectUuidController.text =
          '550e8400-e29b-41d4-a716-446655440000';
      inputController.scriptIdController.text = '12';
      outputController.recordToolResult(
        'run_sub_agent_script',
        <String, dynamic>{'result': 'uuid first body'},
      );

      await controller.writeBackScriptWorkspaceResult();

      expect(lastError, isNull);
      expect(fetchProjectsCalls, 0);
      expect(updatedProjectId, '550e8400-e29b-41d4-a716-446655440000');
      expect(outputController.writebackLine, contains('script 12'));
      expect(
        outputController.writebackLine,
        anyOf(contains('已更新'), contains('updated')),
      );
      expect(operationController.loadingScriptResultWriteback, isFalse);
    },
  );

  test(
    'workspace writeback controller reports project not found for missing script project scope',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError = 'seed';
      var updateCalls = 0;
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
        l10nProvider: () => null,
        fetchProjects: (token, projectNumericId) async => const <ProjectRow>[],
        updateScript: (token, projectId, scriptNumericId, body) async {
          updateCalls += 1;
          return const ScriptRow(
            id: 'script-uuid',
            projectId: 'missing-project',
            numericId: 8,
            content: 'should not happen',
          );
        },
      );

      inputController.projectIdController.text = '999';
      inputController.scriptIdController.text = '8';
      outputController.recordToolResult(
        'run_sub_agent_script',
        <String, dynamic>{'result': 'new script body'},
      );

      await controller.writeBackScriptWorkspaceResult();

      expect(
        lastError,
        anyOf(contains('Project not found'), contains('项目不存在')),
      );
      expect(updateCalls, 0);
      expect(operationController.loadingScriptResultWriteback, isFalse);
    },
  );

  test(
    'workspace writeback controller resolves project numeric id from project uuid for plan writeback',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError = 'seed';
      var fetchAllProjectsCalls = 0;
      int? savedProjectId;
      List<Map<String, dynamic>>? savedScriptRows;
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
        l10nProvider: () => null,
        fetchAllProjects: (token) async {
          fetchAllProjectsCalls += 1;
          return const <ProjectRow>[
            ProjectRow(
              id: '550e8400-e29b-41d4-a716-446655440123',
              numericId: 42,
              projectAccessMode: 'inherited',
              projectAccessRole: 'member',
            ),
          ];
        },
        setPlanData:
            (
              token, {
              required projectId,
              storySkeleton = '',
              adaptationStrategy = '',
              script = const [],
            }) async {
              savedProjectId = projectId;
              savedScriptRows = script
                  .whereType<Map<String, dynamic>>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList(growable: false);
              return 200;
            },
      );

      inputController.projectIdController.clear();
      inputController.projectUuidController.text =
          '550e8400-e29b-41d4-a716-446655440123';
      outputController.recordToolResult('get_planData', <String, dynamic>{
        'data': <String, dynamic>{
          'storySkeleton': 'skeleton',
          'adaptationStrategy': 'strategy',
          'script': const <Map<String, dynamic>>[
            <String, dynamic>{'numeric_id': 1, 'content': 'row 1'},
            <String, dynamic>{'id': 2, 'content': 'row 2', 'name': 'extra'},
            <String, dynamic>{'id': 0, 'content': 'skip me'},
            <String, dynamic>{'id': 5, 'content': 9},
          ],
        },
      });

      await controller.writeBackScriptPlanWorkspaceResult();

      expect(lastError, isNull);
      expect(fetchAllProjectsCalls, 1);
      expect(savedProjectId, 42);
      expect(savedScriptRows, <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'content': 'row 1'},
        <String, dynamic>{'id': 2, 'content': 'row 2'},
      ]);
      expect(outputController.writebackLine, contains('project=42'));
      expect(operationController.loadingScriptPlanResultWriteback, isFalse);
    },
  );

  test(
    'workspace writeback controller updates plan data with normalized script rows',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError = 'seed';
      int? updatedPlanId;
      List<Map<String, dynamic>>? updatedScriptRows;
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
        l10nProvider: () => null,
        updatePlanData:
            (
              token, {
              required id,
              storySkeleton = '',
              adaptationStrategy = '',
              script = const [],
            }) async {
              updatedPlanId = id;
              updatedScriptRows = script
                  .whereType<Map<String, dynamic>>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList(growable: false);
              return 200;
            },
      );

      outputController.recordToolResult('get_planData', <String, dynamic>{
        'planId': 55,
        'data': <String, dynamic>{
          'storySkeleton': 'skeleton',
          'adaptationStrategy': 'strategy',
          'script': const <Map<String, dynamic>>[
            <String, dynamic>{'numeric_id': 3, 'content': 'row 3'},
            <String, dynamic>{'id': 4, 'content': 'row 4'},
            <String, dynamic>{'id': 0, 'content': 'skip me'},
            <String, dynamic>{'numeric_id': 5, 'content': 9},
          ],
        },
      });

      await controller.writeBackScriptPlanViaUpdateData();

      expect(lastError, isNull);
      expect(updatedPlanId, 55);
      expect(updatedScriptRows, <Map<String, dynamic>>[
        <String, dynamic>{'id': 3, 'content': 'row 3'},
        <String, dynamic>{'id': 4, 'content': 'row 4'},
      ]);
      expect(outputController.writebackLine, contains('55'));
      expect(operationController.loadingScriptPlanResultWriteback, isFalse);
    },
  );

  test(
    'workspace writeback controller resolves project numeric id from project uuid for production flow writeback',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError = 'seed';
      var fetchAllProjectsCalls = 0;
      int? fetchedProjectId;
      int? savedProjectId;
      Map<String, dynamic>? savedFlow;
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
        l10nProvider: () => null,
        fetchAllProjects: (token) async {
          fetchAllProjectsCalls += 1;
          return const <ProjectRow>[
            ProjectRow(
              id: '550e8400-e29b-41d4-a716-446655440456',
              numericId: 77,
              projectAccessMode: 'inherited',
              projectAccessRole: 'member',
            ),
          ];
        },
        fetchProductionFlow:
            (token, {required projectId, required episodesId}) async {
              fetchedProjectId = projectId;
              return <String, dynamic>{
                'workspaceResult': <String, dynamic>{'old': true},
              };
            },
        saveProductionFlow:
            (
              token, {
              required projectId,
              required episodesId,
              data = const {},
            }) async {
              savedProjectId = projectId;
              savedFlow = Map<String, dynamic>.from(data);
              return 200;
            },
      );

      inputController.projectIdController.clear();
      inputController.projectUuidController.text =
          '550e8400-e29b-41d4-a716-446655440456';
      inputController.scriptIdController.text = '9';
      inputController.productionFlowKeyController.text = 'workspaceResult';
      outputController.recordToolResult(
        'run_sub_agent_director_plan',
        <String, dynamic>{'result': 'next payload'},
      );

      await controller.writeBackProductionFlowResult();

      expect(lastError, isNull);
      expect(fetchAllProjectsCalls, 1);
      expect(fetchedProjectId, 77);
      expect(savedProjectId, 77);
      expect(savedFlow?['workspaceResult'], <String, dynamic>{
        'result': 'next payload',
      });
      expect(outputController.writebackLine, contains('project 77 / script 9'));
      expect(operationController.loadingProductionResultWriteback, isFalse);
    },
  );

  test(
    'workspace writeback controller marks production writeback loading while resolving project scope',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      final projectLookup = Completer<List<ProjectRow>>();
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
        fetchAllProjects: (token) => projectLookup.future,
      );

      inputController.projectIdController.clear();
      inputController.projectUuidController.text =
          '550e8400-e29b-41d4-a716-446655440456';
      inputController.scriptIdController.text = '9';
      inputController.productionFlowKeyController.text = 'workspaceResult';
      outputController.recordToolResult(
        'run_sub_agent_director_plan',
        <String, dynamic>{'result': 'next payload'},
      );

      final future = controller.writeBackProductionFlowResult();
      expect(operationController.loadingProductionResultWriteback, isTrue);

      projectLookup.complete(const <ProjectRow>[
        ProjectRow(
          id: '550e8400-e29b-41d4-a716-446655440456',
          numericId: 77,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ]);
      await future;

      expect(operationController.loadingProductionResultWriteback, isFalse);
    },
  );

  test(
    'workspace writeback controller refreshes core flow payload for get_flowData writeback',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError = 'seed';
      var fetchFlowCalls = 0;
      Map<String, dynamic>? savedFlow;
      final controller = WorkspaceWritebackController(
        inputController: inputController,
        outputController: outputController,
        operationController: operationController,
        accessTokenProvider: () => 'token',
        onErrorChanged: (error) => lastError = error,
        l10nProvider: () => null,
        fetchProductionFlow:
            (token, {required projectId, required episodesId}) async {
              fetchFlowCalls += 1;
              return <String, dynamic>{
                'storyboard': <String, dynamic>{'frames': 12},
                'workspaceResult': <String, dynamic>{'old': true},
              };
            },
        saveProductionFlow:
            (
              token, {
              required projectId,
              required episodesId,
              data = const {},
            }) async {
              savedFlow = Map<String, dynamic>.from(data);
              return 200;
            },
      );

      inputController.projectIdController.text = '7';
      inputController.scriptIdController.text = '9';
      inputController.productionFlowKeyController.text = 'storyboard';
      outputController.recordToolResult('get_flowData', <String, dynamic>{
        'storyboard': <String, dynamic>{'frames': 1},
      }, currentFlowKey: 'storyboard');

      await controller.writeBackProductionFlowResult();

      expect(lastError, isNull);
      expect(fetchFlowCalls, 2);
      expect(savedFlow?['storyboard'], <String, dynamic>{'frames': 12});
      expect(
        outputController.writebackLine,
        contains('get_flowData -> refreshed full flow[storyboard]'),
      );
      expect(operationController.loadingProductionResultWriteback, isFalse);
    },
  );

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
        l10nProvider: () => null,
      );

      inputController.projectIdController.text = '1';
      inputController.scriptIdController.text = '2';
      inputController.productionFlowKeyController.text = 'assets';
      outputController.recordToolResult(
        'run_sub_agent_director_plan',
        <String, dynamic>{'result': 'plan'},
      );

      await controller.writeBackProductionFlowResult();

      expect(
        lastError,
        anyOf(
          contains('不能直接覆盖核心 flow[assets]'),
          contains('cannot overwrite core flow[assets]'),
        ),
      );
      expect(operationController.loadingProductionResultWriteback, isFalse);
    },
  );
}
