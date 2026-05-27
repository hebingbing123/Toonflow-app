import '../content_compliance/controller.dart';

ContentComplianceQueueResponseV1 buildDemoContentComplianceQueue() {
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
        'title': '有未认领的严重举报',
        'message': '演示：优先处理待认领队列中的安全类举报。',
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
        'workspaceName': '演示工作区',
        'projectId': '00000000-0000-0000-0000-000000000007',
        'projectName': '春季短剧 · 演示',
        'category': 'safety',
        'severity': 'critical',
        'status': 'pending',
        'escalationStage': 'critical_unclaimed',
        'detail': '演示举报：示例安全类内容需人工复核。',
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
