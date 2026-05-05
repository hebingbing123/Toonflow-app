import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import 'tracks.dart';

/// OpenAPI **`GenerateVideoPromptResponse`**.
class GenerateVideoPromptDiagnostics {
  const GenerateVideoPromptDiagnostics({
    required this.promptChars,
    required this.negativePromptChars,
    required this.negativeConstraintCount,
    this.negativeCandidateFragmentCount = 0,
    this.negativeSavedFragmentCount = 0,
    this.negativeSavedChars = 0,
    required this.negativeBudgetTier,
    required this.autoNegativeSource,
    required this.autoNegativeReviewFragmentCount,
    required this.autoNegativeMemoryFragmentCount,
    required this.observationNoteChars,
    required this.roleAnchorCount,
    required this.sceneAnchorCount,
    required this.toolAnchorCount,
    required this.styleAnchorCount,
    required this.memoryStyleAnchorCount,
    required this.memoryDeliveryAnchorCount,
    required this.memoryDeliveryPriorityApplied,
    required this.memoryStyleChars,
    required this.memoryVisualChars,
    required this.memoryDeliveryChars,
    this.memoryTopCandidateScore = 0,
    this.memorySelectedPrimaryBucket,
    this.memoryLowValueCandidateSkipped = false,
    required this.memoryHitBuckets,
    required this.memorySuppressedBuckets,
    this.memoryHitBucketCounts = const <String, int>{},
    this.memorySuppressedBucketCounts = const <String, int>{},
    this.memoryOptimizationApplied = false,
    this.memoryOptimizationRemovedRows = 0,
    this.memoryOptimizationRemovedChars = 0,
    this.memoryOptimizationRemovedVisualRows = 0,
    this.memoryOptimizationRemovedDuplicateRows = 0,
    this.memoryOptimizationRemovedLowValueRows = 0,
    this.directorManualYieldedToMemory = false,
    this.directorManualYieldedChars = 0,
    this.directorPerformanceTrimmedChars = 0,
    this.directorAnchorSavedChars = 0,
    required this.continuityNoteCount,
    required this.continuityNoteChars,
    required this.usesReferenceFrame,
    required this.memoryBudgetTier,
    this.recentQualityMemoryBiases = const <String>[],
    this.memoryProjectScopeRowCount = 0,
    this.memoryScriptScopeRowCount = 0,
    this.memoryRoleScopeRowCount = 0,
  });

  final int promptChars;
  final int negativePromptChars;
  final int negativeConstraintCount;
  final int negativeCandidateFragmentCount;
  final int negativeSavedFragmentCount;
  final int negativeSavedChars;
  final String negativeBudgetTier;
  final String? autoNegativeSource;
  final int autoNegativeReviewFragmentCount;
  final int autoNegativeMemoryFragmentCount;
  final int observationNoteChars;
  final int roleAnchorCount;
  final int sceneAnchorCount;
  final int toolAnchorCount;
  final int styleAnchorCount;
  final int memoryStyleAnchorCount;
  final int memoryDeliveryAnchorCount;
  final bool memoryDeliveryPriorityApplied;
  final int memoryStyleChars;
  final int memoryVisualChars;
  final int memoryDeliveryChars;
  final double memoryTopCandidateScore;
  final String? memorySelectedPrimaryBucket;
  final bool memoryLowValueCandidateSkipped;
  final List<String> memoryHitBuckets;
  final List<String> memorySuppressedBuckets;
  final Map<String, int> memoryHitBucketCounts;
  final Map<String, int> memorySuppressedBucketCounts;
  final bool memoryOptimizationApplied;
  final int memoryOptimizationRemovedRows;
  final int memoryOptimizationRemovedChars;
  final int memoryOptimizationRemovedVisualRows;
  final int memoryOptimizationRemovedDuplicateRows;
  final int memoryOptimizationRemovedLowValueRows;
  final bool directorManualYieldedToMemory;
  final int directorManualYieldedChars;
  final int directorPerformanceTrimmedChars;
  final int directorAnchorSavedChars;
  final int continuityNoteCount;
  final int continuityNoteChars;
  final bool usesReferenceFrame;
  final String memoryBudgetTier;
  final List<String> recentQualityMemoryBiases;
  final int memoryProjectScopeRowCount;
  final int memoryScriptScopeRowCount;
  final int memoryRoleScopeRowCount;

  static Map<String, int> _bucketCounts(dynamic value) {
    if (value is! Map) return const <String, int>{};
    final result = <String, int>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final count = entry.value;
      if (key is String && key.isNotEmpty && count is num && count > 0) {
        result[key] = count.toInt();
      }
    }
    return Map.unmodifiable(result);
  }

  factory GenerateVideoPromptDiagnostics.fromJson(Map<String, dynamic> json) {
    return GenerateVideoPromptDiagnostics(
      promptChars: (json['promptChars'] as num?)?.toInt() ?? 0,
      negativePromptChars: (json['negativePromptChars'] as num?)?.toInt() ?? 0,
      negativeConstraintCount:
          (json['negativeConstraintCount'] as num?)?.toInt() ?? 0,
      negativeCandidateFragmentCount:
          (json['negativeCandidateFragmentCount'] as num?)?.toInt() ?? 0,
      negativeSavedFragmentCount:
          (json['negativeSavedFragmentCount'] as num?)?.toInt() ?? 0,
      negativeSavedChars: (json['negativeSavedChars'] as num?)?.toInt() ?? 0,
      negativeBudgetTier: json['negativeBudgetTier'] as String? ?? 'lean',
      autoNegativeSource: json['autoNegativeSource'] as String?,
      autoNegativeReviewFragmentCount:
          (json['autoNegativeReviewFragmentCount'] as num?)?.toInt() ?? 0,
      autoNegativeMemoryFragmentCount:
          (json['autoNegativeMemoryFragmentCount'] as num?)?.toInt() ?? 0,
      observationNoteChars:
          (json['observationNoteChars'] as num?)?.toInt() ?? 0,
      roleAnchorCount: (json['roleAnchorCount'] as num?)?.toInt() ?? 0,
      sceneAnchorCount: (json['sceneAnchorCount'] as num?)?.toInt() ?? 0,
      toolAnchorCount: (json['toolAnchorCount'] as num?)?.toInt() ?? 0,
      styleAnchorCount: (json['styleAnchorCount'] as num?)?.toInt() ?? 0,
      memoryStyleAnchorCount:
          (json['memoryStyleAnchorCount'] as num?)?.toInt() ?? 0,
      memoryDeliveryAnchorCount:
          (json['memoryDeliveryAnchorCount'] as num?)?.toInt() ?? 0,
      memoryDeliveryPriorityApplied:
          json['memoryDeliveryPriorityApplied'] == true,
      memoryStyleChars: (json['memoryStyleChars'] as num?)?.toInt() ?? 0,
      memoryVisualChars: (json['memoryVisualChars'] as num?)?.toInt() ?? 0,
      memoryDeliveryChars: (json['memoryDeliveryChars'] as num?)?.toInt() ?? 0,
      memoryTopCandidateScore:
          (json['memoryTopCandidateScore'] as num?)?.toDouble() ?? 0,
      memorySelectedPrimaryBucket:
          json['memorySelectedPrimaryBucket'] as String?,
      memoryLowValueCandidateSkipped:
          json['memoryLowValueCandidateSkipped'] == true,
      memoryHitBuckets: (json['memoryHitBuckets'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      memorySuppressedBuckets:
          (json['memorySuppressedBuckets'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      memoryHitBucketCounts: _bucketCounts(json['memoryHitBucketCounts']),
      memorySuppressedBucketCounts: _bucketCounts(
        json['memorySuppressedBucketCounts'],
      ),
      memoryOptimizationApplied: json['memoryOptimizationApplied'] == true,
      memoryOptimizationRemovedRows:
          (json['memoryOptimizationRemovedRows'] as num?)?.toInt() ?? 0,
      memoryOptimizationRemovedChars:
          (json['memoryOptimizationRemovedChars'] as num?)?.toInt() ?? 0,
      memoryOptimizationRemovedVisualRows:
          (json['memoryOptimizationRemovedVisualRows'] as num?)?.toInt() ?? 0,
      memoryOptimizationRemovedDuplicateRows:
          (json['memoryOptimizationRemovedDuplicateRows'] as num?)?.toInt() ??
          0,
      memoryOptimizationRemovedLowValueRows:
          (json['memoryOptimizationRemovedLowValueRows'] as num?)?.toInt() ??
          0,
      directorManualYieldedToMemory:
          json['directorManualYieldedToMemory'] == true,
      directorManualYieldedChars:
          (json['directorManualYieldedChars'] as num?)?.toInt() ?? 0,
      directorPerformanceTrimmedChars:
          (json['directorPerformanceTrimmedChars'] as num?)?.toInt() ?? 0,
      directorAnchorSavedChars:
          (json['directorAnchorSavedChars'] as num?)?.toInt() ?? 0,
      continuityNoteCount: (json['continuityNoteCount'] as num?)?.toInt() ?? 0,
      continuityNoteChars: (json['continuityNoteChars'] as num?)?.toInt() ?? 0,
      usesReferenceFrame: json['usesReferenceFrame'] == true,
      memoryBudgetTier: json['memoryBudgetTier'] as String? ?? 'expanded',
      recentQualityMemoryBiases:
          (json['recentQualityMemoryBiases'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      memoryProjectScopeRowCount:
          (json['memoryProjectScopeRowCount'] as num?)?.toInt() ?? 0,
      memoryScriptScopeRowCount:
          (json['memoryScriptScopeRowCount'] as num?)?.toInt() ?? 0,
      memoryRoleScopeRowCount:
          (json['memoryRoleScopeRowCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class GenerateVideoPromptResponse {
  const GenerateVideoPromptResponse({
    required this.prompt,
    this.negativePrompt,
    this.observationNote,
    required this.diagnostics,
    required this.model,
    required this.duration,
  });

  final String prompt;
  final String? negativePrompt;
  final String? observationNote;
  final GenerateVideoPromptDiagnostics diagnostics;
  final String model;
  final int duration;

  factory GenerateVideoPromptResponse.fromJson(Map<String, dynamic> json) {
    return GenerateVideoPromptResponse(
      prompt: json['prompt'] as String,
      negativePrompt: json['negativePrompt'] as String?,
      observationNote: json['observationNote'] as String?,
      diagnostics: GenerateVideoPromptDiagnostics.fromJson(
        (json['diagnostics'] as Map<String, dynamic>?) ?? const {},
      ),
      model: json['model'] as String,
      duration: (json['duration'] as num).toInt(),
    );
  }
}

class WorkbenchGenerateVoiceoverResponse {
  const WorkbenchGenerateVoiceoverResponse({
    required this.total,
    required this.enqueuedJobIds,
  });

  final int total;
  final List<String> enqueuedJobIds;

  factory WorkbenchGenerateVoiceoverResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawJobs = json['enqueued'] as List<dynamic>? ?? const [];
    return WorkbenchGenerateVoiceoverResponse(
      total: (json['total'] as num?)?.toInt() ?? rawJobs.length,
      enqueuedJobIds: rawJobs
          .map((item) => (item as Map<String, dynamic>)['id']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }
}

/// `POST /api/v1/production/workbench/generate-video-prompt` — OpenAPI `postWorkbenchGenerateVideoPromptV1`.
Future<GenerateVideoPromptResponse> postWorkbenchGenerateVideoPromptV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  int? storyboardId,
  bool? autoQualityReview,
  String? imageUrl,
  String? description,
  int? durationHint,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/generate-video-prompt',
  );
  final body = <String, dynamic>{'projectId': projectId, 'scriptId': scriptId};
  if (storyboardId != null) body['storyboardId'] = storyboardId;
  if (autoQualityReview == true) body['autoQualityReview'] = true;
  if (imageUrl != null) body['imageUrl'] = imageUrl;
  if (description != null) body['description'] = description;
  if (durationHint != null) body['durationHint'] = durationHint;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return GenerateVideoPromptResponse.fromJson(map);
}

/// OpenAPI **`GetGenerateDataResponse`**.
class GetGenerateDataResponse {
  const GetGenerateDataResponse({
    required this.projectId,
    required this.scriptId,
    required this.generatedVideos,
    required this.generatingJobs,
  });

  final int projectId;
  final int scriptId;
  final List<VideoItem> generatedVideos;
  final List<JobRow> generatingJobs;

  factory GetGenerateDataResponse.fromJson(Map<String, dynamic> json) {
    final rawVideos = json['generatedVideos'] as List<dynamic>? ?? const [];
    final rawJobs = json['generatingJobs'] as List<dynamic>? ?? const [];
    return GetGenerateDataResponse(
      projectId: (json['projectId'] as num).toInt(),
      scriptId: (json['scriptId'] as num).toInt(),
      generatedVideos: rawVideos
          .map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatingJobs: rawJobs
          .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// `POST /api/v1/production/workbench/get-generate-data` — OpenAPI `postWorkbenchGetGenerateDataV1`.
Future<GetGenerateDataResponse> postWorkbenchGetGenerateDataV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/get-generate-data',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'scriptId': scriptId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return GetGenerateDataResponse.fromJson(map);
}

/// `POST /api/v1/production/workbench/generate-voiceover`.
Future<WorkbenchGenerateVoiceoverResponse> postWorkbenchGenerateVoiceoverV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> storyboardIds,
  String? voice,
  double? speed,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/generate-voiceover',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'storyboardIds': storyboardIds,
  };
  if (voice != null && voice.trim().isNotEmpty) {
    body['voice'] = voice.trim();
  }
  if (speed != null) {
    body['speed'] = speed;
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
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkbenchGenerateVoiceoverResponse.fromJson(map);
}
