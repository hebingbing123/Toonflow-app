import 'package:openflow_app/content_compliance/controller.dart';
import 'package:openflow_app/rust_api.dart';

ContentComplianceQueueResponseV1 buildContentComplianceQueueWithAlert(
  String stage,
) {
  return ContentComplianceQueueResponseV1.fromJson(<String, dynamic>{
    'summary': <String, dynamic>{
      'pending': 0,
      'claimed': 0,
      'resolved': 0,
      'dismissed': 0,
      'critical': 0,
      'high': 0,
    },
    'sla': <String, dynamic>{
      'openOver24h': 0,
      'openOver72h': 0,
      'claimedOver24h': 0,
      'unclaimedCritical': 0,
      'oldestOpenAgeHours': 0,
    },
    'capacity': <String, dynamic>{
      'reviewerCapacityLimit': 12,
      'overloadedReviewerCount': 1,
      'overloadedClaimedCount': 2,
    },
    'alerts': <dynamic>[
      <String, dynamic>{
        'level': stage == 'critical_unclaimed' ? 'critical' : 'high',
        'stage': stage,
        'count': 2,
        'title': '测试提醒',
        'message': '测试提醒正文',
      },
    ],
    'workspaceSummaries': <dynamic>[],
    'ownerSummaries': <dynamic>[],
    'escalationSummaries': <dynamic>[],
    'items': <dynamic>[
      <String, dynamic>{
        'id': 'f2a0f70a-3ef3-44f1-9dbe-947eb41976c1',
        'reporterUserId': 'd4011e94-6042-4f7a-b35d-02268389f815',
        'reporterEmail': 'reporter@example.com',
        'targetType': 'project',
        'targetId': '8d4d0366-843f-4e4e-a5b6-a6602a2950cb',
        'workspaceId': null,
        'workspaceName': null,
        'projectId': null,
        'projectName': null,
        'category': 'safety',
        'severity': stage == 'critical_unclaimed' ? 'critical' : 'high',
        'status': stage == 'critical_unclaimed' ? 'pending' : 'claimed',
        'escalationStage': stage,
        'detail': 'test',
        'claimedByLabel': stage == 'critical_unclaimed' ? null : 'reviewer_a',
        'claimedAt': null,
        'resolutionLabel': null,
        'resolutionNote': null,
        'resolvedAt': null,
        'createdAt': '2026-05-10T00:00:00Z',
      },
    ],
  });
}

ContentComplianceController buildDesktopGalleryContentComplianceController() {
  return ContentComplianceController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
    )
    ..queueEnabledOverride = true
    ..skipAutoLoadQueueOnMount = true
    ..queue = buildContentComplianceQueueWithAlert('critical_unclaimed');
}
