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

  test('workspace input controller clears stale script scope on project-only switch', () {
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
  });

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
}
