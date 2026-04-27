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
    required this.memoryStyleChars,
    required this.continuityNoteCount,
    required this.continuityNoteChars,
    required this.usesReferenceFrame,
    required this.memoryBudgetTier,
  });

  final int promptChars;
  final int negativePromptChars;
  final int negativeConstraintCount;
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
  final int memoryStyleChars;
  final int continuityNoteCount;
  final int continuityNoteChars;
  final bool usesReferenceFrame;
  final String memoryBudgetTier;

  factory GenerateVideoPromptDiagnostics.fromJson(Map<String, dynamic> json) {
    return GenerateVideoPromptDiagnostics(
      promptChars: (json['promptChars'] as num?)?.toInt() ?? 0,
      negativePromptChars: (json['negativePromptChars'] as num?)?.toInt() ?? 0,
      negativeConstraintCount:
          (json['negativeConstraintCount'] as num?)?.toInt() ?? 0,
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
      memoryStyleChars: (json['memoryStyleChars'] as num?)?.toInt() ?? 0,
      continuityNoteCount: (json['continuityNoteCount'] as num?)?.toInt() ?? 0,
      continuityNoteChars: (json['continuityNoteChars'] as num?)?.toInt() ?? 0,
      usesReferenceFrame: json['usesReferenceFrame'] == true,
      memoryBudgetTier: json['memoryBudgetTier'] as String? ?? 'expanded',
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

/// `POST /api/v1/production/workbench/generate-video-prompt` — OpenAPI `postWorkbenchGenerateVideoPromptV1`.
Future<GenerateVideoPromptResponse> postWorkbenchGenerateVideoPromptV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  int? storyboardId,
  String? imageUrl,
  String? description,
  int? durationHint,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/generate-video-prompt',
  );
  final body = <String, dynamic>{'projectId': projectId, 'scriptId': scriptId};
  if (storyboardId != null) body['storyboardId'] = storyboardId;
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
