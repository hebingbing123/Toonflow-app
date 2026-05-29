import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

part 'api/types.dart';

Future<List<BenchmarkCaseV1>> fetchBenchmarkCases(
  String accessToken, {
  int? projectId,
  String? stage,
  String? caseType,
}) async {
  final query = <String, String>{};
  if (projectId != null) query['projectId'] = '$projectId';
  if (stage != null && stage.isNotEmpty) query['stage'] = stage;
  if (caseType != null && caseType.isNotEmpty) query['caseType'] = caseType;
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/cases',
  ).replace(queryParameters: query.isEmpty ? null : query);
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! List) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return decoded
      .whereType<Map>()
      .map((item) => BenchmarkCaseV1.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Future<BenchmarkCaseV1> promoteBenchmarkCaseFromReview(
  String accessToken, {
  required String qualityReviewId,
  required String caseType,
  required String summary,
  List<String>? issueTags,
  int? weight,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/cases/promote-from-review',
  );
  final body = <String, dynamic>{
    'qualityReviewId': qualityReviewId,
    'caseType': caseType,
    'summary': summary,
  };
  if (issueTags != null && issueTags.isNotEmpty) body['issueTags'] = issueTags;
  if (weight != null) body['weight'] = weight;
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 201 && res.statusCode != 200) {
    throw RustApiException.fromHttpResponse(res);
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return BenchmarkCaseV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<List<ExperimentRunV1>> fetchBenchmarkExperiments(
  String accessToken, {
  String? status,
  String? sampleTier,
}) async {
  final query = <String, String>{};
  if (status != null && status.isNotEmpty) query['status'] = status;
  if (sampleTier != null && sampleTier.isNotEmpty) {
    query['sampleTier'] = sampleTier;
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/experiments',
  ).replace(queryParameters: query.isEmpty ? null : query);
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! List) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return decoded
      .whereType<Map>()
      .map((item) => ExperimentRunV1.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Future<ExperimentDetailV1> fetchBenchmarkExperimentDetail(
  String accessToken,
  String experimentId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/experiments/$experimentId',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ExperimentDetailV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<ExperimentDetailV1> createBenchmarkExperiment(
  String accessToken, {
  required String name,
  required String sampleTier,
  required List<String> stageScope,
  required List<Map<String, dynamic>> variants,
  String? baselineVariantLabel,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/benchmark/experiments');
  final body = <String, dynamic>{
    'name': name,
    'sampleTier': sampleTier,
    'stageScope': stageScope,
    'variants': variants,
  };
  if (baselineVariantLabel != null && baselineVariantLabel.isNotEmpty) {
    body['baselineVariantLabel'] = baselineVariantLabel;
  }
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 60));
  ensureHttpStatus(res, 201);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ExperimentDetailV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<ExperimentDetailV1> startBenchmarkExperiment(
  String accessToken,
  String experimentId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/experiments/$experimentId/start',
  );
  final res = await http
      .post(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ExperimentDetailV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<ExperimentDetailV1> cancelBenchmarkExperiment(
  String accessToken,
  String experimentId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/experiments/$experimentId/cancel',
  );
  final res = await http
      .post(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ExperimentDetailV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<List<ReviewQueueItemV1>> fetchBenchmarkReviewQueue(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/benchmark/review-queue');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! List) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return decoded
      .whereType<Map>()
      .map(
        (item) => ReviewQueueItemV1.fromJson(Map<String, dynamic>.from(item)),
      )
      .toList(growable: false);
}

Future<ReviewQueueItemV1> submitBenchmarkReview(
  String accessToken, {
  required String reviewQueueId,
  required Map<String, dynamic> submittedScore,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/review-queue/$reviewQueueId/submit',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'submittedScore': submittedScore}),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ReviewQueueItemV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<ReviewQueueItemV1> skipBenchmarkReview(
  String accessToken, {
  required String reviewQueueId,
  String? reason,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/review-queue/$reviewQueueId/skip',
  );
  final body = <String, dynamic>{};
  if (reason != null && reason.trim().isNotEmpty) {
    body['reason'] = reason.trim();
  }
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ReviewQueueItemV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<MemoryProfilesResponseV1> fetchBenchmarkMemoryProfiles(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/benchmark/memory-profiles');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return MemoryProfilesResponseV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<RoiEvidenceSummaryV1> fetchBenchmarkExperimentRoi(
  String accessToken,
  String experimentId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/experiments/$experimentId/roi',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return RoiEvidenceSummaryV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<GateDecisionEnvelopeV1> fetchBenchmarkGate(
  String accessToken,
  String experimentId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/experiments/$experimentId/gate',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return GateDecisionEnvelopeV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<GateDecisionRecordV1> submitBenchmarkGateDecision(
  String accessToken, {
  required String experimentId,
  required String variantId,
  String? decision,
  String? rationaleNote,
  String? promotionRestrictions,
  bool promoteToBaseline = false,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/experiments/$experimentId/gate/decide',
  );
  final body = <String, dynamic>{'variantId': variantId};
  if (decision != null && decision.isNotEmpty) body['decision'] = decision;
  if (rationaleNote != null && rationaleNote.isNotEmpty) {
    body['rationaleNote'] = rationaleNote;
  }
  if (promotionRestrictions != null && promotionRestrictions.isNotEmpty) {
    body['promotionRestrictions'] = promotionRestrictions;
  }
  if (promoteToBaseline) body['promoteToBaseline'] = true;
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return GateDecisionRecordV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<BenchmarkTrendsResponseV1> fetchBenchmarkTrends(
  String accessToken, {
  int limitWeeks = 8,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/benchmark/trends',
  ).replace(queryParameters: {'limitWeeks': '$limitWeeks'});
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return BenchmarkTrendsResponseV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<ABCompareResponseV1> compareBenchmarkABJobs(
  String accessToken, {
  bool persist = false,
  String? name,
  required List<ABCompareCaseV1> cases,
  ABCompareConfigV1? config,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/benchmark/ab/compare');
  final body = <String, dynamic>{
    'cases': cases.map((e) => e.toJson()).toList(growable: false),
    if (config != null) 'config': config.toJson(),
    if (persist) 'persist': true,
    if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
  };
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 60));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ABCompareResponseV1.fromJson(Map<String, dynamic>.from(decoded));
}

Future<List<ABCompareRunRowV1>> fetchBenchmarkABCompareRuns(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/benchmark/ab/runs');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! List) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return decoded
      .whereType<Map>()
      .map((item) => ABCompareRunRowV1.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Future<ABCompareRunDetailV1> fetchBenchmarkABCompareRunDetail(
  String accessToken,
  String runId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/benchmark/ab/runs/$runId');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return ABCompareRunDetailV1.fromJson(Map<String, dynamic>.from(decoded));
}
