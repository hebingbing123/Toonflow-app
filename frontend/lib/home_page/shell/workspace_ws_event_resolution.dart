class WorkspaceWsEventResolution {
  const WorkspaceWsEventResolution({
    this.clearAllOperations = false,
    this.clearToolOperations = false,
    this.clearAgentOperations = false,
    this.markCancelled = false,
  });

  final bool clearAllOperations;
  final bool clearToolOperations;
  final bool clearAgentOperations;
  final bool markCancelled;
}

WorkspaceWsEventResolution resolveWorkspaceWsEvent(Map<String, dynamic> event) {
  final type = event['type'];
  if (type is! String || type.isEmpty) {
    return const WorkspaceWsEventResolution();
  }
  final payload = event['payload'];
  final payloadMap = payload is Map<String, dynamic> ? payload : null;

  if (type == 'error.occurred') {
    return const WorkspaceWsEventResolution(clearAllOperations: true);
  }

  if (type == 'harness.tool.result') {
    return const WorkspaceWsEventResolution(clearToolOperations: true);
  }

  if (type == 'harness.agent.cancelled') {
    return const WorkspaceWsEventResolution(
      clearAgentOperations: true,
      markCancelled: true,
    );
  }

  if (type == 'chat.message.updated' && payloadMap != null) {
    final status = payloadMap['status'];
    if (status == 'complete' || status == 'stop' || status == 'error') {
      return const WorkspaceWsEventResolution(clearAgentOperations: true);
    }
  }

  return const WorkspaceWsEventResolution();
}
