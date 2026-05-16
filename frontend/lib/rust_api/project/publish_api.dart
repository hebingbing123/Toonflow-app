// All API functions for publish
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'publish_models.dart';

/// `GET …/publish/overview` — aggregated publish slice. See `getPublishOverviewV1`.
Future<PublishOverviewResponse> fetchPublishOverview(
  String accessToken,
  String projectId, {
  String? draftId,
  int auditLimit = 30,
}) async {
  final qp = <String, String>{};
  if (draftId != null && draftId.trim().isNotEmpty) {
    qp['draft_id'] = draftId.trim();
  }
  qp['audit_limit'] = '$auditLimit';
  final base = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/overview',
  );
  final uri = qp.isEmpty ? base : base.replace(queryParameters: qp);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishOverviewResponse.fromJson(map);
}

/// `GET …/publish/platform-matrix`
Future<PublishPlatformMatrixResponse> fetchPublishPlatformMatrix(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/platform-matrix',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishPlatformMatrixResponse.fromJson(map);
}

/// `GET …/publish/drafts`
///
/// Optional [scheduledFrom] / [scheduledTo] (RFC3339): both required when filtering;
/// returns only drafts with non-null `scheduled_at` in `[from, to)`.
Future<List<PublishDraftRow>> fetchPublishDrafts(
  String accessToken,
  String projectId, {
  String? scheduledFrom,
  String? scheduledTo,
}) async {
  final qp = <String, String>{};
  if (scheduledFrom != null) {
    qp['scheduled_from'] = scheduledFrom;
  }
  if (scheduledTo != null) {
    qp['scheduled_to'] = scheduledTo;
  }
  final base = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts',
  );
  final uri = qp.isEmpty ? base : base.replace(queryParameters: qp);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PublishDraftRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET …/publish/drafts/{draft_id}/prepare-check`
Future<PublishPrepareCheckResponse> fetchPublishPrepareCheck(
  String accessToken,
  String projectId,
  String draftId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId/prepare-check',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishPrepareCheckResponse.fromJson(map);
}

/// `POST …/publish/drafts`
Future<PublishDraftRow> createPublishDraft(
  String accessToken,
  String projectId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishDraftRow.fromJson(map);
}

/// `GET …/publish/drafts/{draft_id}`
Future<PublishDraftRow> fetchPublishDraft(
  String accessToken,
  String projectId,
  String draftId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishDraftRow.fromJson(map);
}

/// `PATCH …/publish/drafts/{draft_id}` — body keys snake_case，省略字段不修改。
Future<PublishDraftRow> patchPublishDraft(
  String accessToken,
  String projectId,
  String draftId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId',
  );
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishDraftRow.fromJson(map);
}

/// `POST …/publish/drafts/{draft_id}/targets`
Future<List<PublishTargetRow>> upsertPublishTargets(
  String accessToken,
  String projectId,
  String draftId,
  List<Map<String, dynamic>> targets,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId/targets',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'targets': targets}),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PublishTargetRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET …/publish/jobs`
Future<List<PublishJobRow>> fetchPublishJobs(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/publish/jobs');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PublishJobRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET …/publish/audit`
Future<List<PublishAttemptAuditRow>> fetchPublishAudit(
  String accessToken,
  String projectId, {
  String? draftId,
  String? jobId,
  int limit = 50,
}) async {
  final qp = <String, String>{'limit': '$limit'};
  if (draftId != null && draftId.trim().isNotEmpty) {
    qp['draft_id'] = draftId.trim();
  }
  if (jobId != null && jobId.trim().isNotEmpty) {
    qp['job_id'] = jobId.trim();
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/audit',
  ).replace(queryParameters: qp);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PublishAttemptAuditRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET …/publish/performance-alerts`
Future<List<PublishPerformanceAlertRow>> fetchPublishPerformanceAlerts(
  String accessToken,
  String projectId, {
  int viewsLt = 1000,
  double completionRateLt = 0.45,
  int limit = 50,
}) async {
  final uri =
      Uri.parse(
        '$kApiBaseUrl/api/v1/projects/$projectId/publish/performance-alerts',
      ).replace(
        queryParameters: <String, String>{
          'views_lt': viewsLt.toString(),
          'completion_rate_lt': completionRateLt.toString(),
          'limit': limit.toString(),
        },
      );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map(
        (e) => PublishPerformanceAlertRow.fromJson(e as Map<String, dynamic>),
      )
      .toList(growable: false);
}

/// `POST …/publish/drafts/{draft_id}/jobs`
Future<PublishJobRow> createPublishJob(
  String accessToken,
  String projectId,
  String draftId, {
  Map<String, dynamic> payload = const <String, dynamic>{},
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId/jobs',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'payload': payload}),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishJobRow.fromJson(map);
}

/// `POST …/publish/jobs/{job_id}/confirm-semi-auto`
Future<PublishJobRow> confirmSemiAutoPublishJob(
  String accessToken,
  String projectId,
  String jobId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/jobs/$jobId/confirm-semi-auto',
  );
  final res = await http
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishJobRow.fromJson(map);
}

/// `POST …/publish/jobs/{job_id}/retry`
Future<void> retryPublishJob(
  String accessToken,
  String projectId,
  String jobId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/jobs/$jobId/retry',
  );
  final res = await http
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 25));
  ensureHttpStatus(res, 204);
}

/// `POST …/publish/validate-copy`
Future<PublishValidateCopyResponse> validatePublishCopy(
  String accessToken,
  String projectId, {
  required Map<String, dynamic> platformCopy,
  required List<Map<String, dynamic>> targets,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/validate-copy',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'platform_copy': platformCopy,
          'targets': targets,
        }),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishValidateCopyResponse.fromJson(map);
}

/// `POST …/publish/drafts/{draft_id}/suggest-platform-copy`
Future<SuggestPlatformCopyResponse> suggestPublishPlatformCopy(
  String accessToken,
  String projectId,
  String draftId, {
  bool apply = true,
  String? styleHint,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId/suggest-platform-copy',
  );
  final payload = <String, dynamic>{'apply': apply};
  if (styleHint != null) {
    payload['style_hint'] = styleHint;
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      )
      .timeout(const Duration(seconds: 60));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SuggestPlatformCopyResponse.fromJson(map);
}

/// `POST …/publish/drafts/batch-schedule`
Future<BatchSchedulePublishDraftsResponse> batchSchedulePublishDrafts(
  String accessToken,
  String projectId, {
  required List<String> draftIds,
  String? scheduledAtIso,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/batch-schedule',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'draft_ids': draftIds,
          'scheduled_at': scheduledAtIso,
        }),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchSchedulePublishDraftsResponse.fromJson(map);
}

Future<PublishBatchValidationResponse> batchValidatePublishDrafts(
  String accessToken,
  String projectId, {
  required List<String> draftIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/batch-validate',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'draft_ids': draftIds}),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishBatchValidationResponse.fromJson(map);
}

/// `POST …/publish/drafts/batch-publish`
Future<PublishBatchPublishResponse> batchPublishDrafts(
  String accessToken,
  String projectId, {
  required List<String> draftIds,
  bool immediate = true,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/batch-publish',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'draft_ids': draftIds,
          'immediate': immediate,
        }),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishBatchPublishResponse.fromJson(map);
}

/// `POST …/publish/drafts/batch-archive`
Future<PublishBatchArchiveResponse> batchArchivePublishDrafts(
  String accessToken,
  String projectId, {
  required List<String> draftIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/batch-archive',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'draft_ids': draftIds}),
      )
      .timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishBatchArchiveResponse.fromJson(map);
}
