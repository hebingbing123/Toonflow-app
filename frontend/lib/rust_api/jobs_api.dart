part of 'index.dart';

/// `GET /api/v1/jobs` — jobs for the caller, newest first (default [limit] 100). See `listJobsV1`.
///
/// [kind] and [status] are optional exact-match query filters (non-empty only).
/// [limit] must be 1–100 when set; [offset] must be >= 0 when set.
Future<List<JobRow>> fetchJobs(
  String accessToken, {
  String? kind,
  String? status,
  int? limit,
  int? offset,
}) async {
  final qp = <String, String>{};
  if (kind != null && kind.trim().isNotEmpty) {
    qp['kind'] = kind.trim();
  }
  if (status != null && status.trim().isNotEmpty) {
    qp['status'] = status.trim();
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  if (offset != null) {
    qp['offset'] = '$offset';
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/jobs',
  ).replace(queryParameters: qp.isEmpty ? null : qp);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list.map((e) => JobRow.fromJson(e as Map<String, dynamic>)).toList();
}

/// `GET /api/v1/jobs/kinds` — distinct kinds for the caller. See `listJobKindsV1`.
Future<List<String>> fetchJobKinds(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/kinds');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list.map((e) => e as String).toList();
}

class JobKindSummary {
  const JobKindSummary({required this.kind, required this.jobCount});

  final String kind;
  final int jobCount;

  factory JobKindSummary.fromJson(Map<String, dynamic> json) {
    return JobKindSummary(
      kind: json['kind'] as String,
      jobCount: (json['job_count'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/jobs/kinds/summary` — per-kind counts. See `listJobKindSummariesV1`.
Future<List<JobKindSummary>> fetchJobKindSummaries(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/kinds/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => JobKindSummary.fromJson(e as Map<String, dynamic>))
      .toList();
}

class JobStatusSummary {
  const JobStatusSummary({required this.status, required this.jobCount});

  final String status;
  final int jobCount;

  factory JobStatusSummary.fromJson(Map<String, dynamic> json) {
    return JobStatusSummary(
      status: json['status'] as String,
      jobCount: (json['job_count'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/jobs/status/summary` — per-status counts. See `listJobStatusSummariesV1`.
Future<List<JobStatusSummary>> fetchJobStatusSummaries(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/status/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => JobStatusSummary.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/jobs/{id}` — job must belong to the caller. See `getJobV1`.
Future<JobRow> fetchJob(String accessToken, String jobId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/$jobId');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// `POST /api/v1/jobs` — queues a generation job.
///
/// [idempotencyKey]: sent as HTTP header `Idempotency-Key` (server trims and keeps up to
/// 200 characters). Same authenticated user + same key replays return the **existing**
/// job row (HTTP 200), no duplicate insert. See OpenAPI `createJobV1`.
Future<JobRow> createJob(
  String accessToken,
  String kind, {
  Map<String, dynamic> payload = const {},
  String? idempotencyKey,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs');
  final headers = <String, String>{
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };
  if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
    headers['Idempotency-Key'] = idempotencyKey;
  }
  final res = await http
      .post(
        uri,
        headers: headers,
        body: jsonEncode({'kind': kind, 'payload': payload}),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// `POST /api/v1/jobs/{id}/cancel` — `queued` or `running` only. See `cancelJobV1`.
Future<JobRow> cancelJob(String accessToken, String jobId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/$jobId/cancel');
  final res = await http
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 409) {
    throw RustApiException(res.body, statusCode: 409);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// `POST /api/v1/jobs/{id}/retry` — `failed` jobs re-queued. See `retryJobV1`.
Future<JobRow> retryJob(String accessToken, String jobId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/$jobId/retry');
  final res = await http
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 409) {
    throw RustApiException(res.body, statusCode: 409);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}
