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
    'workspace writeback controller resolves project numeric id from project uuid for plan writeback',
    () async {
      final inputController = WorkspaceInputController();
      final operationController = WorkspaceOperationController();
      final outputController = WorkspaceOutputController();
      addTearDown(inputController.dispose);

      String? lastError = 'seed';
      var fetchAllProjectsCalls = 0;
      int? savedProjectId;
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
            <String, dynamic>{'id': 1, 'content': 'row 1'},
          ],
        },
      });

      await controller.writeBackScriptPlanWorkspaceResult();

      expect(lastError, isNull);
      expect(fetchAllProjectsCalls, 1);
      expect(savedProjectId, 42);
      expect(outputController.writebackLine, contains('project=42'));
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
