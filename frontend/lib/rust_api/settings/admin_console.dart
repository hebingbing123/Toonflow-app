import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

Map<String, String> _internalHeaders(String token) => <String, String>{
  'x-toonflow-internal-token': token.trim(),
};

class AdminSearchResponseV1 {
  const AdminSearchResponseV1({
    required this.query,
    required this.users,
    required this.workspaces,
    required this.projects,
    required this.jobs,
  });

  final String query;
  final List<AdminUserSearchHitV1> users;
  final List<AdminWorkspaceSearchHitV1> workspaces;
  final List<AdminProjectSearchHitV1> projects;
  final List<AdminJobSummaryV1> jobs;

  factory AdminSearchResponseV1.fromJson(Map<String, dynamic> json) {
    return AdminSearchResponseV1(
      query: json['query'] as String? ?? '',
      users: _listOf(
        json['users'],
        (item) => AdminUserSearchHitV1.fromJson(item),
      ),
      workspaces: _listOf(
        json['workspaces'],
        (item) => AdminWorkspaceSearchHitV1.fromJson(item),
      ),
      projects: _listOf(
        json['projects'],
        (item) => AdminProjectSearchHitV1.fromJson(item),
      ),
      jobs: _listOf(json['jobs'], (item) => AdminJobSummaryV1.fromJson(item)),
    );
  }
}

class AdminUserSearchHitV1 {
  const AdminUserSearchHitV1({
    required this.userId,
    required this.email,
    required this.planTier,
    required this.operationalStatus,
    required this.currentWorkspaceId,
    required this.workspaceCount,
    required this.projectCount,
    required this.activeJobCount,
  });

  final String userId;
  final String? email;
  final String? planTier;
  final String operationalStatus;
  final String? currentWorkspaceId;
  final int workspaceCount;
  final int projectCount;
  final int activeJobCount;

  factory AdminUserSearchHitV1.fromJson(Map<String, dynamic> json) {
    return AdminUserSearchHitV1(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String?,
      planTier: json['planTier'] as String?,
      operationalStatus: json['operationalStatus'] as String? ?? 'active',
      currentWorkspaceId: json['currentWorkspaceId'] as String?,
      workspaceCount: (json['workspaceCount'] as num?)?.toInt() ?? 0,
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      activeJobCount: (json['activeJobCount'] as num?)?.toInt() ?? 0,
    );
  }
}

enum AdminOperationalStatusV1 { active, suspended }

enum AdminQuotaOverrideActionV1 { preserve, clear, set }

enum AdminWorkspaceLifecycleActionV1 { preserve, archive, restore }

enum AdminWorkspaceOpsNoteActionV1 { preserve, set, clear }

enum AdminUserWorkspaceContextActionV1 { resetToPersonal, setToWorkspace }

class AdminWorkspaceSearchHitV1 {
  const AdminWorkspaceSearchHitV1({
    required this.workspaceId,
    required this.name,
    required this.workspaceType,
    required this.archivedAt,
    required this.ownerUserId,
    required this.ownerEmail,
    required this.memberCount,
    required this.projectCount,
    required this.activeJobCount,
  });

  final String workspaceId;
  final String name;
  final String workspaceType;
  final String? archivedAt;
  final String ownerUserId;
  final String? ownerEmail;
  final int memberCount;
  final int projectCount;
  final int activeJobCount;

  factory AdminWorkspaceSearchHitV1.fromJson(Map<String, dynamic> json) {
    return AdminWorkspaceSearchHitV1(
      workspaceId: json['workspaceId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      workspaceType: json['workspaceType'] as String? ?? '',
      archivedAt: json['archivedAt'] as String?,
      ownerUserId: json['ownerUserId'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      activeJobCount: (json['activeJobCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProjectSearchHitV1 {
  const AdminProjectSearchHitV1({
    required this.projectId,
    required this.numericId,
    required this.name,
    required this.workspaceId,
    required this.workspaceName,
    required this.ownerUserId,
    required this.ownerEmail,
    required this.updatedAt,
  });

  final String projectId;
  final int numericId;
  final String? name;
  final String? workspaceId;
  final String? workspaceName;
  final String ownerUserId;
  final String? ownerEmail;
  final String? updatedAt;

  factory AdminProjectSearchHitV1.fromJson(Map<String, dynamic> json) {
    return AdminProjectSearchHitV1(
      projectId: json['projectId'] as String? ?? '',
      numericId: (json['numericId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      workspaceId: json['workspaceId'] as String?,
      workspaceName: json['workspaceName'] as String?,
      ownerUserId: json['ownerUserId'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class AdminJobSummaryV1 {
  const AdminJobSummaryV1({
    required this.jobId,
    required this.ownerUserId,
    required this.ownerEmail,
    required this.kind,
    required this.status,
    required this.projectId,
    required this.projectNumericId,
    required this.createdAt,
  });

  final String jobId;
  final String ownerUserId;
  final String? ownerEmail;
  final String kind;
  final String status;
  final String? projectId;
  final int? projectNumericId;
  final String createdAt;

  factory AdminJobSummaryV1.fromJson(Map<String, dynamic> json) {
    return AdminJobSummaryV1(
      jobId: json['jobId'] as String? ?? '',
      ownerUserId: json['ownerUserId'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String?,
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? '',
      projectId: json['projectId'] as String?,
      projectNumericId: (json['projectNumericId'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AdminWorkspaceRefV1 {
  const AdminWorkspaceRefV1({
    required this.workspaceId,
    required this.name,
    required this.workspaceType,
    required this.archivedAt,
  });

  final String workspaceId;
  final String name;
  final String workspaceType;
  final String? archivedAt;

  factory AdminWorkspaceRefV1.fromJson(Map<String, dynamic> json) {
    return AdminWorkspaceRefV1(
      workspaceId: json['workspaceId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      workspaceType: json['workspaceType'] as String? ?? '',
      archivedAt: json['archivedAt'] as String?,
    );
  }
}

class AdminUserMembershipSummaryV1 {
  const AdminUserMembershipSummaryV1({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceType,
    required this.role,
    required this.archivedAt,
  });

  final String workspaceId;
  final String workspaceName;
  final String workspaceType;
  final String role;
  final String? archivedAt;

  factory AdminUserMembershipSummaryV1.fromJson(Map<String, dynamic> json) {
    return AdminUserMembershipSummaryV1(
      workspaceId: json['workspaceId'] as String? ?? '',
      workspaceName: json['workspaceName'] as String? ?? '',
      workspaceType: json['workspaceType'] as String? ?? '',
      role: json['role'] as String? ?? '',
      archivedAt: json['archivedAt'] as String?,
    );
  }
}

class AdminWorkspaceMemberSummaryV1 {
  const AdminWorkspaceMemberSummaryV1({
    required this.userId,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String userId;
  final String? email;
  final String role;
  final String createdAt;

  factory AdminWorkspaceMemberSummaryV1.fromJson(Map<String, dynamic> json) {
    return AdminWorkspaceMemberSummaryV1(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AdminProjectSummaryV1 {
  const AdminProjectSummaryV1({
    required this.projectId,
    required this.numericId,
    required this.name,
    required this.ownerUserId,
    required this.ownerEmail,
    required this.updatedAt,
  });

  final String projectId;
  final int numericId;
  final String? name;
  final String ownerUserId;
  final String? ownerEmail;
  final String? updatedAt;

  factory AdminProjectSummaryV1.fromJson(Map<String, dynamic> json) {
    return AdminProjectSummaryV1(
      projectId: json['projectId'] as String? ?? '',
      numericId: (json['numericId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      ownerUserId: json['ownerUserId'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class AdminUserDetailResponseV1 {
  const AdminUserDetailResponseV1({
    required this.userId,
    required this.email,
    required this.createdAt,
    required this.planTier,
    required this.operationalStatus,
    required this.operationalStatusReason,
    required this.opsNote,
    required this.dailyJobQuotaOverride,
    required this.billingProvider,
    required this.subscriptionStatus,
    required this.currentWorkspace,
    required this.workspaceCount,
    required this.projectCount,
    required this.activeJobCount,
    required this.apiKeyCount,
    required this.unreadNotificationCount,
    required this.memberships,
    required this.recentJobs,
    required this.governanceAudit,
  });

  final String userId;
  final String? email;
  final String createdAt;
  final String planTier;
  final String operationalStatus;
  final String? operationalStatusReason;
  final String? opsNote;
  final int? dailyJobQuotaOverride;
  final String? billingProvider;
  final String? subscriptionStatus;
  final AdminWorkspaceRefV1? currentWorkspace;
  final int workspaceCount;
  final int projectCount;
  final int activeJobCount;
  final int apiKeyCount;
  final int unreadNotificationCount;
  final List<AdminUserMembershipSummaryV1> memberships;
  final List<AdminJobSummaryV1> recentJobs;
  final List<AdminUserGovernanceAuditSummaryV1> governanceAudit;

  factory AdminUserDetailResponseV1.fromJson(Map<String, dynamic> json) {
    return AdminUserDetailResponseV1(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      planTier: json['planTier'] as String? ?? 'free',
      operationalStatus: json['operationalStatus'] as String? ?? 'active',
      operationalStatusReason: json['operationalStatusReason'] as String?,
      opsNote: json['opsNote'] as String?,
      dailyJobQuotaOverride: (json['dailyJobQuotaOverride'] as num?)?.toInt(),
      billingProvider: json['billingProvider'] as String?,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      currentWorkspace: json['currentWorkspace'] is Map
          ? AdminWorkspaceRefV1.fromJson(
              Map<String, dynamic>.from(json['currentWorkspace'] as Map),
            )
          : null,
      workspaceCount: (json['workspaceCount'] as num?)?.toInt() ?? 0,
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      activeJobCount: (json['activeJobCount'] as num?)?.toInt() ?? 0,
      apiKeyCount: (json['apiKeyCount'] as num?)?.toInt() ?? 0,
      unreadNotificationCount:
          (json['unreadNotificationCount'] as num?)?.toInt() ?? 0,
      memberships: _listOf(
        json['memberships'],
        (item) => AdminUserMembershipSummaryV1.fromJson(item),
      ),
      recentJobs: _listOf(
        json['recentJobs'],
        (item) => AdminJobSummaryV1.fromJson(item),
      ),
      governanceAudit: _listOf(
        json['governanceAudit'],
        (item) => AdminUserGovernanceAuditSummaryV1.fromJson(item),
      ),
    );
  }
}

class AdminUserGovernanceAuditSummaryV1 {
  const AdminUserGovernanceAuditSummaryV1({
    required this.auditId,
    required this.actorLabel,
    required this.createdAt,
    required this.previousState,
    required this.nextState,
  });

  final String auditId;
  final String actorLabel;
  final String createdAt;
  final Map<String, dynamic> previousState;
  final Map<String, dynamic> nextState;

  factory AdminUserGovernanceAuditSummaryV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminUserGovernanceAuditSummaryV1(
      auditId: json['auditId'] as String? ?? '',
      actorLabel: json['actorLabel'] as String? ?? 'internal_ops',
      createdAt: json['createdAt'] as String? ?? '',
      previousState: Map<String, dynamic>.from(
        json['previousState'] as Map? ?? const {},
      ),
      nextState: Map<String, dynamic>.from(
        json['nextState'] as Map? ?? const {},
      ),
    );
  }
}

class AdminWorkspaceGovernanceAuditSummaryV1 {
  const AdminWorkspaceGovernanceAuditSummaryV1({
    required this.auditId,
    required this.actorLabel,
    required this.createdAt,
    required this.previousState,
    required this.nextState,
  });

  final String auditId;
  final String actorLabel;
  final String createdAt;
  final Map<String, dynamic> previousState;
  final Map<String, dynamic> nextState;

  factory AdminWorkspaceGovernanceAuditSummaryV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminWorkspaceGovernanceAuditSummaryV1(
      auditId: json['auditId'] as String? ?? '',
      actorLabel: json['actorLabel'] as String? ?? 'internal_ops',
      createdAt: json['createdAt'] as String? ?? '',
      previousState: Map<String, dynamic>.from(
        json['previousState'] as Map? ?? const {},
      ),
      nextState: Map<String, dynamic>.from(
        json['nextState'] as Map? ?? const {},
      ),
    );
  }
}

class AdminWorkspaceDetailResponseV1 {
  const AdminWorkspaceDetailResponseV1({
    required this.workspaceId,
    required this.name,
    required this.workspaceType,
    required this.ownerUserId,
    required this.ownerEmail,
    required this.archivedAt,
    required this.opsNote,
    required this.memberCount,
    required this.projectCount,
    required this.activeJobCount,
    required this.members,
    required this.recentProjects,
    required this.recentJobs,
    required this.governanceAudit,
  });

  final String workspaceId;
  final String name;
  final String workspaceType;
  final String ownerUserId;
  final String? ownerEmail;
  final String? archivedAt;
  final String? opsNote;
  final int memberCount;
  final int projectCount;
  final int activeJobCount;
  final List<AdminWorkspaceMemberSummaryV1> members;
  final List<AdminProjectSummaryV1> recentProjects;
  final List<AdminJobSummaryV1> recentJobs;
  final List<AdminWorkspaceGovernanceAuditSummaryV1> governanceAudit;

  factory AdminWorkspaceDetailResponseV1.fromJson(Map<String, dynamic> json) {
    return AdminWorkspaceDetailResponseV1(
      workspaceId: json['workspaceId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      workspaceType: json['workspaceType'] as String? ?? '',
      ownerUserId: json['ownerUserId'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String?,
      archivedAt: json['archivedAt'] as String?,
      opsNote: json['opsNote'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      activeJobCount: (json['activeJobCount'] as num?)?.toInt() ?? 0,
      members: _listOf(
        json['members'],
        (item) => AdminWorkspaceMemberSummaryV1.fromJson(item),
      ),
      recentProjects: _listOf(
        json['recentProjects'],
        (item) => AdminProjectSummaryV1.fromJson(item),
      ),
      recentJobs: _listOf(
        json['recentJobs'],
        (item) => AdminJobSummaryV1.fromJson(item),
      ),
      governanceAudit: _listOf(
        json['governanceAudit'],
        (item) => AdminWorkspaceGovernanceAuditSummaryV1.fromJson(item),
      ),
    );
  }
}

class AdminProjectDetailResponseV1 {
  const AdminProjectDetailResponseV1({
    required this.projectId,
    required this.numericId,
    required this.name,
    required this.ownerUserId,
    required this.ownerEmail,
    required this.workspace,
    required this.createdAt,
    required this.updatedAt,
    required this.scriptCount,
    required this.assetCount,
    required this.jobCount,
    required this.activeJobCount,
    required this.recentJobs,
  });

  final String projectId;
  final int numericId;
  final String? name;
  final String ownerUserId;
  final String? ownerEmail;
  final AdminWorkspaceRefV1? workspace;
  final String? createdAt;
  final String? updatedAt;
  final int scriptCount;
  final int assetCount;
  final int jobCount;
  final int activeJobCount;
  final List<AdminJobSummaryV1> recentJobs;

  factory AdminProjectDetailResponseV1.fromJson(Map<String, dynamic> json) {
    return AdminProjectDetailResponseV1(
      projectId: json['projectId'] as String? ?? '',
      numericId: (json['numericId'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      ownerUserId: json['ownerUserId'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String?,
      workspace: json['workspace'] is Map
          ? AdminWorkspaceRefV1.fromJson(
              Map<String, dynamic>.from(json['workspace'] as Map),
            )
          : null,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      scriptCount: (json['scriptCount'] as num?)?.toInt() ?? 0,
      assetCount: (json['assetCount'] as num?)?.toInt() ?? 0,
      jobCount: (json['jobCount'] as num?)?.toInt() ?? 0,
      activeJobCount: (json['activeJobCount'] as num?)?.toInt() ?? 0,
      recentJobs: _listOf(
        json['recentJobs'],
        (item) => AdminJobSummaryV1.fromJson(item),
      ),
    );
  }
}

List<T> _listOf<T>(Object? raw, T Function(Map<String, dynamic> item) decode) {
  return (raw as List? ?? const [])
      .map((item) => decode(Map<String, dynamic>.from(item as Map)))
      .toList(growable: false);
}

Future<AdminSearchResponseV1> fetchAdminSearchV1(
  String internalOpsToken, {
  required String query,
  int limit = 8,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/internal/admin/search?q=${Uri.encodeQueryComponent(query)}&limit=$limit',
  );
  final res = await http
      .get(uri, headers: _internalHeaders(internalOpsToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return AdminSearchResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminUserDetailResponseV1> fetchAdminUserDetailV1(
  String internalOpsToken, {
  required String userId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/internal/admin/users/$userId');
  final res = await http
      .get(uri, headers: _internalHeaders(internalOpsToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return AdminUserDetailResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminWorkspaceDetailResponseV1> fetchAdminWorkspaceDetailV1(
  String internalOpsToken, {
  required String workspaceId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/internal/admin/workspaces/$workspaceId',
  );
  final res = await http
      .get(uri, headers: _internalHeaders(internalOpsToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return AdminWorkspaceDetailResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminProjectDetailResponseV1> fetchAdminProjectDetailV1(
  String internalOpsToken, {
  required String projectId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/internal/admin/projects/$projectId',
  );
  final res = await http
      .get(uri, headers: _internalHeaders(internalOpsToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return AdminProjectDetailResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminUserDetailResponseV1> updateAdminUserGovernanceV1(
  String internalOpsToken, {
  required String userId,
  required AdminOperationalStatusV1 operationalStatus,
  String? operationalStatusReason,
  String? opsNote,
  AdminQuotaOverrideActionV1 dailyJobQuotaAction =
      AdminQuotaOverrideActionV1.preserve,
  int? dailyJobQuota,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/internal/admin/users/$userId/governance',
  );
  final body = <String, dynamic>{
    'operationalStatus': switch (operationalStatus) {
      AdminOperationalStatusV1.active => 'active',
      AdminOperationalStatusV1.suspended => 'suspended',
    },
    'dailyJobQuotaAction': switch (dailyJobQuotaAction) {
      AdminQuotaOverrideActionV1.preserve => 'preserve',
      AdminQuotaOverrideActionV1.clear => 'clear',
      AdminQuotaOverrideActionV1.set => 'set',
    },
  };
  if (operationalStatusReason != null) {
    body['operationalStatusReason'] = operationalStatusReason;
  }
  if (opsNote != null) {
    body['opsNote'] = opsNote;
  }
  if (dailyJobQuota != null) {
    body['dailyJobQuota'] = dailyJobQuota;
  }
  final res = await http
      .post(
        uri,
        headers: {
          ..._internalHeaders(internalOpsToken),
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return AdminUserDetailResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminUserDetailResponseV1> updateAdminUserWorkspaceContextV1(
  String internalOpsToken, {
  required String userId,
  required AdminUserWorkspaceContextActionV1 action,
  String? workspaceId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/internal/admin/users/$userId/workspace-context',
  );
  final body = <String, dynamic>{
    'action': switch (action) {
      AdminUserWorkspaceContextActionV1.resetToPersonal => 'reset_to_personal',
      AdminUserWorkspaceContextActionV1.setToWorkspace => 'set_to_workspace',
    },
  };
  if (workspaceId != null) {
    body['workspaceId'] = workspaceId;
  }
  final res = await http
      .post(
        uri,
        headers: {
          ..._internalHeaders(internalOpsToken),
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return AdminUserDetailResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AdminWorkspaceDetailResponseV1> updateAdminWorkspaceGovernanceV1(
  String internalOpsToken, {
  required String workspaceId,
  required AdminWorkspaceLifecycleActionV1 workspaceLifecycle,
  required AdminWorkspaceOpsNoteActionV1 opsNoteAction,
  String? opsNote,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/internal/admin/workspaces/$workspaceId/governance',
  );
  final body = <String, dynamic>{
    'workspaceLifecycle': switch (workspaceLifecycle) {
      AdminWorkspaceLifecycleActionV1.preserve => 'preserve',
      AdminWorkspaceLifecycleActionV1.archive => 'archive',
      AdminWorkspaceLifecycleActionV1.restore => 'restore',
    },
    'opsNoteAction': switch (opsNoteAction) {
      AdminWorkspaceOpsNoteActionV1.preserve => 'preserve',
      AdminWorkspaceOpsNoteActionV1.set => 'set',
      AdminWorkspaceOpsNoteActionV1.clear => 'clear',
    },
  };
  if (opsNote != null) {
    body['opsNote'] = opsNote;
  }
  final res = await http
      .post(
        uri,
        headers: {
          ..._internalHeaders(internalOpsToken),
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return AdminWorkspaceDetailResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
