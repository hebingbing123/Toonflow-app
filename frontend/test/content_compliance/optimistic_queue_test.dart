import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/content_compliance/controller.dart';
import 'package:openflow_app/content_compliance/optimistic_queue.dart';

ContentComplianceReportItemV1 _report({required String id, String status = 'pending'}) {
  return ContentComplianceReportItemV1(
    id: id,
    reporterUserId: 'user',
    reporterEmail: null,
    targetType: 'project',
    targetId: 'target',
    workspaceId: null,
    workspaceName: null,
    projectId: null,
    projectName: null,
    category: 'safety',
    severity: 'high',
    status: status,
    escalationStage: 'watch',
    detail: null,
    claimedByLabel: null,
    claimedAt: null,
    resolutionLabel: null,
    resolutionNote: null,
    resolvedAt: null,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

ContentComplianceQueueResponseV1 _queue(List<ContentComplianceReportItemV1> items) {
  return ContentComplianceQueueResponseV1(
    summary: const ContentComplianceQueueSummaryV1(
      pending: 1,
      claimed: 0,
      resolved: 0,
      dismissed: 0,
      critical: 0,
      high: 1,
    ),
    sla: const ContentComplianceQueueSlaSummaryV1(
      openOver24h: 0,
      openOver72h: 0,
      claimedOver24h: 0,
      unclaimedCritical: 0,
      oldestOpenAgeHours: 0,
    ),
    capacity: const ContentComplianceQueueCapacitySummaryV1(
      reviewerCapacityLimit: 12,
      overloadedReviewerCount: 0,
      overloadedClaimedCount: 0,
    ),
    alerts: const <ContentComplianceQueueAlertV1>[],
    workspaceSummaries: const <ContentComplianceWorkspaceSummaryV1>[],
    ownerSummaries: const <ContentComplianceOwnerSummaryV1>[],
    escalationSummaries: const <ContentComplianceEscalationSummaryV1>[],
    items: items,
  );
}

void main() {
  test('studioComplianceStatusForBatchAction maps claim/dismiss/resolve', () {
    expect(studioComplianceStatusForBatchAction('claim'), 'claimed');
    expect(studioComplianceStatusForBatchAction('DISMISS'), 'dismissed');
    expect(studioComplianceStatusForBatchAction('resolve'), 'resolved');
  });

  test('studioComplianceQueueUpdateReports updates selected rows', () {
    final queue = _queue(<ContentComplianceReportItemV1>[
      _report(id: 'a'),
      _report(id: 'b'),
    ]);
    final next = studioComplianceQueueUpdateReports(
      queue,
      {'a'},
      (row) => studioComplianceReportWithStatus(
        row,
        status: 'claimed',
        actorLabel: 'ops',
      ),
    );
    expect(next?.items.first.status, 'claimed');
    expect(next?.items.last.status, 'pending');
  });
}
