import '../content_compliance/controller.dart';
import '../l10n/rust_api_error_format.dart';

ContentComplianceQueueResponseV1 buildDemoContentComplianceQueue() {
  final l10n = rustApiLookupL10nFromPlatform();
  final projectName = l10n.demoStudioProjectDisplayName;
  return ContentComplianceQueueResponseV1.fromJson(<String, dynamic>{
    'summary': <String, dynamic>{
      'pending': 1,
      'claimed': 0,
      'resolved': 2,
      'dismissed': 0,
      'critical': 1,
      'high': 0,
    },
    'sla': <String, dynamic>{
      'openOver24h': 0,
      'openOver72h': 0,
      'claimedOver24h': 0,
      'unclaimedCritical': 1,
      'oldestOpenAgeHours': 6,
    },
    'capacity': <String, dynamic>{
      'reviewerCapacityLimit': 12,
      'overloadedReviewerCount': 0,
      'overloadedClaimedCount': 0,
    },
    'alerts': <dynamic>[
      <String, dynamic>{
        'level': 'critical',
        'stage': 'critical_unclaimed',
        'count': 1,
        'title': l10n.demoComplianceAlertCriticalTitle,
        'message': l10n.demoComplianceAlertCriticalMessage,
      },
    ],
    'workspaceSummaries': <dynamic>[],
    'ownerSummaries': <dynamic>[],
    'escalationSummaries': <dynamic>[],
    'items': <dynamic>[
      <String, dynamic>{
        'id': 'demo-compliance-1',
        'reporterUserId': 'demo-reporter',
        'reporterEmail': 'reviewer@demo.openflow',
        'targetType': 'project',
        'targetId': '00000000-0000-0000-0000-000000000007',
        'workspaceId': 'workspace-demo',
        'workspaceName': l10n.demoWorkspaceDisplayName,
        'projectId': '00000000-0000-0000-0000-000000000007',
        'projectName': projectName,
        'category': 'safety',
        'severity': 'critical',
        'status': 'pending',
        'escalationStage': 'critical_unclaimed',
        'detail': l10n.demoComplianceReportDetail,
        'claimedByLabel': null,
        'claimedAt': null,
        'resolutionLabel': null,
        'resolutionNote': null,
        'resolvedAt': null,
        'createdAt': '2026-05-10T00:00:00Z',
      },
    ],
  });
}
