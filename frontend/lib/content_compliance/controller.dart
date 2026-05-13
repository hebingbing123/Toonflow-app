import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import '../platform/rust_api_feedback.dart';
import '../rust_api/core.dart';
import '../rust_api/settings/notifications.dart';

typedef ContentComplianceAccessTokenProvider = String? Function();
typedef ContentComplianceErrorSink = void Function(String? error);
typedef ContentComplianceL10nProvider = AppLocalizations? Function();
typedef ContentComplianceAlertsSink =
    void Function(List<ContentComplianceQueueAlertV1> alerts);

class ContentComplianceReportItemV1 {
  const ContentComplianceReportItemV1({
    required this.id,
    required this.reporterUserId,
    required this.reporterEmail,
    required this.targetType,
    required this.targetId,
    required this.workspaceId,
    required this.workspaceName,
    required this.projectId,
    required this.projectName,
    required this.category,
    required this.severity,
    required this.status,
    required this.escalationStage,
    required this.detail,
    required this.claimedByLabel,
    required this.claimedAt,
    required this.resolutionLabel,
    required this.resolutionNote,
    required this.resolvedAt,
    required this.createdAt,
  });

  final String id;
  final String reporterUserId;
  final String? reporterEmail;
  final String targetType;
  final String targetId;
  final String? workspaceId;
  final String? workspaceName;
  final String? projectId;
  final String? projectName;
  final String category;
  final String severity;
  final String status;
  final String escalationStage;
  final String? detail;
  final String? claimedByLabel;
  final String? claimedAt;
  final String? resolutionLabel;
  final String? resolutionNote;
  final String? resolvedAt;
  final String createdAt;

  factory ContentComplianceReportItemV1.fromJson(Map<String, dynamic> json) {
    return ContentComplianceReportItemV1(
      id: json['id'] as String? ?? '',
      reporterUserId: json['reporterUserId'] as String? ?? '',
      reporterEmail: json['reporterEmail'] as String?,
      targetType: json['targetType'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      workspaceId: json['workspaceId'] as String?,
      workspaceName: json['workspaceName'] as String?,
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String?,
      category: json['category'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      status: json['status'] as String? ?? '',
      escalationStage: json['escalationStage'] as String? ?? 'watch',
      detail: json['detail'] as String?,
      claimedByLabel: json['claimedByLabel'] as String?,
      claimedAt: json['claimedAt'] as String?,
      resolutionLabel: json['resolutionLabel'] as String?,
      resolutionNote: json['resolutionNote'] as String?,
      resolvedAt: json['resolvedAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class ContentComplianceQueueSummaryV1 {
  const ContentComplianceQueueSummaryV1({
    required this.pending,
    required this.claimed,
    required this.resolved,
    required this.dismissed,
    required this.critical,
    required this.high,
  });

  final int pending;
  final int claimed;
  final int resolved;
  final int dismissed;
  final int critical;
  final int high;

  factory ContentComplianceQueueSummaryV1.fromJson(Map<String, dynamic> json) {
    return ContentComplianceQueueSummaryV1(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      claimed: (json['claimed'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
      dismissed: (json['dismissed'] as num?)?.toInt() ?? 0,
      critical: (json['critical'] as num?)?.toInt() ?? 0,
      high: (json['high'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceQueueSlaSummaryV1 {
  const ContentComplianceQueueSlaSummaryV1({
    required this.openOver24h,
    required this.openOver72h,
    required this.claimedOver24h,
    required this.unclaimedCritical,
    required this.oldestOpenAgeHours,
  });

  final int openOver24h;
  final int openOver72h;
  final int claimedOver24h;
  final int unclaimedCritical;
  final int oldestOpenAgeHours;

  factory ContentComplianceQueueSlaSummaryV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceQueueSlaSummaryV1(
      openOver24h: (json['openOver24h'] as num?)?.toInt() ?? 0,
      openOver72h: (json['openOver72h'] as num?)?.toInt() ?? 0,
      claimedOver24h: (json['claimedOver24h'] as num?)?.toInt() ?? 0,
      unclaimedCritical: (json['unclaimedCritical'] as num?)?.toInt() ?? 0,
      oldestOpenAgeHours: (json['oldestOpenAgeHours'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceWorkspaceSummaryV1 {
  const ContentComplianceWorkspaceSummaryV1({
    required this.workspaceId,
    required this.workspaceName,
    required this.openCount,
    required this.pendingCount,
    required this.claimedCount,
    required this.criticalOpenCount,
    required this.highOpenCount,
    required this.slaBreachedCount,
    required this.oldestOpenAgeHours,
  });

  final String? workspaceId;
  final String? workspaceName;
  final int openCount;
  final int pendingCount;
  final int claimedCount;
  final int criticalOpenCount;
  final int highOpenCount;
  final int slaBreachedCount;
  final int oldestOpenAgeHours;

  factory ContentComplianceWorkspaceSummaryV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceWorkspaceSummaryV1(
      workspaceId: json['workspaceId'] as String?,
      workspaceName: json['workspaceName'] as String?,
      openCount: (json['openCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      claimedCount: (json['claimedCount'] as num?)?.toInt() ?? 0,
      criticalOpenCount: (json['criticalOpenCount'] as num?)?.toInt() ?? 0,
      highOpenCount: (json['highOpenCount'] as num?)?.toInt() ?? 0,
      slaBreachedCount: (json['slaBreachedCount'] as num?)?.toInt() ?? 0,
      oldestOpenAgeHours: (json['oldestOpenAgeHours'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceOwnerSummaryV1 {
  const ContentComplianceOwnerSummaryV1({
    required this.ownerLabel,
    required this.pendingCount,
    required this.claimedCount,
    required this.criticalOpenCount,
    required this.overdueCount,
    required this.oldestOpenAgeHours,
    required this.overCapacity,
    required this.overCapacityBy,
  });

  final String ownerLabel;
  final int pendingCount;
  final int claimedCount;
  final int criticalOpenCount;
  final int overdueCount;
  final int oldestOpenAgeHours;
  final bool overCapacity;
  final int overCapacityBy;

  factory ContentComplianceOwnerSummaryV1.fromJson(Map<String, dynamic> json) {
    return ContentComplianceOwnerSummaryV1(
      ownerLabel: json['ownerLabel'] as String? ?? 'unclaimed',
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      claimedCount: (json['claimedCount'] as num?)?.toInt() ?? 0,
      criticalOpenCount: (json['criticalOpenCount'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
      oldestOpenAgeHours: (json['oldestOpenAgeHours'] as num?)?.toInt() ?? 0,
      overCapacity: json['overCapacity'] as bool? ?? false,
      overCapacityBy: (json['overCapacityBy'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceQueueCapacitySummaryV1 {
  const ContentComplianceQueueCapacitySummaryV1({
    required this.reviewerCapacityLimit,
    required this.overloadedReviewerCount,
    required this.overloadedClaimedCount,
  });

  final int reviewerCapacityLimit;
  final int overloadedReviewerCount;
  final int overloadedClaimedCount;

  factory ContentComplianceQueueCapacitySummaryV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceQueueCapacitySummaryV1(
      reviewerCapacityLimit:
          (json['reviewerCapacityLimit'] as num?)?.toInt() ?? 12,
      overloadedReviewerCount:
          (json['overloadedReviewerCount'] as num?)?.toInt() ?? 0,
      overloadedClaimedCount:
          (json['overloadedClaimedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceEscalationSummaryV1 {
  const ContentComplianceEscalationSummaryV1({
    required this.escalationStage,
    required this.reportCount,
  });

  final String escalationStage;
  final int reportCount;

  factory ContentComplianceEscalationSummaryV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceEscalationSummaryV1(
      escalationStage: json['escalationStage'] as String? ?? 'watch',
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceQueueResponseV1 {
  const ContentComplianceQueueResponseV1({
    required this.summary,
    required this.sla,
    required this.capacity,
    required this.alerts,
    required this.workspaceSummaries,
    required this.ownerSummaries,
    required this.escalationSummaries,
    required this.items,
  });

  final ContentComplianceQueueSummaryV1 summary;
  final ContentComplianceQueueSlaSummaryV1 sla;
  final ContentComplianceQueueCapacitySummaryV1 capacity;
  final List<ContentComplianceQueueAlertV1> alerts;
  final List<ContentComplianceWorkspaceSummaryV1> workspaceSummaries;
  final List<ContentComplianceOwnerSummaryV1> ownerSummaries;
  final List<ContentComplianceEscalationSummaryV1> escalationSummaries;
  final List<ContentComplianceReportItemV1> items;

  factory ContentComplianceQueueResponseV1.fromJson(Map<String, dynamic> json) {
    return ContentComplianceQueueResponseV1(
      summary: ContentComplianceQueueSummaryV1.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      ),
      sla: ContentComplianceQueueSlaSummaryV1.fromJson(
        Map<String, dynamic>.from(json['sla'] as Map? ?? const {}),
      ),
      capacity: ContentComplianceQueueCapacitySummaryV1.fromJson(
        Map<String, dynamic>.from(json['capacity'] as Map? ?? const {}),
      ),
      alerts: (json['alerts'] as List? ?? const [])
          .map(
            (item) => ContentComplianceQueueAlertV1.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      workspaceSummaries: (json['workspaceSummaries'] as List? ?? const [])
          .map(
            (item) => ContentComplianceWorkspaceSummaryV1.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      ownerSummaries: (json['ownerSummaries'] as List? ?? const [])
          .map(
            (item) => ContentComplianceOwnerSummaryV1.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      escalationSummaries: (json['escalationSummaries'] as List? ?? const [])
          .map(
            (item) => ContentComplianceEscalationSummaryV1.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      items: (json['items'] as List? ?? const [])
          .map(
            (item) => ContentComplianceReportItemV1.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ContentComplianceQueueAlertV1 {
  const ContentComplianceQueueAlertV1({
    required this.level,
    required this.stage,
    required this.count,
    required this.title,
    required this.message,
  });

  final String level;
  final String stage;
  final int count;
  final String title;
  final String message;

  factory ContentComplianceQueueAlertV1.fromJson(Map<String, dynamic> json) {
    return ContentComplianceQueueAlertV1(
      level: json['level'] as String? ?? 'medium',
      stage: json['stage'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class ContentComplianceAuditItemV1 {
  const ContentComplianceAuditItemV1({
    required this.id,
    required this.reportId,
    required this.actorUserId,
    required this.actorLabel,
    required this.action,
    required this.fromStatus,
    required this.toStatus,
    required this.disposition,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String reportId;
  final String? actorUserId;
  final String actorLabel;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? disposition;
  final Map<String, dynamic> details;
  final String createdAt;

  factory ContentComplianceAuditItemV1.fromJson(Map<String, dynamic> json) {
    return ContentComplianceAuditItemV1(
      id: json['id'] as String? ?? '',
      reportId: json['reportId'] as String? ?? '',
      actorUserId: json['actorUserId'] as String?,
      actorLabel: json['actorLabel'] as String? ?? '',
      action: json['action'] as String? ?? '',
      fromStatus: json['fromStatus'] as String?,
      toStatus: json['toStatus'] as String?,
      disposition: json['disposition'] as String?,
      details: Map<String, dynamic>.from(
        json['details'] as Map? ?? const <String, dynamic>{},
      ),
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class ContentComplianceBatchMutateResponseV1 {
  const ContentComplianceBatchMutateResponseV1({
    required this.requestedCount,
    required this.succeededCount,
    required this.failedCount,
  });

  final int requestedCount;
  final int succeededCount;
  final int failedCount;

  factory ContentComplianceBatchMutateResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceBatchMutateResponseV1(
      requestedCount: (json['requestedCount'] as num?)?.toInt() ?? 0,
      succeededCount: (json['succeededCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceReassignResponseV1 {
  const ContentComplianceReassignResponseV1({
    required this.requestedCount,
    required this.succeededCount,
    required this.failedCount,
    required this.assigneeLabel,
  });

  final int requestedCount;
  final int succeededCount;
  final int failedCount;
  final String assigneeLabel;

  factory ContentComplianceReassignResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceReassignResponseV1(
      requestedCount: (json['requestedCount'] as num?)?.toInt() ?? 0,
      succeededCount: (json['succeededCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      assigneeLabel: json['assigneeLabel'] as String? ?? '',
    );
  }
}

class ContentComplianceAutoRebalanceResponseV1 {
  const ContentComplianceAutoRebalanceResponseV1({
    required this.dryRun,
    required this.reviewerCapacityLimit,
    required this.plannedMoveCount,
    required this.executedMoveCount,
  });

  final bool dryRun;
  final int reviewerCapacityLimit;
  final int plannedMoveCount;
  final int executedMoveCount;

  factory ContentComplianceAutoRebalanceResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceAutoRebalanceResponseV1(
      dryRun: json['dryRun'] as bool? ?? false,
      reviewerCapacityLimit:
          (json['reviewerCapacityLimit'] as num?)?.toInt() ?? 12,
      plannedMoveCount: (json['plannedMoveCount'] as num?)?.toInt() ?? 0,
      executedMoveCount: (json['executedMoveCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContentComplianceController extends ChangeNotifier {
  ContentComplianceController({
    required ContentComplianceAccessTokenProvider accessTokenProvider,
    required ContentComplianceErrorSink onErrorChanged,
    ContentComplianceAlertsSink? onAlertsChanged,
    ContentComplianceL10nProvider? l10nProvider,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _onAlertsChanged = onAlertsChanged,
       _l10nProvider = l10nProvider;

  final ContentComplianceAccessTokenProvider _accessTokenProvider;
  final ContentComplianceErrorSink _onErrorChanged;
  final ContentComplianceAlertsSink? _onAlertsChanged;
  final ContentComplianceL10nProvider? _l10nProvider;

  AppLocalizations? get _l10n => _l10nProvider?.call();

  bool submittingReport = false;
  bool loadingQueue = false;
  bool mutatingQueue = false;
  String? loadingAuditReportId;
  ContentComplianceQueueResponseV1? queue;
  String? queueStatusFilter;
  String? queueCategoryFilter;
  String? queueTargetTypeFilter;
  String? queueWorkspaceIdFilter;
  String? queueWorkspaceNameFilter;
  String? queueClaimedByLabelFilter;
  String? queueSlaBucketFilter;
  String? queueEscalationStageFilter;
  bool queueClaimedOnly = false;

  /// When non-null, overrides [kInternalOpsToken] non-empty check (widget tests).
  bool? queueEnabledOverride;

  /// When true, [ContentComplianceSection] will not call [loadQueue] on mount.
  bool skipAutoLoadQueueOnMount = false;

  bool get queueEnabled =>
      queueEnabledOverride ?? kInternalOpsToken.trim().isNotEmpty;

  void _setError(String? value) => _onErrorChanged(value);

  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String category,
    required String severity,
    String? detail,
  }) async {
    final token = _accessTokenProvider()?.trim();
    if (token == null || token.isEmpty || submittingReport) {
      return;
    }
    submittingReport = true;
    _setError(null);
    notifyListeners();
    try {
      final res = await http
          .post(
            Uri.parse('$kApiBaseUrl/api/v1/content/reports'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'targetType': targetType,
              'targetId': targetId.trim(),
              'category': category,
              'severity': severity,
              if ((detail ?? '').trim().isNotEmpty) 'detail': detail!.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      ensureHttpSuccess(res);
      if (queueEnabled) {
        await loadQueue();
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError(
        describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error),
      );
    } finally {
      submittingReport = false;
      notifyListeners();
    }
  }

  Future<void> loadQueue({
    String? status,
    String? category,
    String? targetType,
    String? workspaceId,
    String? workspaceName,
    String? claimedByLabel,
    String? slaBucket,
    String? escalationStage,
    bool? claimedOnly,
  }) async {
    if (!queueEnabled || loadingQueue) {
      return;
    }
    queueStatusFilter = _normalizeQueueFilter(status) ?? queueStatusFilter;
    queueCategoryFilter =
        _normalizeQueueFilter(category) ?? queueCategoryFilter;
    queueTargetTypeFilter =
        _normalizeQueueFilter(targetType) ?? queueTargetTypeFilter;
    queueWorkspaceIdFilter =
        _normalizeQueueFilter(workspaceId) ?? queueWorkspaceIdFilter;
    queueWorkspaceNameFilter =
        _normalizeQueueFilter(workspaceName) ?? queueWorkspaceNameFilter;
    queueClaimedByLabelFilter =
        _normalizeQueueFilter(claimedByLabel) ?? queueClaimedByLabelFilter;
    queueSlaBucketFilter =
        _normalizeQueueFilter(slaBucket) ?? queueSlaBucketFilter;
    queueEscalationStageFilter =
        _normalizeQueueFilter(escalationStage) ?? queueEscalationStageFilter;
    queueClaimedOnly = claimedOnly ?? queueClaimedOnly;
    loadingQueue = true;
    _setError(null);
    notifyListeners();
    try {
      final uri = Uri.parse('$kApiBaseUrl/api/v1/internal/compliance/reports')
          .replace(
            queryParameters: <String, String>{
              if ((queueStatusFilter ?? '').isNotEmpty)
                'status': queueStatusFilter!,
              if ((queueCategoryFilter ?? '').isNotEmpty)
                'category': queueCategoryFilter!,
              if ((queueTargetTypeFilter ?? '').isNotEmpty)
                'targetType': queueTargetTypeFilter!,
              if ((queueWorkspaceIdFilter ?? '').isNotEmpty)
                'workspaceId': queueWorkspaceIdFilter!,
              if ((queueClaimedByLabelFilter ?? '').isNotEmpty)
                'claimedByLabel': queueClaimedByLabelFilter!,
              if ((queueSlaBucketFilter ?? '').isNotEmpty)
                'slaBucket': queueSlaBucketFilter!,
              if ((queueEscalationStageFilter ?? '').isNotEmpty)
                'escalationStage': queueEscalationStageFilter!,
              if (queueClaimedOnly) 'claimedOnly': 'true',
            },
          );
      final res = await http
          .get(
            uri,
            headers: {'x-toonflow-internal-token': kInternalOpsToken.trim()},
          )
          .timeout(const Duration(seconds: 15));
      ensureHttpSuccess(res);
      queue = ContentComplianceQueueResponseV1.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      _onAlertsChanged?.call(
        queue?.alerts ?? const <ContentComplianceQueueAlertV1>[],
      );
      final accessToken = _accessTokenProvider()?.trim();
      if (accessToken != null && accessToken.isNotEmpty && queue != null) {
        await syncContentComplianceAlertsV1(
          accessToken,
          queue!.alerts
              .map(
                (alert) => SyncContentComplianceAlertItemV1(
                  stage: alert.stage,
                  level: alert.level,
                  count: alert.count,
                  title: alert.title,
                  message: alert.message,
                  linkPath:
                      '/product/content-compliance?escalationStage=${alert.stage}',
                ),
              )
              .toList(growable: false),
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError(
        describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error),
      );
    } finally {
      loadingQueue = false;
      notifyListeners();
    }
  }

  Future<void> claimReport(
    String id, {
    String actorLabel = 'internal_ops',
  }) async {
    await _mutateQueue(
      '$kApiBaseUrl/api/v1/internal/compliance/reports/$id/claim',
      <String, dynamic>{'actorLabel': actorLabel},
    );
  }

  Future<void> resolveReport(
    String id, {
    required String status,
    String actorLabel = 'internal_ops',
    String? resolutionNote,
    String disposition = 'none',
  }) async {
    await _mutateQueue(
      '$kApiBaseUrl/api/v1/internal/compliance/reports/$id/resolve',
      <String, dynamic>{
        'status': status,
        'actorLabel': actorLabel,
        'disposition': disposition,
        if ((resolutionNote ?? '').trim().isNotEmpty)
          'resolutionNote': resolutionNote!.trim(),
      },
    );
  }

  Future<void> _mutateQueue(String url, Map<String, dynamic> body) async {
    if (!queueEnabled || mutatingQueue) {
      return;
    }
    mutatingQueue = true;
    _setError(null);
    notifyListeners();
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: {
              'x-toonflow-internal-token': kInternalOpsToken.trim(),
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      ensureHttpSuccess(res);
      await loadQueue();
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError(
        describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error),
      );
    } finally {
      mutatingQueue = false;
      notifyListeners();
    }
  }

  Future<void> applyQueueFilters({
    String? status,
    String? category,
    String? targetType,
    String? workspaceId,
    String? workspaceName,
    String? claimedByLabel,
    String? slaBucket,
    String? escalationStage,
    required bool claimedOnly,
  }) async {
    queueStatusFilter = _normalizeQueueFilter(status);
    queueCategoryFilter = _normalizeQueueFilter(category);
    queueTargetTypeFilter = _normalizeQueueFilter(targetType);
    queueWorkspaceIdFilter = _normalizeQueueFilter(workspaceId);
    queueWorkspaceNameFilter = _normalizeQueueFilter(workspaceName);
    queueClaimedByLabelFilter = _normalizeQueueFilter(claimedByLabel);
    queueSlaBucketFilter = _normalizeQueueFilter(slaBucket);
    queueEscalationStageFilter = _normalizeQueueFilter(escalationStage);
    queueClaimedOnly = claimedOnly;
    notifyListeners();
    await loadQueue(
      status: queueStatusFilter,
      category: queueCategoryFilter,
      targetType: queueTargetTypeFilter,
      workspaceId: queueWorkspaceIdFilter,
      workspaceName: queueWorkspaceNameFilter,
      claimedByLabel: queueClaimedByLabelFilter,
      slaBucket: queueSlaBucketFilter,
      escalationStage: queueEscalationStageFilter,
      claimedOnly: queueClaimedOnly,
    );
  }

  Future<void> clearQueueFilters() async {
    queueStatusFilter = null;
    queueCategoryFilter = null;
    queueTargetTypeFilter = null;
    queueWorkspaceIdFilter = null;
    queueWorkspaceNameFilter = null;
    queueClaimedByLabelFilter = null;
    queueSlaBucketFilter = null;
    queueEscalationStageFilter = null;
    queueClaimedOnly = false;
    notifyListeners();
    await loadQueue(
      status: '',
      category: '',
      targetType: '',
      workspaceId: '',
      workspaceName: '',
      claimedByLabel: '',
      slaBucket: '',
      escalationStage: '',
      claimedOnly: false,
    );
  }

  Future<ContentComplianceBatchMutateResponseV1?> batchMutateReports({
    required List<String> reportIds,
    required String action,
    String actorLabel = 'internal_ops',
    String? resolutionNote,
    String disposition = 'none',
  }) async {
    if (!queueEnabled || mutatingQueue || reportIds.isEmpty) {
      return null;
    }
    mutatingQueue = true;
    _setError(null);
    notifyListeners();
    try {
      final res = await http
          .post(
            Uri.parse(
              '$kApiBaseUrl/api/v1/internal/compliance/reports/batch-mutate',
            ),
            headers: {
              'x-toonflow-internal-token': kInternalOpsToken.trim(),
              'content-type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'reportIds': reportIds,
              'action': action,
              'actorLabel': actorLabel,
              'disposition': disposition,
              if ((resolutionNote ?? '').trim().isNotEmpty)
                'resolutionNote': resolutionNote!.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      ensureHttpSuccess(res);
      final response = ContentComplianceBatchMutateResponseV1.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      await loadQueue();
      return response;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
      return null;
    } catch (error) {
      _setError(
        describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error),
      );
      return null;
    } finally {
      mutatingQueue = false;
      notifyListeners();
    }
  }

  Future<ContentComplianceReassignResponseV1?> reassignReports({
    required List<String> reportIds,
    required String assigneeLabel,
    String actorLabel = 'internal_ops',
    String? note,
  }) async {
    if (!queueEnabled || mutatingQueue || reportIds.isEmpty) {
      return null;
    }
    final trimmedAssignee = assigneeLabel.trim();
    if (trimmedAssignee.isEmpty) {
      _setError(
        _l10n?.contentComplianceErrAssigneeRequired ??
            'Assignee reviewer cannot be empty.',
      );
      notifyListeners();
      return null;
    }
    mutatingQueue = true;
    _setError(null);
    notifyListeners();
    try {
      final res = await http
          .post(
            Uri.parse(
              '$kApiBaseUrl/api/v1/internal/compliance/reports/reassign',
            ),
            headers: {
              'x-toonflow-internal-token': kInternalOpsToken.trim(),
              'content-type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'reportIds': reportIds,
              'assigneeLabel': trimmedAssignee,
              'actorLabel': actorLabel,
              if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      ensureHttpSuccess(res);
      final response = ContentComplianceReassignResponseV1.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      await loadQueue();
      return response;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
      return null;
    } catch (error) {
      _setError(
        describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error),
      );
      return null;
    } finally {
      mutatingQueue = false;
      notifyListeners();
    }
  }

  Future<ContentComplianceAutoRebalanceResponseV1?> autoRebalanceReports({
    bool dryRun = false,
    String actorLabel = 'internal_ops',
    String? note,
    int maxMoves = 100,
  }) async {
    if (!queueEnabled || mutatingQueue) {
      return null;
    }
    mutatingQueue = true;
    _setError(null);
    notifyListeners();
    try {
      final res = await http
          .post(
            Uri.parse(
              '$kApiBaseUrl/api/v1/internal/compliance/reports/auto-rebalance',
            ),
            headers: {
              'x-toonflow-internal-token': kInternalOpsToken.trim(),
              'content-type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'dryRun': dryRun,
              'actorLabel': actorLabel,
              'maxMoves': maxMoves.clamp(1, 500),
              if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      ensureHttpSuccess(res);
      final response = ContentComplianceAutoRebalanceResponseV1.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      await loadQueue();
      return response;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
      return null;
    } catch (error) {
      _setError(
        describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error),
      );
      return null;
    } finally {
      mutatingQueue = false;
      notifyListeners();
    }
  }

  String? _normalizeQueueFilter(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty || value == 'all') {
      return null;
    }
    return value;
  }

  Future<List<ContentComplianceAuditItemV1>> fetchReportAudit(
    String reportId, {
    int limit = 30,
  }) async {
    if (!queueEnabled) {
      return const <ContentComplianceAuditItemV1>[];
    }
    loadingAuditReportId = reportId;
    _setError(null);
    notifyListeners();
    try {
      final uri = Uri.parse(
        '$kApiBaseUrl/api/v1/internal/compliance/reports/$reportId/audit?limit=$limit',
      );
      final res = await http
          .get(
            uri,
            headers: {'x-toonflow-internal-token': kInternalOpsToken.trim()},
          )
          .timeout(const Duration(seconds: 15));
      ensureHttpSuccess(res);
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map(
            (item) => ContentComplianceAuditItemV1.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
      return const <ContentComplianceAuditItemV1>[];
    } catch (error) {
      _setError(
        describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error),
      );
      return const <ContentComplianceAuditItemV1>[];
    } finally {
      loadingAuditReportId = null;
      notifyListeners();
    }
  }
}
