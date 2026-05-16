import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/input_controller.dart';

void main() {
  test(
    'workspace input controller starts without fake project/script scope',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      expect(controller.projectIdController.text, isEmpty);
      expect(controller.scriptIdController.text, isEmpty);
      expect(controller.productionFlowKeyController.text, 'scriptPlan');
      expect(controller.productionDomainToolController.text, 'get_flowData');
      expect(controller.productionPromptController.text, isEmpty);
      expect(controller.scriptPromptController.text, isEmpty);
      expect(controller.scriptDomainToolController.text, 'get_planData');
      expect(
        controller.scriptSubAgentToolController.text,
        'run_sub_agent_storySkeleton',
      );
    },
  );

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
    expect(controller.scriptIdController.text, isEmpty);

    controller.applyProjectScope(23, scriptNumericId: 7);
    expect(controller.projectIdController.text, '23');
    expect(controller.scriptIdController.text, '7');

    controller.applyProjectScope(
      99,
      scriptNumericId: 3,
      projectUuid: '550e8400-e29b-41d4-a716-446655440001',
      scriptUuid: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      workspaceId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    );
    expect(controller.projectIdController.text, '99');
    expect(controller.scriptIdController.text, '3');
    expect(
      controller.projectUuidController.text,
      '550e8400-e29b-41d4-a716-446655440001',
    );
    expect(
      controller.scriptUuidController.text,
      '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
    );
    expect(
      controller.workspaceUuidController.text,
      'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    );

    controller.clearScriptScope();
    expect(controller.scriptIdController.text, isEmpty);
    expect(controller.scriptUuidController.text, isEmpty);
  });

  test(
    'workspace input controller clears stale script scope on project-only switch',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyProjectScope(
        99,
        scriptNumericId: 3,
        projectUuid: '550e8400-e29b-41d4-a716-446655440001',
        scriptUuid: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        workspaceId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      );

      controller.applyProjectScope(
        100,
        projectUuid: '550e8400-e29b-41d4-a716-446655440002',
        workspaceId: 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',
      );

      expect(controller.projectIdController.text, '100');
      expect(
        controller.projectUuidController.text,
        '550e8400-e29b-41d4-a716-446655440002',
      );
      expect(controller.scriptIdController.text, isEmpty);
      expect(controller.scriptUuidController.text, isEmpty);
      expect(
        controller.workspaceUuidController.text,
        'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',
      );
    },
  );

  test('workspace input controller supports uuid-only scope refs', () {
    final controller = WorkspaceInputController();
    addTearDown(controller.dispose);

    controller.applyProjectScope(
      99,
      scriptNumericId: 3,
      projectUuid: '550e8400-e29b-41d4-a716-446655440001',
      scriptUuid: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      workspaceId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    );

    controller.applyProjectScopeRef(
      projectUuid: '550e8400-e29b-41d4-a716-446655440002',
      workspaceId: 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',
    );

    expect(controller.projectIdController.text, isEmpty);
    expect(
      controller.projectUuidController.text,
      '550e8400-e29b-41d4-a716-446655440002',
    );
    expect(controller.scriptIdController.text, isEmpty);
    expect(controller.scriptUuidController.text, isEmpty);
    expect(
      controller.workspaceUuidController.text,
      'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff',
    );
  });

  test(
    'workspace input controller applyProjectScopeRef replaces stale uuid and script scope',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyProjectScope(
        99,
        scriptNumericId: 3,
        projectUuid: '550e8400-e29b-41d4-a716-446655440001',
        scriptUuid: '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        workspaceId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      );

      controller.applyProjectScopeRef(projectNumericId: 101);

      expect(controller.projectIdController.text, '101');
      expect(controller.projectUuidController.text, isEmpty);
      expect(controller.scriptIdController.text, isEmpty);
      expect(controller.scriptUuidController.text, isEmpty);
      expect(controller.workspaceUuidController.text, isEmpty);
    },
  );

  test('workspace input controller can focus production storyboard scope', () {
    final controller = WorkspaceInputController();
    addTearDown(controller.dispose);

    controller.applyProductionStoryboardFocus(
      scriptNumericId: 42,
      storyboardNumericId: 9,
    );

    expect(controller.productionFlowKeyController.text, 'storyboard');
    expect(controller.productionDomainToolController.text, 'get_flowData');
    expect(
      controller.productionDomainArgsController.text,
      '{"key":"storyboard","fields":["id","index","duration","src","state","associateAssetsIds","shouldGenerateImage"],"ids":[9],"scriptId":42}',
    );
    expect(
      controller.productionSubAgentArgsController.text,
      '{"storyboardIds":[9]}',
    );
  });

  test('workspace input controller applies script domain focus atomically', () {
    final controller = WorkspaceInputController();
    addTearDown(controller.dispose);

    expect(controller.scriptDomainFocusRevision.value, 0);

    controller.applyScriptDomainFocus(
      domainTool: 'get_script_content',
      rawDomainArgs:
          '{"scriptId":42,"lineStart":61,"lineEnd":120,"maxChars":1600}',
      subAgentTool: 'run_sub_agent_script',
      prompt: 'repair this tail window',
    );

    expect(controller.scriptDomainToolController.text, 'get_script_content');
    expect(
      controller.scriptDomainArgsController.text,
      '{"scriptId":42,"lineStart":61,"lineEnd":120,"maxChars":1600}',
    );
    expect(
      controller.scriptSubAgentToolController.text,
      'run_sub_agent_script',
    );
    expect(controller.scriptPromptController.text, 'repair this tail window');
    expect(controller.scriptDomainFocusRevision.value, 1);
  });

  test(
    'workspace input controller applies production domain focus atomically',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      expect(controller.productionDomainFocusRevision.value, 0);

      controller.applyProductionDomainFocus(
        flowKey: 'storyboard',
        domainTool: 'generate_storyboard',
        rawDomainArgs: '{"ids":[9,12]}',
        subAgentTool: 'run_sub_agent_storyboard_gen',
        rawSubAgentArgs: '{"storyboardIds":[9,12]}',
        prompt: 'repair these storyboard shots',
      );

      expect(controller.productionFlowKeyController.text, 'storyboard');
      expect(
        controller.productionDomainToolController.text,
        'generate_storyboard',
      );
      expect(controller.productionDomainArgsController.text, '{"ids":[9,12]}');
      expect(
        controller.productionSubAgentToolController.text,
        'run_sub_agent_storyboard_gen',
      );
      expect(
        controller.productionSubAgentArgsController.text,
        '{"storyboardIds":[9,12]}',
      );
      expect(
        controller.productionPromptController.text,
        'repair these storyboard shots',
      );
      expect(controller.productionDomainFocusRevision.value, 1);
    },
  );

  test(
    'workspace input controller normalizes blank raw focus args to empty objects',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyScriptDomainFocus(
        domainTool: 'get_planData',
        rawDomainArgs: '   ',
      );
      expect(controller.scriptDomainArgsController.text, '{}');
      expect(controller.scriptDomainFocusRevision.value, 1);

      controller.applyProductionDomainFocus(
        flowKey: 'storyboard',
        domainTool: 'generate_storyboard',
        rawDomainArgs: '   ',
        rawSubAgentArgs: '   ',
        subAgentTool: 'run_sub_agent_storyboard_gen',
      );
      expect(controller.productionDomainArgsController.text, '{}');
      expect(controller.productionSubAgentArgsController.text, '{}');
      expect(controller.productionDomainFocusRevision.value, 1);
    },
  );

  test(
    'workspace input controller maps rollback action to script planning focus',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyScriptRepairFocus(
        scriptNumericId: 42,
        suggestedAction: 'rollback_to_director_planning',
      );

      expect(controller.scriptDomainToolController.text, 'get_planData');
      expect(
        controller.scriptDomainArgsController.text,
        '{"key":"adaptationStrategy","maxChars":1600}',
      );
      expect(
        controller.scriptSubAgentToolController.text,
        'run_sub_agent_adaptationStrategy',
      );
    },
  );

  test(
    'workspace input controller maps director-planning stage to adaptation strategy focus',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyScriptRepairFocus(
        scriptNumericId: 42,
        stage: 'director_planning',
      );

      expect(controller.scriptDomainToolController.text, 'get_planData');
      expect(
        controller.scriptDomainArgsController.text,
        '{"key":"adaptationStrategy","maxChars":1600}',
      );
      expect(
        controller.scriptSubAgentToolController.text,
        'run_sub_agent_adaptationStrategy',
      );
    },
  );

  test(
    'workspace input controller maps story-skeleton stage to story skeleton focus',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyScriptRepairFocus(
        scriptNumericId: 42,
        stage: 'story_skeleton',
      );

      expect(controller.scriptDomainToolController.text, 'get_planData');
      expect(
        controller.scriptDomainArgsController.text,
        '{"key":"storySkeleton","maxChars":1600}',
      );
      expect(
        controller.scriptSubAgentToolController.text,
        'run_sub_agent_storySkeleton',
      );
    },
  );

  test(
    'workspace input controller defaults script repair focus to story skeleton',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyScriptRepairFocus(scriptNumericId: 42);

      expect(controller.scriptDomainToolController.text, 'get_planData');
      expect(
        controller.scriptDomainArgsController.text,
        '{"key":"storySkeleton","maxChars":1600}',
      );
      expect(
        controller.scriptSubAgentToolController.text,
        'run_sub_agent_storySkeleton',
      );
    },
  );

  test(
    'workspace input controller maps patch storyboard action to panel tool',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyProductionStoryboardFocus(
        scriptNumericId: 42,
        storyboardNumericId: 9,
        suggestedAction: 'patch_storyboard_items',
      );

      expect(controller.productionFlowKeyController.text, 'storyboard');
      expect(controller.productionDomainToolController.text, 'get_flowData');
      expect(
        controller.productionSubAgentToolController.text,
        'run_sub_agent_storyboard_panel',
      );
      expect(
        controller.productionDomainArgsController.text,
        '{"key":"storyboard","fields":["id","index","duration","src","state","associateAssetsIds","shouldGenerateImage"],"ids":[9],"scriptId":42}',
      );
      expect(
        controller.productionSubAgentArgsController.text,
        '{"storyboardIds":[9]}',
      );
    },
  );

  test(
    'workspace input controller maps regenerate action to storyboard generation tool',
    () {
      final controller = WorkspaceInputController();
      addTearDown(controller.dispose);

      controller.applyProductionStoryboardFocus(
        storyboardNumericId: 9,
        suggestedAction: 'regenerate_storyboard',
      );

      expect(controller.productionFlowKeyController.text, 'storyboard');
      expect(
        controller.productionDomainToolController.text,
        'generate_storyboard',
      );
      expect(
        controller.productionSubAgentToolController.text,
        'run_sub_agent_storyboard_gen',
      );
      expect(controller.productionDomainArgsController.text, '{"ids":[9]}');
      expect(
        controller.productionSubAgentArgsController.text,
        '{"storyboardIds":[9]}',
      );
    },
  );
}
