import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/shell/workspace_ws_event_resolution.dart';

void main() {
  test('tool result clears only tool-scoped operations', () {
    final resolution = resolveWorkspaceWsEvent(<String, dynamic>{
      'type': 'harness.tool.result',
      'payload': <String, dynamic>{'name': 'get_planData'},
    });

    expect(resolution.clearAllOperations, isFalse);
    expect(resolution.clearToolOperations, isTrue);
    expect(resolution.clearAgentOperations, isFalse);
    expect(resolution.markCancelled, isFalse);
  });

  test('agent completion clears only agent-scoped operations', () {
    final resolution = resolveWorkspaceWsEvent(<String, dynamic>{
      'type': 'chat.message.updated',
      'payload': <String, dynamic>{'status': 'complete'},
    });

    expect(resolution.clearAllOperations, isFalse);
    expect(resolution.clearToolOperations, isFalse);
    expect(resolution.clearAgentOperations, isTrue);
    expect(resolution.markCancelled, isFalse);
  });

  test('agent cancellation clears agent operations and marks cancellation', () {
    final resolution = resolveWorkspaceWsEvent(<String, dynamic>{
      'type': 'harness.agent.cancelled',
      'payload': <String, dynamic>{},
    });

    expect(resolution.clearAllOperations, isFalse);
    expect(resolution.clearToolOperations, isFalse);
    expect(resolution.clearAgentOperations, isTrue);
    expect(resolution.markCancelled, isTrue);
  });

  test('error clears all websocket operations', () {
    final resolution = resolveWorkspaceWsEvent(<String, dynamic>{
      'type': 'error.occurred',
      'payload': <String, dynamic>{'code': 'bad_request'},
    });

    expect(resolution.clearAllOperations, isTrue);
    expect(resolution.clearToolOperations, isFalse);
    expect(resolution.clearAgentOperations, isFalse);
    expect(resolution.markCancelled, isFalse);
  });

  test('non-terminal updates keep operations active', () {
    final resolution = resolveWorkspaceWsEvent(<String, dynamic>{
      'type': 'chat.content.updated',
      'payload': <String, dynamic>{'append': 'hello'},
    });

    expect(resolution.clearAllOperations, isFalse);
    expect(resolution.clearToolOperations, isFalse);
    expect(resolution.clearAgentOperations, isFalse);
    expect(resolution.markCancelled, isFalse);
  });
}
