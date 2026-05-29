import '../content_compliance/controller.dart';

String studioComplianceStatusForBatchAction(String action) {
  switch (action.trim().toLowerCase()) {
    case 'claim':
      return 'claimed';
    case 'dismiss':
      return 'dismissed';
    case 'resolve':
      return 'resolved';
    default:
      return action.trim().toLowerCase();
  }
}

ContentComplianceReportItemV1 studioComplianceReportWithStatus(
  ContentComplianceReportItemV1 row, {
  required String status,
  String? actorLabel,
  String? resolutionNote,
}) {
  final stamp = DateTime.now().toUtc().toIso8601String();
  final claimed = status == 'claimed';
  final terminal = status == 'resolved' || status == 'dismissed';
  return ContentComplianceReportItemV1(
    id: row.id,
    reporterUserId: row.reporterUserId,
    reporterEmail: row.reporterEmail,
    targetType: row.targetType,
    targetId: row.targetId,
    workspaceId: row.workspaceId,
    workspaceName: row.workspaceName,
    projectId: row.projectId,
    projectName: row.projectName,
    category: row.category,
    severity: row.severity,
    status: status,
    escalationStage: row.escalationStage,
    detail: row.detail,
    claimedByLabel: claimed
        ? actorLabel ?? row.claimedByLabel ?? 'internal_ops'
        : row.claimedByLabel,
    claimedAt: claimed ? stamp : row.claimedAt,
    resolutionLabel: terminal ? actorLabel ?? row.resolutionLabel : row.resolutionLabel,
    resolutionNote: terminal ? resolutionNote ?? row.resolutionNote : row.resolutionNote,
    resolvedAt: terminal ? stamp : row.resolvedAt,
    createdAt: row.createdAt,
  );
}

ContentComplianceQueueResponseV1? studioComplianceQueueMapReports(
  ContentComplianceQueueResponseV1? queue,
  List<ContentComplianceReportItemV1> Function(
    List<ContentComplianceReportItemV1> items,
  ) map,
) {
  if (queue == null) {
    return null;
  }
  return ContentComplianceQueueResponseV1(
    summary: queue.summary,
    sla: queue.sla,
    capacity: queue.capacity,
    alerts: queue.alerts,
    workspaceSummaries: queue.workspaceSummaries,
    ownerSummaries: queue.ownerSummaries,
    escalationSummaries: queue.escalationSummaries,
    items: map(queue.items),
  );
}

ContentComplianceQueueResponseV1? studioComplianceQueueUpdateReports(
  ContentComplianceQueueResponseV1? queue,
  Set<String> reportIds,
  ContentComplianceReportItemV1 Function(ContentComplianceReportItemV1 row) update,
) {
  return studioComplianceQueueMapReports(queue, (items) {
    return items
        .map(
          (row) => reportIds.contains(row.id) ? update(row) : row,
        )
        .toList(growable: false);
  });
}
