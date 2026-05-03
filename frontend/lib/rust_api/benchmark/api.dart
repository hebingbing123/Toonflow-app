import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class BenchmarkCaseV1 {
  const BenchmarkCaseV1({
    required this.id,
    required this.projectId,
    required this.scriptId,
    required this.stage,
    required this.caseType,
    required this.issueTags,
    required this.weight,
    required this.summary,
    required this.lastVerifiedAt,
  });

  factory BenchmarkCaseV1.fromJson(Map<String, dynamic> json) {
    final rawTags = json['issueTags'];
    return BenchmarkCaseV1(
      id: json['id']?.toString() ?? '',
      projectId: (json['projectId'] as num?)?.toInt() ?? 0,
      scriptId: (json['scriptId'] as num?)?.toInt(),
      stage: json['stage']?.toString() ?? '',
      caseType: json['caseType']?.toString() ?? '',
      issueTags: rawTags is List
          ? rawTags.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      weight: (json['weight'] as num?)?.toInt() ?? 1,
      summary: json['summary']?.toString() ?? '',
      lastVerifiedAt: json['lastVerifiedAt']?.toString(),
    );
  }

  final String id;
  final int projectId;
  final int? scriptId;
  final String stage;
  final String caseType;
  final List<String> issueTags;
  final int weight;
  final String summary;
  final String? lastVerifiedAt;
}

class ExperimentRunV1 {
  const ExperimentRunV1({
    required this.id,
    required this.name,
    required this.status,
    required this.sampleTier,
    required this.stageScope,
    required this.baselineVariantId,
    required this.createdAt,
    required this.startedAt,
    required this.completedAt,
  });

  factory ExperimentRunV1.fromJson(Map<String, dynamic> json) {
    final rawScope = json['stageScope'];
    return ExperimentRunV1(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      sampleTier: json['sampleTier']?.toString() ?? '',
      stageScope: rawScope is List
          ? rawScope.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      baselineVariantId: json['baselineVariantId']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      startedAt: json['startedAt']?.toString(),
      completedAt: json['completedAt']?.toString(),
    );
  }

  final String id;
  final String name;
  final String status;
  final String sampleTier;
  final List<String> stageScope;
  final String? baselineVariantId;
  final String createdAt;
  final String? startedAt;
  final String? completedAt;
}

class ExperimentVariantV1 {
  const ExperimentVariantV1({
    required this.id,
    required this.label,
    required this.isBaseline,
    required this.skillSnapshot,
    required this.promptSnapshot,
    required this.memoryBudgetSnapshot,
    required this.observationPolicySnapshot,
    required this.modelRouteSnapshot,
    required this.notes,
  });

  factory ExperimentVariantV1.fromJson(Map<String, dynamic> json) {
    return ExperimentVariantV1(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      isBaseline: json['isBaseline'] == true,
      skillSnapshot: Map<String, dynamic>.from(
        (json['skillSnapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      promptSnapshot: Map<String, dynamic>.from(
        (json['promptSnapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      memoryBudgetSnapshot: Map<String, dynamic>.from(
        (json['memoryBudgetSnapshot'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
      observationPolicySnapshot: Map<String, dynamic>.from(
        (json['observationPolicySnapshot'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
      modelRouteSnapshot: Map<String, dynamic>.from(
        (json['modelRouteSnapshot'] as Map?)?.cast<String, dynamic>() ??
            const {},
      ),
      notes: json['notes']?.toString(),
    );
  }

  final String id;
  final String label;
  final bool isBaseline;
  final Map<String, dynamic> skillSnapshot;
  final Map<String, dynamic> promptSnapshot;
  final Map<String, dynamic> memoryBudgetSnapshot;
  final Map<String, dynamic> observationPolicySnapshot;
  final Map<String, dynamic> modelRouteSnapshot;
  final String? notes;
}

class ExperimentDetailV1 {
  const ExperimentDetailV1({required this.experiment, required this.variants});

  factory ExperimentDetailV1.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'];
    return ExperimentDetailV1(
      experiment: ExperimentRunV1.fromJson(
        Map<String, dynamic>.from(
          (json['experiment'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      ),
      variants: rawVariants is List
          ? rawVariants
                .whereType<Map>()
                .map(
                  (item) => ExperimentVariantV1.fromJson(
                    Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  ),
                )
                .toList(growable: false)
          : const <ExperimentVariantV1>[],
    );
  }

  final ExperimentRunV1 experiment;
  final List<ExperimentVariantV1> variants;
}

class ReviewQueueItemV1 {
  const ReviewQueueItemV1({
    required this.id,
    required this.experimentRunId,
    required this.experimentResultId,
    required this.reviewType,
    required this.status,
    required this.priority,
    required this.prompt,
    required this.submittedScore,
  });

  factory ReviewQueueItemV1.fromJson(Map<String, dynamic> json) {
    return ReviewQueueItemV1(
      id: json['id']?.toString() ?? '',
      experimentRunId: json['experimentRunId']?.toString(),
      experimentResultId: json['experimentResultId']?.toString(),
      reviewType: json['reviewType']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      prompt: json['prompt']?.toString() ?? '',
      submittedScore: json['submittedScore'] is Map
          ? Map<String, dynamic>.from(
              (json['submittedScore'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  final String id;
  final String? experimentRunId;
  final String? experimentResultId;
  final String reviewType;
  final String status;
  final int priority;
  final String prompt;
  final Map<String, dynamic>? submittedScore;
}

class MemoryProfileV1 {
  const MemoryProfileV1({
    required this.budgetTier,
    required this.profileVersion,
    required this.observationNoteLimit,
  });

  factory MemoryProfileV1.fromJson(Map<String, dynamic> json) {
    return MemoryProfileV1(
      budgetTier: json['budgetTier']?.toString() ?? '',
      profileVersion: json['profileVersion']?.toString(),
      observationNoteLimit: (json['observationNoteLimit'] as num?)?.toInt(),
    );
  }

  final String budgetTier;
  final String? profileVersion;
  final int? observationNoteLimit;
}

class MemoryProfilesResponseV1 {
  const MemoryProfilesResponseV1({required this.profiles, required this.total});

  factory MemoryProfilesResponseV1.fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'];
    return MemoryProfilesResponseV1(
      profiles: rawProfiles is List
          ? rawProfiles
                .whereType<Map>()
                .map(
                  (item) => MemoryProfileV1.fromJson(
                    Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  ),
                )
                .toList(growable: false)
          : const <MemoryProfileV1>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  final List<MemoryProfileV1> profiles;
  final int total;
}

class RoiVariantComparisonV1 {
  const RoiVariantComparisonV1({
    required this.variantId,
    required this.variantLabel,
    required this.isBaseline,
    required this.totalTokens,
    required this.tokenDeltaPercent,
    required this.avgQualityScore,
    required this.qualityScoreDelta,
    required this.badCaseRecurrenceDelta,
  });

  factory RoiVariantComparisonV1.fromJson(Map<String, dynamic> json) {
    final costDelta = Map<String, dynamic>.from(
      (json['costDelta'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final qualityMetrics = Map<String, dynamic>.from(
      (json['qualityMetrics'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return RoiVariantComparisonV1(
      variantId: json['variantId']?.toString() ?? '',
      variantLabel: json['variantLabel']?.toString() ?? '',
      isBaseline: json['isBaseline'] == true,
      totalTokens: (costDelta['totalTokens'] as num?)?.toInt() ?? 0,
      tokenDeltaPercent:
          (costDelta['tokenDeltaPercent'] as num?)?.toDouble() ?? 0,
      avgQualityScore:
          (qualityMetrics['avgQualityScore'] as num?)?.toDouble() ?? 0,
      qualityScoreDelta:
          (qualityMetrics['qualityScoreDelta'] as num?)?.toDouble() ?? 0,
      badCaseRecurrenceDelta:
          (qualityMetrics['badCaseRecurrenceDelta'] as num?)?.toInt() ?? 0,
    );
  }

  final String variantId;
  final String variantLabel;
  final bool isBaseline;
  final int totalTokens;
  final double tokenDeltaPercent;
  final double avgQualityScore;
  final double qualityScoreDelta;
  final int badCaseRecurrenceDelta;
}

class RoiEvidenceSummaryV1 {
  const RoiEvidenceSummaryV1({
    required this.experimentRunId,
    required this.variantComparisons,
    required this.overallConclusionType,
    required this.overallRationale,
  });

  factory RoiEvidenceSummaryV1.fromJson(Map<String, dynamic> json) {
    final rawComparisons = json['variantComparisons'];
    final conclusion = Map<String, dynamic>.from(
      (json['overallConclusion'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return RoiEvidenceSummaryV1(
      experimentRunId: json['experimentRunId']?.toString() ?? '',
      variantComparisons: rawComparisons is List
          ? rawComparisons
                .whereType<Map>()
                .map(
                  (item) => RoiVariantComparisonV1.fromJson(
                    Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  ),
                )
                .toList(growable: false)
          : const <RoiVariantComparisonV1>[],
      overallConclusionType:
          conclusion['conclusionType']?.toString() ?? 'insufficient_data',
      overallRationale: conclusion['rationale']?.toString() ?? '',
    );
  }

  final String experimentRunId;
  final List<RoiVariantComparisonV1> variantComparisons;
  final String overallConclusionType;
  final String overallRationale;
}

class GateAssessmentV1 {
  const GateAssessmentV1({
    required this.variantId,
    required this.variantLabel,
    required this.autoDecision,
    required this.avgQualityScore,
    required this.qualityScoreDelta,
    required this.totalTokens,
    required this.tokenDeltaPercent,
    required this.severeGuardFailures,
  });

  factory GateAssessmentV1.fromJson(Map<String, dynamic> json) {
    return GateAssessmentV1(
      variantId: json['variantId']?.toString() ?? '',
      variantLabel: json['variantLabel']?.toString() ?? '',
      autoDecision: json['autoDecision']?.toString() ?? '',
      avgQualityScore: (json['avgQualityScore'] as num?)?.toDouble() ?? 0,
      qualityScoreDelta: (json['qualityScoreDelta'] as num?)?.toDouble() ?? 0,
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      tokenDeltaPercent: (json['tokenDeltaPercent'] as num?)?.toDouble() ?? 0,
      severeGuardFailures: (json['severeGuardFailures'] as num?)?.toInt() ?? 0,
    );
  }

  final String variantId;
  final String variantLabel;
  final String autoDecision;
  final double avgQualityScore;
  final double qualityScoreDelta;
  final int totalTokens;
  final double tokenDeltaPercent;
  final int severeGuardFailures;
}

class GateDecisionRecordV1 {
  const GateDecisionRecordV1({
    required this.variantId,
    required this.decision,
    required this.decidedAt,
  });

  factory GateDecisionRecordV1.fromJson(Map<String, dynamic> json) {
    return GateDecisionRecordV1(
      variantId: json['variantId']?.toString() ?? '',
      decision: json['decision']?.toString() ?? '',
      decidedAt: json['decidedAt']?.toString() ?? '',
    );
  }

  final String variantId;
  final String decision;
  final String decidedAt;
}

class GateDecisionEnvelopeV1 {
  const GateDecisionEnvelopeV1({
    required this.experimentRunId,
    required this.assessments,
    required this.latestDecisions,
  });

  factory GateDecisionEnvelopeV1.fromJson(Map<String, dynamic> json) {
    final rawAssessments = json['assessments'];
    final rawDecisions = json['latestDecisions'];
    return GateDecisionEnvelopeV1(
      experimentRunId: json['experimentRunId']?.toString() ?? '',
      assessments: rawAssessments is List
          ? rawAssessments
                .whereType<Map>()
                .map(
                  (item) => GateAssessmentV1.fromJson(
                    Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  ),
                )
                .toList(growable: false)
          : const <GateAssessmentV1>[],
      latestDecisions: rawDecisions is List
          ? rawDecisions
                .whereType<Map>()
                .map(
                  (item) => GateDecisionRecordV1.fromJson(
                    Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  ),
                )
                .toList(growable: false)
          : const <GateDecisionRecordV1>[],
    );
  }

  final String experimentRunId;
  final List<GateAssessmentV1> assessments;
  final List<GateDecisionRecordV1> latestDecisions;
}

class BenchmarkTrendPointV1 {
  const BenchmarkTrendPointV1({
    required this.weekStart,
    required this.completedResults,
    required this.avgQualityScore,
    required this.totalTokens,
    required this.badCaseFailures,
    required this.approvedCount,
    required this.blockedCount,
  });

  factory BenchmarkTrendPointV1.fromJson(Map<String, dynamic> json) {
    return BenchmarkTrendPointV1(
      weekStart: json['weekStart']?.toString() ?? '',
      completedResults: (json['completedResults'] as num?)?.toInt() ?? 0,
      avgQualityScore: (json['avgQualityScore'] as num?)?.toDouble() ?? 0,
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      badCaseFailures: (json['badCaseFailures'] as num?)?.toInt() ?? 0,
      approvedCount: (json['approvedCount'] as num?)?.toInt() ?? 0,
      blockedCount: (json['blockedCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String weekStart;
  final int completedResults;
  final double avgQualityScore;
  final int totalTokens;
  final int badCaseFailures;
  final int approvedCount;
  final int blockedCount;
}

class BenchmarkTrendsResponseV1 {
  const BenchmarkTrendsResponseV1({required this.weeks});

  factory BenchmarkTrendsResponseV1.fromJson(Map<String, dynamic> json) {
    final rawWeeks = json['weeks'];
    return BenchmarkTrendsResponseV1(
      weeks: rawWeeks is List
          ? rawWeeks
                .whereType<Map>()
                .map(
                  (item) => BenchmarkTrendPointV1.fromJson(
                    Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  ),
                )
                .toList(growable: false)
          : const <BenchmarkTrendPointV1>[],
    );
  }

  final List<BenchmarkTrendPointV1> weeks;
}

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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 201 && res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'submittedScore': submittedScore}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return BenchmarkTrendsResponseV1.fromJson(Map<String, dynamic>.from(decoded));
}
