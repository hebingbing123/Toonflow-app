import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class ProductionExportZipResponse {
  final String? filename;
  final Uint8List bytes;

  const ProductionExportZipResponse({
    required this.filename,
    required this.bytes,
  });
}

class WorkbenchStoryboardNegativePrompt {
  const WorkbenchStoryboardNegativePrompt({
    required this.storyboardId,
    this.negativePrompt,
  });

  final int storyboardId;
  final String? negativePrompt;

  factory WorkbenchStoryboardNegativePrompt.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkbenchStoryboardNegativePrompt(
      storyboardId: (json['storyboardId'] as num).toInt(),
      negativePrompt: json['negativePrompt'] as String?,
    );
  }
}

class WorkbenchGenerateVideoResponse {
  const WorkbenchGenerateVideoResponse({
    required this.total,
    this.negativePrompt,
    required this.storyboardNegativePrompts,
  });

  final int total;
  final String? negativePrompt;
  final List<WorkbenchStoryboardNegativePrompt> storyboardNegativePrompts;

  factory WorkbenchGenerateVideoResponse.fromJson(Map<String, dynamic> json) {
    final rawPrompts =
        json['storyboardNegativePrompts'] as List<dynamic>? ?? const [];
    return WorkbenchGenerateVideoResponse(
      total: (json['total'] as num?)?.toInt() ?? 0,
      negativePrompt: json['negativePrompt'] as String?,
      storyboardNegativePrompts: rawPrompts
          .map(
            (item) => WorkbenchStoryboardNegativePrompt.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class ProductionPatchRequest {
  const ProductionPatchRequest({
    required this.projectId,
    required this.episodesId,
    required this.scope,
    required this.ids,
    required this.reason,
    required this.modelTier,
  });

  final int projectId;
  final int episodesId;
  final String scope;
  final List<int> ids;
  final String reason;
  final String modelTier;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'projectId': projectId,
      'episodesId': episodesId,
      'scope': scope,
      'ids': ids,
      'reason': reason,
      'modelTier': modelTier,
    };
  }
}

class ProductionPatchResponse {
  const ProductionPatchResponse({
    required this.patchId,
    required this.scope,
    required this.processedIds,
    required this.modelTier,
    required this.status,
    required this.consecutiveFailures,
    required this.attributionMode,
    required this.attributionSummary,
    required this.attributionCategory,
    required this.suggestedUpstreamStage,
    required this.suggestedUpstreamScope,
    required this.repairPriority,
    required this.savedTokenEstimate,
    required this.memoryWritten,
  });

  factory ProductionPatchResponse.fromJson(Map<String, dynamic> json) {
    final rawIds = json['processedIds'] as List<dynamic>? ?? const [];
    final rawPriority = json['repairPriority'] as List<dynamic>? ?? const [];
    return ProductionPatchResponse(
      patchId: json['patchId']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      processedIds: rawIds.map((item) => (item as num).toInt()).toList(),
      modelTier: json['modelTier']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      consecutiveFailures: (json['consecutiveFailures'] as num?)?.toInt() ?? 0,
      attributionMode: json['attributionMode'] == true,
      attributionSummary: json['attributionSummary']?.toString(),
      attributionCategory: json['attributionCategory']?.toString(),
      suggestedUpstreamStage: json['suggestedUpstreamStage']?.toString(),
      suggestedUpstreamScope: json['suggestedUpstreamScope']?.toString(),
      repairPriority: rawPriority.map((item) => item.toString()).toList(),
      savedTokenEstimate: (json['savedTokenEstimate'] as num?)?.toInt() ?? 0,
      memoryWritten: json['memoryWritten'] == true,
    );
  }

  final String patchId;
  final String scope;
  final List<int> processedIds;
  final String modelTier;
  final String status;
  final int consecutiveFailures;
  final bool attributionMode;
  final String? attributionSummary;
  final String? attributionCategory;
  final String? suggestedUpstreamStage;
  final String? suggestedUpstreamScope;
  final List<String> repairPriority;
  final int savedTokenEstimate;
  final bool memoryWritten;
}

Future<int> postProductionGetProductionDataV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> storyboardIds,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-production-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'scriptId': scriptId,
          'ids': storyboardIds,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

Future<ProductionPatchResponse> postProductionPatchV1(
  String accessToken, {
  required ProductionPatchRequest request,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/patch');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw RustApiException('invalid production patch payload');
  }
  return ProductionPatchResponse.fromJson(decoded);
}

/// `POST /api/v1/production/get-flow-data` — OpenAPI `postProductionGetFlowDataV1`
/// (implemented in Rust; returns **200/404/503** when DB-gated).
Future<int> postProductionGetFlowDataV1(
  String accessToken, {
  required int projectId,
  required int episodesId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-flow-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'episodesId': episodesId}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/get-flow-data` — returns flow JSON object on success.
Future<Map<String, dynamic>> fetchProductionFlowDataV1(
  String accessToken, {
  required int projectId,
  required int episodesId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-flow-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'episodesId': episodesId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw RustApiException('invalid flow payload');
  }
  return decoded;
}

/// `POST /api/v1/production/save-flow-data` — OpenAPI `postProductionSaveFlowDataV1`
/// (implemented in Rust; returns **200/404/503** when DB-gated).
Future<int> postProductionSaveFlowDataV1(
  String accessToken, {
  required int projectId,
  required int episodesId,
  Map<String, dynamic> data = const {},
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/save-flow-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'episodesId': episodesId,
          'data': data,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/workbench/generate-video` — OpenAPI `postProductionWorkbenchGenerateVideoV1`
/// (implemented; returns final applied negative prompts per storyboard).
Future<WorkbenchGenerateVideoResponse> postProductionWorkbenchGenerateVideoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<Map<String, dynamic>> uploadData,
  required String prompt,
  String? negativePrompt,
  required String model,
  required String mode,
  required String resolution,
  required int duration,
  bool? audio,
  required int trackId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/generate-video',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'uploadData': uploadData,
    'prompt': prompt,
    'model': model,
    'mode': mode,
    'resolution': resolution,
    'duration': duration,
    'trackId': trackId,
  };
  if (negativePrompt != null) body['negativePrompt'] = negativePrompt;
  if (audio != null) body['audio'] = audio;
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
  return WorkbenchGenerateVideoResponse.fromJson(map);
}

/// `POST /api/v1/production/storyboard/polling-image` — OpenAPI `postProductionStoryboardPollingImageV1`
/// (implemented; returns **200** or **404** / **503** when DB-gated).
Future<int> postProductionStoryboardPollingImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> ids,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/polling-image',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'scriptId': scriptId,
          'ids': ids,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/export-image` — OpenAPI `postProductionExportImageV1`
/// Returns a ZIP attachment on **200**; this helper currently exposes status-only probing.
Future<int> postProductionExportImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<Map<String, dynamic>> shotId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/export-image');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'scriptId': scriptId,
          'shotId': shotId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/export-image` — fetches the ZIP attachment body.
Future<ProductionExportZipResponse> fetchProductionExportImageZipV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<Map<String, dynamic>> shotId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/export-image');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'scriptId': scriptId,
          'shotId': shotId,
        }),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return ProductionExportZipResponse(
    filename: _parseAttachmentFilename(res.headers['content-disposition']),
    bytes: res.bodyBytes,
  );
}

String? _parseAttachmentFilename(String? contentDisposition) {
  if (contentDisposition == null || contentDisposition.isEmpty) {
    return null;
  }
  final match = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
  if (match == null) {
    return null;
  }
  return match.group(1);
}
