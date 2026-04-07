import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Thrown when the Rust API returns a non-2xx or the body cannot be parsed.
class RustApiException implements Exception {
  RustApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RustApiException($statusCode): $message';
}

class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.legacyId,
    this.name,
    this.intro,
    this.projectType,
    this.imageModel,
    this.imageQuality,
    this.videoModel,
    this.artStyle,
    this.directorManual,
    this.mode,
    this.videoRatio,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final String? name;
  final String? intro;
  final String? projectType;
  final String? imageModel;
  final String? imageQuality;
  final String? videoModel;
  final String? artStyle;
  final String? directorManual;
  final String? mode;
  final String? videoRatio;
  final int? createTimeMs;

  factory ProjectRow.fromJson(Map<String, dynamic> json) {
    return ProjectRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String?,
      intro: json['intro'] as String?,
      projectType: json['project_type'] as String?,
      imageModel: json['image_model'] as String?,
      imageQuality: json['image_quality'] as String?,
      videoModel: json['video_model'] as String?,
      artStyle: json['art_style'] as String?,
      directorManual: json['director_manual'] as String?,
      mode: json['mode'] as String?,
      videoRatio: json['video_ratio'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// OpenAPI **`BatchGenerateAssetsImageResponse`**.
class BatchGenerateAssetsImageResponseV1 {
  const BatchGenerateAssetsImageResponseV1({
    required this.enqueued,
    required this.total,
  });

  final List<JobRow> enqueued;
  final int total;

  factory BatchGenerateAssetsImageResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['enqueued'] as List<dynamic>? ?? const [];
    return BatchGenerateAssetsImageResponseV1(
      enqueued:
          raw.map((e) => JobRow.fromJson(e as Map<String, dynamic>)).toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/production/assets/batch-generate-assets-image` — OpenAPI `postAssetsBatchGenerateAssetsImageV1`.
Future<BatchGenerateAssetsImageResponseV1> postProductionAssetsBatchGenerateAssetsImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> assetIds,
  String? model,
  String? resolution,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/assets/batch-generate-assets-image');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'assetIds': assetIds,
  };
  if (model != null) body['model'] = model;
  if (resolution != null) body['resolution'] = resolution;
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
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchGenerateAssetsImageResponseV1.fromJson(map);
}

/// OpenAPI **`DeleteAssetsDerivativeResponse`**.
class DeleteAssetsDerivativeResponseV1 {
  const DeleteAssetsDerivativeResponseV1({
    required this.deleted,
    required this.assetIds,
  });

  final int deleted;
  final List<int> assetIds;

  factory DeleteAssetsDerivativeResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['assetIds'] as List<dynamic>? ?? const [];
    return DeleteAssetsDerivativeResponseV1(
      deleted: (json['deleted'] as num).toInt(),
      assetIds: raw.map((e) => (e as num).toInt()).toList(),
    );
  }
}

/// `POST /api/v1/production/assets/delete-assets-derivative` — OpenAPI `postAssetsDeleteAssetsDerivativeV1`.
Future<DeleteAssetsDerivativeResponseV1> postProductionAssetsDeleteAssetsDerivativeV1(
  String accessToken, {
  required int projectId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/assets/delete-assets-derivative');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'assetIds': assetIds}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DeleteAssetsDerivativeResponseV1.fromJson(map);
}

/// OpenAPI **`AssetDataItem`**.
class AssetDataItemV1 {
  const AssetDataItemV1({
    required this.id,
    required this.name,
    required this.type,
    this.describe,
    this.coverLegacyImageId,
    this.createdAt,
  });

  final int id;
  final String name;
  final String type;
  final String? describe;
  final int? coverLegacyImageId;
  final DateTime? createdAt;

  factory AssetDataItemV1.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    final raw = json['createdAt'];
    if (raw is String) parsed = DateTime.tryParse(raw);
    return AssetDataItemV1(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      describe: json['describe'] as String?,
      coverLegacyImageId: json['coverLegacyImageId'] == null
          ? null
          : (json['coverLegacyImageId'] as num).toInt(),
      createdAt: parsed,
    );
  }
}

/// OpenAPI **`AssetsDataResponse`**.
class AssetsDataResponseV1 {
  const AssetsDataResponseV1({required this.assets, required this.total});

  final List<AssetDataItemV1> assets;
  final int total;

  factory AssetsDataResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['assets'] as List<dynamic>? ?? const [];
    return AssetsDataResponseV1(
      assets:
          raw.map((e) => AssetDataItemV1.fromJson(e as Map<String, dynamic>)).toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/production/assets/get-assets-data` — OpenAPI `postAssetsGetAssetsDataV1`.
Future<AssetsDataResponseV1> postProductionAssetsGetAssetsDataV1(
  String accessToken, {
  required int projectId,
  String? assetType,
  int limit = 50,
  int offset = 0,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/assets/get-assets-data');
  final body = <String, dynamic>{
    'projectId': projectId,
    'limit': limit,
    'offset': offset,
  };
  if (assetType != null) body['assetType'] = assetType;
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
  return AssetsDataResponseV1.fromJson(map);
}

/// OpenAPI **`AssetImageStatus`**.
class AssetImageStatusV1 {
  const AssetImageStatusV1({
    required this.assetId,
    required this.imageCount,
    this.latestState,
  });

  final int assetId;
  final int imageCount;
  final String? latestState;

  factory AssetImageStatusV1.fromJson(Map<String, dynamic> json) {
    return AssetImageStatusV1(
      assetId: (json['assetId'] as num).toInt(),
      imageCount: (json['imageCount'] as num).toInt(),
      latestState: json['latestState'] as String?,
    );
  }
}

/// OpenAPI **`AssetsPollingImageResponse`**.
class AssetsPollingImageResponseV1 {
  const AssetsPollingImageResponseV1({required this.statuses});

  final List<AssetImageStatusV1> statuses;

  factory AssetsPollingImageResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['statuses'] as List<dynamic>? ?? const [];
    return AssetsPollingImageResponseV1(
      statuses: raw
          .map((e) => AssetImageStatusV1.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// `POST /api/v1/production/assets/polling-image` — OpenAPI `postAssetsPollingImageV1`.
Future<AssetsPollingImageResponseV1> postProductionAssetsPollingImageV1(
  String accessToken, {
  required int projectId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/assets/polling-image');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'assetIds': assetIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetsPollingImageResponseV1.fromJson(map);
}

/// OpenAPI **`UpdateAssetsUrlResponse`**.
class UpdateAssetsUrlResponseV1 {
  const UpdateAssetsUrlResponseV1({
    required this.assetId,
    required this.imageUrl,
    required this.message,
  });

  final int assetId;
  final String imageUrl;
  final String message;

  factory UpdateAssetsUrlResponseV1.fromJson(Map<String, dynamic> json) {
    return UpdateAssetsUrlResponseV1(
      assetId: (json['assetId'] as num).toInt(),
      imageUrl: json['imageUrl'] as String,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/assets/update-assets-url` — OpenAPI `postAssetsUpdateAssetsUrlV1`.
Future<UpdateAssetsUrlResponseV1> postProductionAssetsUpdateAssetsUrlV1(
  String accessToken, {
  required int projectId,
  required int assetId,
  required String imageUrl,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/assets/update-assets-url');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'assetId': assetId,
          'imageUrl': imageUrl,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UpdateAssetsUrlResponseV1.fromJson(map);
}

/// OpenAPI **`ImageFlowStep`**.
class ImageFlowStepV1 {
  const ImageFlowStepV1({
    required this.stepId,
    required this.stepName,
    required this.status,
  });

  final String stepId;
  final String stepName;
  final String status;

  factory ImageFlowStepV1.fromJson(Map<String, dynamic> json) {
    return ImageFlowStepV1(
      stepId: json['stepId'] as String,
      stepName: json['stepName'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepId': stepId,
      'stepName': stepName,
      'status': status,
    };
  }
}

/// OpenAPI **`ImageFlowResponse`**.
class ImageFlowResponseV1 {
  const ImageFlowResponseV1({
    required this.flowId,
    required this.steps,
    required this.defaultModel,
  });

  final String flowId;
  final List<ImageFlowStepV1> steps;
  final String defaultModel;

  factory ImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['steps'] as List<dynamic>? ?? const [];
    return ImageFlowResponseV1(
      flowId: json['flowId'] as String,
      steps:
          raw.map((e) => ImageFlowStepV1.fromJson(e as Map<String, dynamic>)).toList(),
      defaultModel: json['defaultModel'] as String,
    );
  }
}

/// `POST /api/v1/production/edit-image/get-image-flow` — OpenAPI `postEditImageGetImageFlowV1`.
Future<ImageFlowResponseV1> postProductionEditImageGetImageFlowV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/edit-image/get-image-flow');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ImageFlowResponseV1.fromJson(map);
}

/// OpenAPI **`ImageDefaultModelResponse`**.
class ImageDefaultModelResponseV1 {
  const ImageDefaultModelResponseV1({
    required this.model,
    required this.resolution,
  });

  final String model;
  final String resolution;

  factory ImageDefaultModelResponseV1.fromJson(Map<String, dynamic> json) {
    return ImageDefaultModelResponseV1(
      model: json['model'] as String,
      resolution: json['resolution'] as String,
    );
  }
}

/// `POST /api/v1/production/edit-image/get-image-default-model` — OpenAPI `postEditImageGetImageDefaultModelV1`.
Future<ImageDefaultModelResponseV1> postProductionEditImageGetImageDefaultModelV1(
  String accessToken,
) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/edit-image/get-image-default-model');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ImageDefaultModelResponseV1.fromJson(map);
}

/// OpenAPI **`SaveImageFlowResponse`**.
class SaveImageFlowResponseV1 {
  const SaveImageFlowResponseV1({required this.flowId, required this.saved});

  final String flowId;
  final bool saved;

  factory SaveImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    return SaveImageFlowResponseV1(
      flowId: json['flowId'] as String,
      saved: json['saved'] as bool,
    );
  }
}

/// `POST /api/v1/production/edit-image/save-image-flow` — OpenAPI `postEditImageSaveImageFlowV1`.
Future<SaveImageFlowResponseV1> postProductionEditImageSaveImageFlowV1(
  String accessToken, {
  required String flowId,
  required List<Map<String, dynamic>> steps,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/edit-image/save-image-flow');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'flowId': flowId, 'steps': steps}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SaveImageFlowResponseV1.fromJson(map);
}

/// OpenAPI **`UpdateImageFlowResponse`**.
class UpdateImageFlowResponseV1 {
  const UpdateImageFlowResponseV1({
    required this.flowId,
    required this.stepId,
    required this.updated,
  });

  final String flowId;
  final String stepId;
  final bool updated;

  factory UpdateImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    return UpdateImageFlowResponseV1(
      flowId: json['flowId'] as String,
      stepId: json['stepId'] as String,
      updated: json['updated'] as bool,
    );
  }
}

/// `POST /api/v1/production/edit-image/update-image-flow` — OpenAPI `postEditImageUpdateImageFlowV1`.
Future<UpdateImageFlowResponseV1> postProductionEditImageUpdateImageFlowV1(
  String accessToken, {
  required String flowId,
  required String stepId,
  required Map<String, dynamic> updates,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/edit-image/update-image-flow');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'flowId': flowId, 'stepId': stepId, 'updates': updates}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UpdateImageFlowResponseV1.fromJson(map);
}

/// OpenAPI **`GenerateFlowImageResponse`**.
class GenerateFlowImageResponseV1 {
  const GenerateFlowImageResponseV1({required this.jobId, required this.status});

  final String jobId;
  final String status;

  factory GenerateFlowImageResponseV1.fromJson(Map<String, dynamic> json) {
    return GenerateFlowImageResponseV1(
      jobId: json['jobId'] as String,
      status: json['status'] as String,
    );
  }
}

/// `POST /api/v1/production/edit-image/generate-flow-image` — OpenAPI `postEditImageGenerateFlowImageV1`.
Future<GenerateFlowImageResponseV1> postProductionEditImageGenerateFlowImageV1(
  String accessToken, {
  required String flowId,
  required String prompt,
  String? model,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/edit-image/generate-flow-image');
  final body = <String, dynamic>{
    'flowId': flowId,
    'prompt': prompt,
  };
  if (model != null) body['model'] = model;
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return GenerateFlowImageResponseV1.fromJson(map);
}

class ScriptBrief {
  const ScriptBrief({
    required this.legacyId,
    this.name,
    this.extractState,
  });

  final int legacyId;
  final String? name;
  final int? extractState;

  factory ScriptBrief.fromJson(Map<String, dynamic> json) {
    return ScriptBrief(
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String?,
      extractState: json['extract_state'] == null
          ? null
          : (json['extract_state'] as num).toInt(),
    );
  }
}

class ProjectDetail {
  const ProjectDetail({
    required this.project,
    required this.scripts,
  });

  final ProjectRow project;
  final List<ScriptBrief> scripts;

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    return ProjectDetail(
      project: ProjectRow.fromJson(json['project'] as Map<String, dynamic>),
      scripts: (json['scripts'] as List<dynamic>)
          .map((e) => ScriptBrief.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProjectStats {
  const ProjectStats({
    required this.scriptCount,
    required this.storyboardCount,
    required this.roleCount,
    required this.novelCount,
    required this.videoCount,
  });

  final int scriptCount;
  final int storyboardCount;
  final int roleCount;
  final int novelCount;
  final int videoCount;

  factory ProjectStats.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return ProjectStats(
      scriptCount: n('script_count'),
      storyboardCount: n('storyboard_count'),
      roleCount: n('role_count'),
      novelCount: json['novel_count'] != null
          ? (json['novel_count'] as num).toInt()
          : 0,
      videoCount: n('video_count'),
    );
  }
}

/// One row from **`GET /api/v1/art-styles`** (`ArtStyleRow` in OpenAPI).
class ArtStyleRow {
  const ArtStyleRow({
    required this.id,
    required this.legacyId,
    required this.name,
    this.fileUrl,
    this.label,
    this.prompt,
  });

  final String id;
  final int legacyId;
  final String name;
  final String? fileUrl;
  final String? label;
  final String? prompt;

  factory ArtStyleRow.fromJson(Map<String, dynamic> json) {
    return ArtStyleRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      fileUrl: json['file_url'] as String?,
      label: json['label'] as String?,
      prompt: json['prompt'] as String?,
    );
  }
}

/// **`GET /api/v1/art-styles`** list envelope.
class ListArtStylesResponse {
  const ListArtStylesResponse({
    required this.items,
    required this.total,
  });

  final List<ArtStyleRow> items;
  final int total;

  factory ListArtStylesResponse.fromJson(Map<String, dynamic> json) {
    return ListArtStylesResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => ArtStyleRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/art-styles/extract-prompt` — OpenAPI `ExtractArtStylePromptResponse`.
class ExtractArtStylePromptResponse {
  const ExtractArtStylePromptResponse({required this.text});

  final String text;

  factory ExtractArtStylePromptResponse.fromJson(Map<String, dynamic> json) {
    return ExtractArtStylePromptResponse(text: json['text'] as String);
  }
}

/// JSON body for **`GET /health`** and **`GET /api/v1/health`** (OpenAPI `HealthResponse`).
class HealthResponse {
  const HealthResponse({
    required this.status,
    required this.service,
  });

  final String status;
  final String service;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      service: json['service'] as String,
    );
  }
}

/// `GET /api/v1/health` — no auth.
Future<HealthResponse> fetchHealthV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/health');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HealthResponse.fromJson(map);
}

/// Unversioned **`GET /health`** — same JSON as [fetchHealthV1].
Future<HealthResponse> fetchHealthRoot() async {
  final uri = Uri.parse('$kApiBaseUrl/health');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HealthResponse.fromJson(map);
}

/// OpenAPI `PingResponse` — legacy **`GET /api/test/test`** (`ok` text) as JSON.
class PingResponse {
  const PingResponse({required this.ok});

  final bool ok;

  factory PingResponse.fromJson(Map<String, dynamic> json) {
    return PingResponse(ok: json['ok'] as bool);
  }
}

/// `GET /api/v1/ping` — no auth.
Future<PingResponse> fetchPingV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/ping');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PingResponse.fromJson(map);
}

/// `GET /api/v1/version` — no auth; OpenAPI `VersionResponse`.
class VersionResponse {
  const VersionResponse({
    required this.service,
    required this.version,
    this.gitSha,
  });

  final String service;
  final String version;
  final String? gitSha;

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      service: json['service'] as String,
      version: json['version'] as String,
      gitSha: json['git_sha'] as String?,
    );
  }
}

Future<VersionResponse> fetchVersionV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/version');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VersionResponse.fromJson(map);
}

/// `GET /api/v1/ready` — no auth; see `readyV1`.
class ReadyV1Response {
  const ReadyV1Response({
    required this.status,
    required this.database,
  });

  final String status;
  final String database;

  factory ReadyV1Response.fromJson(Map<String, dynamic> json) {
    return ReadyV1Response(
      status: json['status'] as String,
      database: json['database'] as String,
    );
  }
}

Future<ReadyV1Response> fetchReadyV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/ready');
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ReadyV1Response.fromJson(map);
}

/// `GET /api/v1/me` — Bearer; see `meV1` / OpenAPI `MeResponse`.
class MeResponse {
  const MeResponse({
    required this.sub,
    this.email,
    required this.planTier,
    this.billingCurrency,
    this.billingProvider,
  });

  final String sub;
  final String? email;
  final String planTier;
  final String? billingCurrency;
  final String? billingProvider;

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      sub: json['sub'] as String,
      email: json['email'] as String?,
      planTier: json['plan_tier'] as String,
      billingCurrency: json['billing_currency'] as String?,
      billingProvider: json['billing_provider'] as String?,
    );
  }
}

Future<MeResponse> fetchMeV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/me');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MeResponse.fromJson(map);
}

/// OpenAPI **`SwitchAiDevToolResponse`** — legacy **`getSwitchAiDevTool`**.
class SwitchAiDevToolV1 {
  const SwitchAiDevToolV1({required this.value});

  final String value;

  factory SwitchAiDevToolV1.fromJson(Map<String, dynamic> json) {
    return SwitchAiDevToolV1(value: json['value'] as String);
  }
}

/// `GET /api/v1/settings/dev/switch-ai-tool` — OpenAPI `getSwitchAiDevToolV1`.
Future<SwitchAiDevToolV1> fetchSwitchAiDevToolV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/dev/switch-ai-tool');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SwitchAiDevToolV1.fromJson(map);
}

/// `PUT /api/v1/settings/dev/switch-ai-tool` — OpenAPI `putSwitchAiDevToolV1` (typically **501**).
Future<int> putSwitchAiDevToolV1(String accessToken, String value) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/dev/switch-ai-tool');
  final res = await http
      .put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'value': value}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// OpenAPI **`MemoryConfig`** — legacy **`getMemory`** / **`sureMemory`** (**camelCase**).
class MemoryConfigV1 {
  const MemoryConfigV1({
    required this.messagesPerSummary,
    required this.shortTermLimit,
    required this.summaryMaxLength,
    required this.summaryLimit,
    required this.ragLimit,
    required this.deepRetrieveSummaryLimit,
    required this.modelOnnxFile,
    required this.modelDtype,
  });

  final int messagesPerSummary;
  final int shortTermLimit;
  final int summaryMaxLength;
  final int summaryLimit;
  final int ragLimit;
  final int deepRetrieveSummaryLimit;
  final List<String> modelOnnxFile;
  final String modelDtype;

  factory MemoryConfigV1.fromJson(Map<String, dynamic> json) {
    final files = json['modelOnnxFile'];
    return MemoryConfigV1(
      messagesPerSummary: (json['messagesPerSummary'] as num).toInt(),
      shortTermLimit: (json['shortTermLimit'] as num).toInt(),
      summaryMaxLength: (json['summaryMaxLength'] as num).toInt(),
      summaryLimit: (json['summaryLimit'] as num).toInt(),
      ragLimit: (json['ragLimit'] as num).toInt(),
      deepRetrieveSummaryLimit:
          (json['deepRetrieveSummaryLimit'] as num).toInt(),
      modelOnnxFile: (files is List)
          ? files.map((e) => e.toString()).toList()
          : <String>[],
      modelDtype: json['modelDtype'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'messagesPerSummary': messagesPerSummary,
        'shortTermLimit': shortTermLimit,
        'summaryMaxLength': summaryMaxLength,
        'summaryLimit': summaryLimit,
        'ragLimit': ragLimit,
        'deepRetrieveSummaryLimit': deepRetrieveSummaryLimit,
        'modelOnnxFile': modelOnnxFile,
        'modelDtype': modelDtype,
      };

  MemoryConfigV1 copyWith({int? ragLimit}) {
    return MemoryConfigV1(
      messagesPerSummary: messagesPerSummary,
      shortTermLimit: shortTermLimit,
      summaryMaxLength: summaryMaxLength,
      summaryLimit: summaryLimit,
      ragLimit: ragLimit ?? this.ragLimit,
      deepRetrieveSummaryLimit: deepRetrieveSummaryLimit,
      modelOnnxFile: List<String>.from(modelOnnxFile),
      modelDtype: modelDtype,
    );
  }
}

/// `GET /api/v1/settings/memory-config` — OpenAPI `getMemoryConfigV1`.
Future<MemoryConfigV1> fetchMemoryConfigV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/memory-config');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MemoryConfigV1.fromJson(map);
}

/// `POST /api/v1/settings/memory-config` — OpenAPI `postMemoryConfigV1`; returns **`message`** (legacy success text).
Future<String> postMemoryConfigV1(
  String accessToken,
  MemoryConfigV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/memory-config');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String;
}

/// `POST /api/v1/settings/memory-config/clear-agent-memories` — OpenAPI `postSettingsClearAgentMemoriesV1` (often **503** without DB).
Future<int> postSettingsClearAgentMemoriesV1(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/settings/memory-config/clear-agent-memories');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'episodesId': ?episodesId,
  };
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
  return res.statusCode;
}

/// OpenAPI **`AgentDeployListItem`** — legacy **`o_agentDeploy`** row shape (**camelCase**).
class AgentDeployListItemV1 {
  const AgentDeployListItemV1({
    required this.id,
    required this.model,
    required this.key,
    required this.modelName,
    required this.vendorId,
    required this.desc,
    required this.name,
    required this.disabled,
    required this.icon,
  });

  final int id;
  final String model;
  final String key;
  final String modelName;
  final String? vendorId;
  final String desc;
  final String name;
  final bool disabled;
  final String icon;

  factory AgentDeployListItemV1.fromJson(Map<String, dynamic> json) {
    return AgentDeployListItemV1(
      id: (json['id'] as num).toInt(),
      model: json['model'] as String? ?? '',
      key: json['key'] as String,
      modelName: json['modelName'] as String? ?? '',
      vendorId: json['vendorId'] as String?,
      desc: json['desc'] as String? ?? '',
      name: json['name'] as String? ?? '',
      disabled: json['disabled'] as bool? ?? false,
      icon: json['icon'] as String? ?? '',
    );
  }
}

/// `POST /api/v1/settings/agent-deploy/list` — OpenAPI `postSettingsAgentDeployListV1` (body **`{}`**).
Future<List<AgentDeployListItemV1>> postAgentDeployListV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/agent-deploy/list');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => AgentDeployListItemV1.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/settings/agent-deploy/deploy-model` — OpenAPI `postSettingsAgentDeployModelV1` (typically **501**).
Future<int> postSettingsAgentDeployModelV1(
  String accessToken, {
  required int id,
  required String name,
  required String model,
  required String modelName,
  String? vendorId,
  required String desc,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/agent-deploy/deploy-model');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'name': name,
          'model': model,
          'modelName': modelName,
          'vendorId': vendorId,
          'desc': desc,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/agent-deploy/set-key` — OpenAPI `postSettingsAgentDeploySetKeyV1` (typically **501**).
Future<int> postSettingsAgentDeploySetKeyV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/agent-deploy/set-key');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/model-test` — OpenAPI `postSettingsVendorModelTestV1`.
/// **200** = **`queued`** **`JobRow`** (**`settings.vendor.model_test`**); **429**/**503** as elsewhere.
Future<int> postSettingsVendorModelTestV1(
  String accessToken, {
  required String modelName,
  required String type,
  required String id,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/model-test');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'modelName': modelName,
          'type': type,
          'id': id,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/update` — OpenAPI `postSettingsVendorsUpdateV1` (typically **501**).
Future<int> postSettingsVendorsUpdateV1(
  String accessToken, {
  required String id,
  Map<String, String>? inputValues,
  List<dynamic> inputs = const [],
  List<dynamic> models = const [],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/update');
  final body = <String, dynamic>{
    'id': id,
    'inputs': inputs,
    'models': models,
  };
  if (inputValues != null) {
    body['inputValues'] = inputValues;
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
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/delete` — OpenAPI `postSettingsVendorsDeleteV1` (typically **501**).
Future<int> postSettingsVendorsDeleteV1(
  String accessToken, {
  required String id,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/delete');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/enable` — OpenAPI `postSettingsVendorsEnableV1` (typically **501**).
Future<int> postSettingsVendorsEnableV1(
  String accessToken, {
  required String id,
  required num enable,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/enable');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': id, 'enable': enable}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/update-code` — OpenAPI `postSettingsVendorsUpdateCodeV1` (typically **501**).
Future<int> postSettingsVendorsUpdateCodeV1(
  String accessToken, {
  required String id,
  required String tsCode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/update-code');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': id, 'tsCode': tsCode}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/code-from-link` — OpenAPI `postSettingsVendorsCodeFromLinkV1` (typically **501**).
Future<int> postSettingsVendorsCodeFromLinkV1(
  String accessToken, {
  required String link,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/code-from-link');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'link': link}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/script-agent/get-plan-data` — OpenAPI `postScriptAgentGetPlanDataV1` (typically **501**).
Future<int> postScriptAgentGetPlanDataV1(
  String accessToken, {
  required int projectId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/get-plan-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'agentType': 'scriptAgent',
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/script-agent/set-plan-data` — OpenAPI `postScriptAgentSetPlanDataV1` (typically **501**).
Future<int> postScriptAgentSetPlanDataV1(
  String accessToken, {
  required int projectId,
  String storySkeleton = '',
  String adaptationStrategy = '',
  List<Map<String, dynamic>> script = const [],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/set-plan-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'agentType': 'scriptAgent',
          'data': {
            'storySkeleton': storySkeleton,
            'adaptationStrategy': adaptationStrategy,
            'script': script,
          },
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/script-agent/update-data` — OpenAPI `postScriptAgentUpdateDataV1` (typically **501**).
Future<int> postScriptAgentUpdateDataV1(
  String accessToken, {
  required int id,
  String storySkeleton = '',
  String adaptationStrategy = '',
  List<Map<String, dynamic>> script = const [
    {'id': 1, 'content': ''},
  ],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/update-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'data': {
            'storySkeleton': storySkeleton,
            'adaptationStrategy': adaptationStrategy,
            'script': script,
          },
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/generate` — OpenAPI `postAssetsGenerateV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.generate.image`**); worker **`succeeded`** inserts
/// **`app_asset_image`** (temporary provider **`image_url`**) when **`OPENAI_API_KEY`/`LLM_API_KEY`**
/// is set. **404** unknown project; **429** daily quota; **503** no DB.
Future<int> postAssetsGenerateGenerateV1(
  String accessToken, {
  required int projectId,
  required int assetLegacyId,
  required String model,
  required String resolution,
  required String type,
  required String name,
  required String prompt,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/generate');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'model': model,
          'resolution': resolution,
          'id': assetLegacyId,
          'type': type,
          'name': name,
          'prompt': prompt,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/polish-prompt` — OpenAPI `postAssetsGeneratePolishPromptV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.polish.prompt`**); worker **`succeeded`** with
/// **`result.polished_prompt`** when **`OPENAI_API_KEY`/`LLM_API_KEY`** is set on the server.
/// **404**/**429**/**503** as for **`generate`**.
Future<int> postAssetsGeneratePolishPromptV1(
  String accessToken, {
  required int assetsId,
  required int projectId,
  required String type,
  required String name,
  required String describe,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/polish-prompt');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'assetsId': assetsId,
          'projectId': projectId,
          'type': type,
          'name': name,
          'describe': describe,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/batch-generate` — OpenAPI `postAssetsGenerateBatchGenerateV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.generate.batch`**); worker runs **`images/generations`**
/// per item when LLM keys are set (**`result.items`**). **404**/**429**/**503** as for **`generate`**.
Future<int> postAssetsGenerateBatchGenerateV1(
  String accessToken, {
  required int projectId,
  required String model,
  required String resolution,
  required List<Map<String, dynamic>> items,
  int? concurrentCount,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/batch-generate');
  final body = <String, dynamic>{
    'projectId': projectId,
    'model': model,
    'resolution': resolution,
    'items': items,
  };
  if (concurrentCount != null) body['concurrentCount'] = concurrentCount;
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
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/batch-polish` — OpenAPI `postAssetsGenerateBatchPolishV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.polish.batch`**); worker **`succeeded`** with
/// **`result.items`** (each **`polished_prompt`**) when the server has **`OPENAI_API_KEY`/`LLM_API_KEY`**.
Future<int> postAssetsGenerateBatchPolishV1(
  String accessToken, {
  required int projectId,
  required List<Map<String, dynamic>> items,
  int? concurrentCount,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/batch-polish');
  final body = <String, dynamic>{
    'projectId': projectId,
    'items': items,
  };
  if (concurrentCount != null) body['concurrentCount'] = concurrentCount;
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
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/add` — OpenAPI `postSettingsVendorsAddV1` (typically **501**).
Future<int> postSettingsVendorsAddV1(String accessToken, {required String tsCode}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/add');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'tsCode': tsCode}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/danger/delete-all-data` — OpenAPI `postSettingsDangerDeleteAllDataV1` (typically **501**).
Future<int> postSettingsDangerDeleteAllDataV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/danger/delete-all-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/danger/clear-database` — OpenAPI `postSettingsDangerClearDatabaseV1` (typically **501**).
Future<int> postSettingsDangerClearDatabaseV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/danger/clear-database');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).
Future<int> postProductionGetProductionDataV1(
  String accessToken, {
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
        body: jsonEncode({'ids': storyboardIds}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
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
        body: jsonEncode({
          'projectId': projectId,
          'episodesId': episodesId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
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
/// (implemented; returns **200** or **404** / **503** when DB-gated).
Future<int> postProductionWorkbenchGenerateVideoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<Map<String, dynamic>> uploadData,
  required String prompt,
  required String model,
  required String mode,
  required String resolution,
  required int duration,
  bool? audio,
  required int trackId,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/production/workbench/generate-video');
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
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/polling-image` — OpenAPI `postProductionStoryboardPollingImageV1`
/// (implemented; returns **200** or **404** / **503** when DB-gated).
Future<int> postProductionStoryboardPollingImageV1(
  String accessToken, {
  required List<int> ids,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/polling-image');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': ids}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/export-image` — OpenAPI `postProductionExportImageV1`
/// (implemented; returns **200** or **404** / **503** when DB-gated).
Future<int> postProductionExportImageV1(
  String accessToken, {
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
        body: jsonEncode({'shotId': shotId}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/*` legacy JSON-object stub — **400** if body is not a JSON object; **501** when object (**OpenAPI** `ProductionLegacyJsonStubBody`).
Future<int> postProductionLegacyJsonStubV1(
  String accessToken,
  String path, {
  Map<String, dynamic> body = const {},
}) async {
  if (!path.startsWith('/api/v1/production/')) {
    throw ArgumentError.value(path, 'path', 'must start with /api/v1/production/');
  }
  final uri = Uri.parse('$kApiBaseUrl$path');
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
  return res.statusCode;
}

/// OpenAPI **`AboutCheckUpdateResponse`** — legacy desktop **`checkUpdate`** shape (**camelCase**).
class AboutCheckUpdateResponseV1 {
  const AboutCheckUpdateResponseV1({
    required this.needUpdate,
    required this.latestVersion,
    required this.reinstall,
    required this.time,
    this.url,
  });

  final bool needUpdate;
  final String latestVersion;
  final bool reinstall;
  final String time;
  final String? url;

  factory AboutCheckUpdateResponseV1.fromJson(Map<String, dynamic> json) {
    return AboutCheckUpdateResponseV1(
      needUpdate: json['needUpdate'] as bool,
      latestVersion: json['latestVersion'] as String,
      reinstall: json['reinstall'] as bool,
      time: json['time'] as String,
      url: json['url'] as String?,
    );
  }
}

/// `POST /api/v1/settings/about/check-update` — OpenAPI `postAboutCheckUpdateV1`.
Future<AboutCheckUpdateResponseV1> postAboutCheckUpdateV1(
  String accessToken,
  String source,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/about/check-update');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'source': source}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AboutCheckUpdateResponseV1.fromJson(map);
}

/// `POST /api/v1/settings/about/download-app` — OpenAPI `postAboutDownloadAppV1` (typically **501**).
Future<int> postAboutDownloadAppV1(
  String accessToken, {
  required String url,
  required bool reinstall,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/about/download-app');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'url': url, 'reinstall': reinstall}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `GET /api/v1/usage/summary` — OpenAPI `UsageSummaryResponse`.
class UsageSummaryResponse {
  const UsageSummaryResponse({
    required this.eventsLast24h,
    required this.eventsLast7d,
    required this.eventCountsLast7d,
  });

  final int eventsLast24h;
  final int eventsLast7d;
  final Map<String, int> eventCountsLast7d;

  factory UsageSummaryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['event_counts_last_7d'];
    final counts = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is num) {
          counts[k] = v.toInt();
        }
      });
    }
    return UsageSummaryResponse(
      eventsLast24h: (json['events_last_24h'] as num).toInt(),
      eventsLast7d: (json['events_last_7d'] as num).toInt(),
      eventCountsLast7d: counts,
    );
  }
}

/// `GET /api/v1/usage/summary` — see `usageSummaryV1`.
Future<UsageSummaryResponse> fetchUsageSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/usage/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UsageSummaryResponse.fromJson(map);
}

/// One row from **`GET /api/v1/prompts`** (`PromptTemplateRow` in OpenAPI).
class PromptTemplateRowV1 {
  const PromptTemplateRowV1({
    required this.id,
    required this.name,
    required this.type,
    required this.data,
  });

  final int id;
  final String name;
  final String type;
  final String data;

  factory PromptTemplateRowV1.fromJson(Map<String, dynamic> json) {
    return PromptTemplateRowV1(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      data: json['data'] as String,
    );
  }
}

/// `GET /api/v1/prompts` — OpenAPI `listPromptsV1`.
Future<List<PromptTemplateRowV1>> fetchPromptsV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PromptTemplateRowV1.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/prompts/{legacy_id}` — OpenAPI `getPromptByLegacyIdV1`.
Future<PromptTemplateRowV1> fetchPromptByLegacyIdV1(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$legacyId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PromptTemplateRowV1.fromJson(map);
}

/// `PATCH /api/v1/prompts/{legacy_id}` — OpenAPI `patchPromptByLegacyIdV1` (**`data`** only).
///
/// **`legacy_id`** must be **1**, **2**, or **3**. Returns the updated row (same shape as GET).
Future<PromptTemplateRowV1> patchPromptByLegacyIdV1(
  String accessToken,
  int legacyId,
  String data,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': data}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PromptTemplateRowV1.fromJson(map);
}

/// OpenAPI **`VisualManualEntry`**.
class VisualManualEntryV1 {
  const VisualManualEntryV1({
    required this.label,
    required this.value,
    required this.data,
  });

  final String label;
  final String value;
  final String data;

  factory VisualManualEntryV1.fromJson(Map<String, dynamic> json) {
    return VisualManualEntryV1(
      label: json['label'] as String,
      value: json['value'] as String,
      data: json['data'] as String,
    );
  }
}

/// OpenAPI **`VisualManualStyle`**.
class VisualManualStyleV1 {
  const VisualManualStyleV1({
    required this.name,
    required this.image,
    required this.stylePath,
    required this.data,
  });

  final String name;
  final List<String> image;
  final String stylePath;
  final List<VisualManualEntryV1> data;

  factory VisualManualStyleV1.fromJson(Map<String, dynamic> json) {
    final imgs = json['image'] as List<dynamic>? ?? const [];
    final slots = json['data'] as List<dynamic>? ?? const [];
    return VisualManualStyleV1(
      name: json['name'] as String,
      image: imgs.map((e) => e as String).toList(),
      stylePath: json['stylePath'] as String,
      data: slots
          .map((e) => VisualManualEntryV1.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// OpenAPI **`VisualManualResponse`**.
class VisualManualResponseV1 {
  const VisualManualResponseV1({required this.styles});

  final List<VisualManualStyleV1> styles;

  factory VisualManualResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['styles'] as List<dynamic>? ?? const [];
    return VisualManualResponseV1(
      styles: raw
          .map((e) => VisualManualStyleV1.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// `GET /api/v1/visual-manual` — OpenAPI `getVisualManualV1`.
Future<VisualManualResponseV1> fetchVisualManualV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}

/// `POST /api/v1/visual-manual` — OpenAPI `postVisualManualV1` (same JSON as GET; body ignored).
Future<VisualManualResponseV1> fetchVisualManualPostV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}

/// Builds `GET /api/v1/skills/binary?path=` — OpenAPI `getSkillBinaryV1` (JWT on the request).
Uri skillsBinaryV1Uri(String pathUnderDataSkills) {
  return Uri.parse('$kApiBaseUrl/api/v1/skills/binary').replace(
    queryParameters: {'path': pathUnderDataSkills},
  );
}

/// Fetches raw image (or other allowed) bytes from [`skillsBinaryV1Uri`].
Future<Uint8List> fetchSkillsBinaryV1(
  String accessToken,
  String pathUnderDataSkills,
) async {
  final uri = skillsBinaryV1Uri(pathUnderDataSkills);
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(
      res.body.isNotEmpty ? res.body : 'binary response ${res.statusCode}',
      statusCode: res.statusCode,
    );
  }
  return res.bodyBytes;
}

/// Row from `GET /api/v1/models` — OpenAPI `ModelListEntry`.
class ModelListEntry {
  const ModelListEntry({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
    required this.name,
  });

  final int id;
  final String label;
  final String value;
  final String type;
  final String name;

  factory ModelListEntry.fromJson(Map<String, dynamic> json) {
    return ModelListEntry(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String,
      value: json['value'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
    );
  }
}

/// `GET /api/v1/models/detail` body — OpenAPI `ModelDetailResponse`.
class ModelDetailResponse {
  const ModelDetailResponse({
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.modelName,
    required this.type,
  });

  final int vendorId;
  final String vendorName;
  final String name;
  final String modelName;
  final String type;

  factory ModelDetailResponse.fromJson(Map<String, dynamic> json) {
    return ModelDetailResponse(
      vendorId: (json['vendor_id'] as num).toInt(),
      vendorName: json['vendor_name'] as String,
      name: json['name'] as String,
      modelName: json['model_name'] as String,
      type: json['type'] as String,
    );
  }
}

/// `GET /api/v1/models?type=…` — Bearer; see `listModelsV1`.
Future<List<ModelListEntry>> fetchModelsCatalog(
  String accessToken, {
  String typeFilter = 'all',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models').replace(
    queryParameters: {'type': typeFilter},
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ModelListEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// OpenAPI **`VendorCatalogSummary`** — keyless vendor row from static catalog.
class VendorCatalogSummaryV1 {
  const VendorCatalogSummaryV1({
    required this.id,
    required this.name,
    required this.modelCount,
    required this.modelKinds,
  });

  final int id;
  final String name;
  final int modelCount;
  final List<String> modelKinds;

  factory VendorCatalogSummaryV1.fromJson(Map<String, dynamic> json) {
    final kinds = json['modelKinds'];
    return VendorCatalogSummaryV1(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      modelCount: (json['modelCount'] as num).toInt(),
      modelKinds: (kinds is List)
          ? kinds.map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}

/// OpenAPI **`VendorsSummaryResponse`**.
class VendorsSummaryResponseV1 {
  const VendorsSummaryResponseV1({
    required this.vendors,
    required this.source,
  });

  final List<VendorCatalogSummaryV1> vendors;
  final String source;

  factory VendorsSummaryResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['vendors'];
    final list = <VendorCatalogSummaryV1>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(VendorCatalogSummaryV1.fromJson(e));
        }
      }
    }
    return VendorsSummaryResponseV1(
      vendors: list,
      source: json['source'] as String,
    );
  }
}

/// `GET /api/v1/settings/vendors/summary` — OpenAPI `getSettingsVendorsSummaryV1`.
Future<VendorsSummaryResponseV1> fetchVendorsSummaryV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VendorsSummaryResponseV1.fromJson(map);
}

/// `GET /api/v1/models/detail?model_id=…` — Bearer; see `modelDetailV1`.
Future<ModelDetailResponse> fetchModelDetail(
  String accessToken, {
  required String modelId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models/detail').replace(
    queryParameters: {'model_id': modelId},
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ModelDetailResponse.fromJson(map);
}

/// OpenAPI **`TextModelDefaultResponse`** — legacy **`getTextModel`** stub + default composite id.
class TextModelDefaultV1 {
  const TextModelDefaultV1({
    required this.legacyPlaceholder,
    required this.defaultModelId,
  });

  final String legacyPlaceholder;
  final String defaultModelId;

  factory TextModelDefaultV1.fromJson(Map<String, dynamic> json) {
    return TextModelDefaultV1(
      legacyPlaceholder: json['legacy_placeholder'] as String,
      defaultModelId: json['default_model_id'] as String,
    );
  }
}

/// `GET /api/v1/models/text-default` — OpenAPI `getTextModelDefaultV1`.
Future<TextModelDefaultV1> fetchTextModelDefaultV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models/text-default');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return TextModelDefaultV1.fromJson(map);
}

/// `POST /api/v1/agents/memory/query` — camelCase body; see `queryAgentMemoryV1`.
Future<List<dynamic>> queryAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/query');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'episodesId': episodesId,
  };
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return jsonDecode(res.body) as List<dynamic>;
}

/// `POST /api/v1/agents/memory/clear` — OpenAPI `clearAgentMemoryV1` (**`clearType`**: `all` | `message` | `summary`).
///
/// Legacy **`type`** is also accepted by the server as an alias for **`clearType`**.
Future<bool> clearAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
  String clearType = 'all',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/clear');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'clearType': clearType,
  };
  if (episodesId != null) body['episodesId'] = episodesId;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['ok'] == true;
}

/// `POST /api/v1/agents/memory/append` — OpenAPI `appendAgentMemoryV1`; returns new message UUID.
Future<String> appendAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  required String content,
  int? episodesId,
  String role = 'user',
  String? name,
  int? createTime,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/append');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'content': content,
    'role': role,
  };
  if (episodesId != null) body['episodesId'] = episodesId;
  if (name != null) body['name'] = name;
  if (createTime != null) body['createTime'] = createTime;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['id'] as String;
}

/// `GET /api/v1/projects` — projects owned by the JWT subject. See `listProjectsV1`.
Future<List<ProjectRow>> fetchProjects(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/general/get-single-project` — legacy **`getSingleProject`**; **`id`** = **`app_project.legacy_id`**.
Future<List<ProjectRow>> postGeneralGetSingleProject(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/general/get-single-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': legacyId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/general/update-project` — legacy **`updateProject`**.
///
/// [body] must include **`id`** (legacy project id) and at least one of **`intro`**,
/// **`type`**, **`artStyle`**, **`videoRatio`**, **`projectType`** (use JSON **`null`** in the map to clear).
Future<String> postGeneralUpdateProject(
  String accessToken,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/general/update-project');
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

// --- Legacy `POST /api/v1/tasks/*` (Electron task center) ---

class LegacyTasksProjectItem {
  const LegacyTasksProjectItem({required this.id, required this.name});

  /// `app_project.legacy_id`.
  final int id;
  final String name;

  factory LegacyTasksProjectItem.fromJson(Map<String, dynamic> json) {
    return LegacyTasksProjectItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}

class LegacyTasksTaskClassRow {
  const LegacyTasksTaskClassRow({required this.taskClass});

  /// Same as `app_generation_job.kind`.
  final String taskClass;

  factory LegacyTasksTaskClassRow.fromJson(Map<String, dynamic> json) {
    return LegacyTasksTaskClassRow(
      taskClass: json['taskClass'] as String,
    );
  }
}

class LegacyTasksGetTaskApiResult {
  const LegacyTasksGetTaskApiResult({required this.data, required this.total});

  final List<JobRow> data;
  final int total;

  factory LegacyTasksGetTaskApiResult.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>;
    return LegacyTasksGetTaskApiResult(
      data: list
          .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/tasks/get-project` — body `{}`, projects with non-empty names.
Future<List<LegacyTasksProjectItem>> postTasksGetProject(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/get-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => LegacyTasksProjectItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/tasks/get-task-categories` — distinct job kinds as `taskClass`.
Future<List<LegacyTasksTaskClassRow>> postTasksGetTaskCategories(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/get-task-categories');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => LegacyTasksTaskClassRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/tasks/get-task-api` — paginated `app_generation_job` with legacy filters.
Future<LegacyTasksGetTaskApiResult> postTasksGetTaskApi(
  String accessToken, {
  required int page,
  required int limit,
  String? state,
  String? taskClass,
  int? projectId,
}) async {
  final body = <String, dynamic>{
    'page': page,
    'limit': limit,
  };
  if (state != null) body['state'] = state;
  if (taskClass != null) body['taskClass'] = taskClass;
  if (projectId != null) body['projectId'] = projectId;
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/get-task-api');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyTasksGetTaskApiResult.fromJson(map);
}

/// `POST /api/v1/tasks/task-details` with numeric [taskId] — completes without error when the server
/// returns **501** (legacy SQLite `o_tasks.id` does not map to job UUIDs). For a job UUID, call
/// [fetchJob] or POST the same path with `{"taskId":"<uuid>"}` and expect **200**/404/503.
Future<void> postTasksTaskDetails(
  String accessToken,
  int taskId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/task-details');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'taskId': taskId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 501) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

// --- Legacy `POST /api/v1/project/*` (Electron project CRUD helpers) ---

/// `POST /api/v1/project/get-project` — body `{}`; same rows as `GET /api/v1/projects`.
Future<List<ProjectRow>> postProjectGetProject(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/get-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/project/delete-project` — [legacyId] is `app_project.legacy_id`.
Future<String> postProjectDeleteProject(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/delete-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': legacyId}),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/project/add-project` — all fields required (may be empty strings).
Future<String> postProjectAddProject(
  String accessToken, {
  required String projectType,
  required String name,
  required String intro,
  required String type,
  required String artStyle,
  required String directorManual,
  required String videoRatio,
  required String imageModel,
  required String videoModel,
  required String imageQuality,
  required String mode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/add-project');
  final body = <String, dynamic>{
    'projectType': projectType,
    'name': name,
    'intro': intro,
    'type': type,
    'artStyle': artStyle,
    'directorManual': directorManual,
    'videoRatio': videoRatio,
    'imageModel': imageModel,
    'videoModel': videoModel,
    'imageQuality': imageQuality,
    'mode': mode,
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/project/edit-project` — [id] is `app_project.legacy_id`.
Future<String> postProjectEditProject(
  String accessToken, {
  required int id,
  required String name,
  required String intro,
  required String type,
  required String artStyle,
  required String directorManual,
  required String videoRatio,
  required String imageModel,
  required String videoModel,
  required String imageQuality,
  required String projectType,
  required String mode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/edit-project');
  final body = <String, dynamic>{
    'id': id,
    'name': name,
    'intro': intro,
    'type': type,
    'artStyle': artStyle,
    'directorManual': directorManual,
    'videoRatio': videoRatio,
    'imageModel': imageModel,
    'videoModel': videoModel,
    'imageQuality': imageQuality,
    'projectType': projectType,
    'mode': mode,
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// OpenAPI **`LegacyDirectorManualDataSlot`** (also used for visual manual POST bodies).
class LegacyDirectorManualDataSlot {
  const LegacyDirectorManualDataSlot({
    required this.label,
    required this.value,
    required this.data,
  });

  final String label;
  final String value;
  final String data;

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'data': data,
      };

  factory LegacyDirectorManualDataSlot.fromJson(Map<String, dynamic> json) {
    return LegacyDirectorManualDataSlot(
      label: json['label'] as String,
      value: json['value'] as String,
      data: json['data'] as String,
    );
  }
}

/// OpenAPI **`LegacyDirectorManualStyleRow`** (`directorManual` = folder under `story_skills`).
class LegacyDirectorManualStyleRow {
  const LegacyDirectorManualStyleRow({
    required this.name,
    required this.image,
    required this.directorManual,
    required this.data,
  });

  final String name;
  final List<String> image;
  final String directorManual;
  final List<LegacyDirectorManualDataSlot> data;

  factory LegacyDirectorManualStyleRow.fromJson(Map<String, dynamic> json) {
    final imgs = json['image'] as List<dynamic>? ?? const [];
    final slots = json['data'] as List<dynamic>? ?? const [];
    return LegacyDirectorManualStyleRow(
      name: json['name'] as String,
      image: imgs.map((e) => e as String).toList(),
      directorManual: json['directorManual'] as String,
      data: slots
          .map(
            (e) => LegacyDirectorManualDataSlot.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// OpenAPI **`LegacyDirectorManualListResponse`**.
class LegacyDirectorManualListResponse {
  const LegacyDirectorManualListResponse({required this.data});

  final List<LegacyDirectorManualStyleRow> data;

  factory LegacyDirectorManualListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return LegacyDirectorManualListResponse(
      data: raw
          .map(
            (e) => LegacyDirectorManualStyleRow.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

void _expectLegacyEmptyObjectResponse(http.Response res) {
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw RustApiException('expected JSON object', statusCode: res.statusCode);
  }
  if (decoded.isNotEmpty) {
    throw RustApiException(
      'expected empty object {{}}, got $decoded',
      statusCode: res.statusCode,
    );
  }
}

/// `POST /api/v1/project/query-director-manual` — body `{}`; bundled **`story_skills`** rows.
Future<LegacyDirectorManualListResponse> postProjectQueryDirectorManual(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/query-director-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyDirectorManualListResponse.fromJson(map);
}

/// `POST /api/v1/project/add-director-manual`.
Future<void> postProjectAddDirectorManual(
  String accessToken, {
  required String name,
  required String directorManual,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/add-director-manual');
  final body = <String, dynamic>{
    'name': name,
    'directorManual': directorManual,
    'images': images,
    'data': data.map((e) => e.toJson()).toList(),
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  _expectLegacyEmptyObjectResponse(res);
}

/// `POST /api/v1/project/edit-director-manual`.
Future<void> postProjectEditDirectorManual(
  String accessToken, {
  required String name,
  required String directorManual,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/edit-director-manual');
  final body = <String, dynamic>{
    'name': name,
    'directorManual': directorManual,
    'images': images,
    'data': data.map((e) => e.toJson()).toList(),
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  _expectLegacyEmptyObjectResponse(res);
}

/// `POST /api/v1/project/delete-director-manual` — [folderName] is folder under **`story_skills`**.
Future<String> postProjectDeleteDirectorManual(
  String accessToken,
  String folderName,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/delete-director-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': folderName}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/project/add-visual-manual`.
Future<void> postProjectAddVisualManual(
  String accessToken, {
  required String name,
  required String stylePath,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/add-visual-manual');
  final body = <String, dynamic>{
    'name': name,
    'stylePath': stylePath,
    'images': images,
    'data': data.map((e) => e.toJson()).toList(),
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  _expectLegacyEmptyObjectResponse(res);
}

/// `POST /api/v1/project/edit-visual-manual`.
Future<void> postProjectEditVisualManual(
  String accessToken, {
  required String name,
  required String stylePath,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/edit-visual-manual');
  final body = <String, dynamic>{
    'name': name,
    'stylePath': stylePath,
    'images': images,
    'data': data.map((e) => e.toJson()).toList(),
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  _expectLegacyEmptyObjectResponse(res);
}

/// `POST /api/v1/project/delete-visual-manual` — [folderName] is folder under **`art_skills`**.
Future<String> postProjectDeleteVisualManual(
  String accessToken,
  String folderName,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/delete-visual-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': folderName}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

class ProjectsSummary {
  const ProjectsSummary({
    required this.projectCount,
    required this.scriptCount,
    required this.storyboardCount,
    required this.novelCount,
    required this.roleCount,
    required this.artStyleCount,
    required this.assetCount,
    required this.videoCount,
  });

  final int projectCount;
  final int scriptCount;
  final int storyboardCount;
  final int novelCount;
  final int roleCount;
  final int artStyleCount;
  final int assetCount;
  final int videoCount;

  factory ProjectsSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return ProjectsSummary(
      projectCount: n('project_count'),
      scriptCount: n('script_count'),
      storyboardCount: n('storyboard_count'),
      novelCount: json['novel_count'] != null
          ? (json['novel_count'] as num).toInt()
          : 0,
      roleCount: json['role_count'] != null
          ? (json['role_count'] as num).toInt()
          : 0,
      artStyleCount: json['art_style_count'] != null
          ? (json['art_style_count'] as num).toInt()
          : 0,
      assetCount: json['asset_count'] != null
          ? (json['asset_count'] as num).toInt()
          : 0,
      videoCount: json['video_count'] != null
          ? (json['video_count'] as num).toInt()
          : 0,
    );
  }
}

/// `GET /api/v1/projects/summary` — totals for the caller. See `getProjectsSummaryV1`.
Future<ProjectsSummary> fetchProjectsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectsSummary.fromJson(map);
}

/// `GET /api/v1/art-styles` — see `listArtStylesV1`.
Future<ListArtStylesResponse> fetchArtStyles(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListArtStylesResponse.fromJson(map);
}

/// `POST /api/v1/art-styles` — OpenAPI `createArtStyleV1` (**201** + row).
Future<ArtStyleRow> createArtStyle(
  String accessToken, {
  required String name,
  String? fileUrl,
  String? label,
  String? prompt,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles');
  final body = <String, dynamic>{'name': name};
  if (fileUrl != null) body['file_url'] = fileUrl;
  if (label != null) body['label'] = label;
  if (prompt != null) body['prompt'] = prompt;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ArtStyleRow.fromJson(map);
}

/// `GET /api/v1/art-styles/legacy/{legacy_id}` — OpenAPI `getArtStyleByLegacyIdV1`.
Future<ArtStyleRow> fetchArtStyleByLegacyId(
  String accessToken, {
  required int legacyId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/legacy/$legacyId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ArtStyleRow.fromJson(map);
}

/// `PATCH /api/v1/art-styles/legacy/{legacy_id}` — OpenAPI `patchArtStyleByLegacyIdV1`.
///
/// [body] uses **snake_case** keys only: **`name`**, **`file_url`**, **`label`**, **`prompt`**.
/// At least one key is required; use JSON **`null`** or empty string for optional fields to clear them.
Future<ArtStyleRow> patchArtStyleByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  if (body.isEmpty) {
    throw ArgumentError('patch body must include at least one allowed field');
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/legacy/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ArtStyleRow.fromJson(map);
}

/// `DELETE /api/v1/art-styles/legacy/{legacy_id}` — OpenAPI `deleteArtStyleByLegacyIdV1` (**204**).
Future<void> deleteArtStyleByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/legacy/$legacyId');
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `POST /api/v1/art-styles/extract-prompt` — vision LLM; see `extractArtStylePromptV1`.
///
/// [images] are passed through as OpenAPI **`image_url.url`** strings (HTTPS or data URI).
Future<ExtractArtStylePromptResponse> extractArtStylePrompt(
  String accessToken,
  List<String> images,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/extract-prompt');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'images': images}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ExtractArtStylePromptResponse.fromJson(map);
}

/// `POST /api/v1/projects` — optional snake_case fields; see `createProjectV1`.
Future<ProjectRow> createProject(
  String accessToken, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(fields ?? <String, dynamic>{}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{legacy_id}` — merge patch for `name` / `intro` only.
///
/// [body] must only include keys allowed by OpenAPI `PatchProjectBody` (unknown keys → HTTP 400).
/// See `patchProjectByLegacyIdV1`.
Future<ProjectRow> updateProjectByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{legacy_id}` — see `deleteProjectByLegacyIdV1`.
Future<void> deleteProjectByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

class ScriptRow {
  const ScriptRow({
    required this.id,
    required this.projectId,
    required this.legacyId,
    this.name,
    this.content,
    this.extractState,
    this.createTimeMs,
  });

  final String id;
  final String projectId;
  final int legacyId;
  final String? name;
  final String? content;
  final int? extractState;
  final int? createTimeMs;

  factory ScriptRow.fromJson(Map<String, dynamic> json) {
    return ScriptRow(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String?,
      content: json['content'] as String?,
      extractState: json['extract_state'] == null
          ? null
          : (json['extract_state'] as num).toInt(),
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// Linked asset brief on **`POST /api/v1/scripts/get-script-api`** — JSON **`id`** = **`app_asset.legacy_id`**.
class LegacyScriptRelatedAssetBrief {
  const LegacyScriptRelatedAssetBrief({
    required this.legacyId,
    required this.name,
  });

  final int legacyId;
  final String name;

  factory LegacyScriptRelatedAssetBrief.fromJson(Map<String, dynamic> json) {
    return LegacyScriptRelatedAssetBrief(
      legacyId: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}

/// One script row from **`POST /api/v1/scripts/get-script-api`** (camelCase **`extractState`**, **`relatedAssets`**, …).
class LegacyScriptsGetScriptApiItem {
  const LegacyScriptsGetScriptApiItem({
    required this.legacyId,
    this.name,
    this.content,
    this.extractState,
    this.errorReason,
    this.createTime,
    required this.relatedAssets,
  });

  final int legacyId;
  final String? name;
  final String? content;
  final int? extractState;
  final String? errorReason;
  final int? createTime;
  final List<LegacyScriptRelatedAssetBrief> relatedAssets;

  factory LegacyScriptsGetScriptApiItem.fromJson(Map<String, dynamic> json) {
    final raw = json['relatedAssets'] as List<dynamic>? ?? [];
    return LegacyScriptsGetScriptApiItem(
      legacyId: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      content: json['content'] as String?,
      extractState: json['extractState'] == null
          ? null
          : (json['extractState'] as num).toInt(),
      errorReason: json['errorReason'] as String?,
      createTime: json['createTime'] == null
          ? null
          : (json['createTime'] as num).toInt(),
      relatedAssets: raw
          .map(
            (e) => LegacyScriptRelatedAssetBrief.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// `POST /api/v1/scripts/get-script-api` — legacy **`getScrptApi`** list + **`relatedAssets`**.
Future<List<LegacyScriptsGetScriptApiItem>> postScriptsGetScriptApi(
  String accessToken,
  int projectId, {
  String? name,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/get-script-api');
  final body = <String, dynamic>{'projectId': projectId};
  if (name != null && name.isNotEmpty) {
    body['name'] = name;
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
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map(
        (e) => LegacyScriptsGetScriptApiItem.fromJson(e as Map<String, dynamic>),
      )
      .toList();
}

/// `GET /api/v1/scripts/legacy/{legacy_id}`. See `getScriptByLegacyIdV1`.
Future<ScriptRow> fetchScriptByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/legacy/$legacyId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ScriptRow.fromJson(map);
}

/// `PATCH /api/v1/scripts/legacy/{legacy_id}` — only `name`, `content`, `extract_state`.
///
/// Unknown keys → HTTP 400. See `patchScriptByLegacyIdV1`.
Future<ScriptRow> updateScriptByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/legacy/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ScriptRow.fromJson(map);
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/scripts` — see `createScriptUnderProjectLegacyV1`.
Future<ScriptRow> createScriptUnderProjectLegacy(
  String accessToken,
  int projectLegacyId, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/scripts',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(fields ?? <String, dynamic>{}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ScriptRow.fromJson(map);
}

/// `DELETE /api/v1/scripts/legacy/{legacy_id}` — see `deleteScriptByLegacyIdV1`.
Future<void> deleteScriptByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/legacy/$legacyId');
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `POST /api/v1/scripts/export` — **`application/zip`** body. See `exportScriptsZipV1`.
Future<Uint8List> exportScriptsZip(
  String accessToken,
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/export');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'legacy_ids': legacyIds}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.bodyBytes;
}

/// Row from **`POST /api/v1/scripts/extract-state/poll`** — OpenAPI **`ScriptExtractStatePollRow`**.
class ScriptExtractStatePollRow {
  const ScriptExtractStatePollRow({
    required this.legacyId,
    this.extractState,
    this.errorReason,
  });

  final int legacyId;
  final int? extractState;
  final String? errorReason;

  factory ScriptExtractStatePollRow.fromJson(Map<String, dynamic> json) {
    return ScriptExtractStatePollRow(
      legacyId: (json['legacy_id'] as num).toInt(),
      extractState: json['extract_state'] == null
          ? null
          : (json['extract_state'] as num).toInt(),
      errorReason: json['error_reason'] as String?,
    );
  }
}

/// `POST /api/v1/scripts/extract-state/poll` — scripts with **`extract_state` ≠ 0**. See `pollScriptExtractStateV1`.
Future<List<ScriptExtractStatePollRow>> pollScriptExtractState(
  String accessToken,
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-state/poll');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'legacy_ids': legacyIds}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map(
        (e) =>
            ScriptExtractStatePollRow.fromJson(e as Map<String, dynamic>),
      )
      .toList();
}

/// `POST /api/v1/scripts/extract-assets` — OpenAPI **`ExtractAssetsAcceptedResponse`** (async job).
class ExtractAssetsAcceptedResponse {
  const ExtractAssetsAcceptedResponse({
    required this.status,
    required this.message,
  });

  final String status;
  final String message;

  factory ExtractAssetsAcceptedResponse.fromJson(Map<String, dynamic> json) {
    return ExtractAssetsAcceptedResponse(
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/scripts/extract-assets` — background LLM extraction (**503** if LLM/DB unset). See `startScriptAssetExtractV1`.
Future<ExtractAssetsAcceptedResponse> startScriptAssetExtract(
  String accessToken, {
  required int projectLegacyId,
  required List<int> scriptLegacyIds,
  int? groupSize,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-assets');
  final body = <String, dynamic>{
    'project_legacy_id': projectLegacyId,
    'script_legacy_ids': scriptLegacyIds,
  };
  if (groupSize != null) {
    body['group_size'] = groupSize;
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ExtractAssetsAcceptedResponse.fromJson(map);
}

class StoryboardRow {
  const StoryboardRow({
    required this.id,
    required this.scriptId,
    required this.legacyId,
    this.legacyScriptId,
    this.prompt,
    this.filePath,
    this.duration,
    this.state,
    this.trackId,
    this.reason,
    this.track,
    this.videoDesc,
    this.shouldGenerateImage,
    this.legacyProjectId,
    this.flowId,
    this.sbIndex,
    this.createTimeMs,
  });

  final String id;
  final String scriptId;
  final int legacyId;
  final int? legacyScriptId;
  final String? prompt;
  final String? filePath;
  final String? duration;
  final String? state;
  final int? trackId;
  final String? reason;
  final String? track;
  final String? videoDesc;
  final int? shouldGenerateImage;
  final int? legacyProjectId;
  final int? flowId;
  final int? sbIndex;
  final int? createTimeMs;

  factory StoryboardRow.fromJson(Map<String, dynamic> json) {
    int? ni(String k) => json[k] == null ? null : (json[k] as num).toInt();
    return StoryboardRow(
      id: json['id'] as String,
      scriptId: json['script_id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      legacyScriptId: ni('legacy_script_id'),
      prompt: json['prompt'] as String?,
      filePath: json['file_path'] as String?,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId: ni('track_id'),
      reason: json['reason'] as String?,
      track: json['track'] as String?,
      videoDesc: json['video_desc'] as String?,
      shouldGenerateImage: ni('should_generate_image'),
      legacyProjectId: ni('legacy_project_id'),
      flowId: ni('flow_id'),
      sbIndex: ni('sb_index'),
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/scripts/legacy/{script_legacy_id}/storyboards`. See `listStoryboardsByScriptLegacyIdV1`.
Future<List<StoryboardRow>> fetchStoryboardsForScript(
  String accessToken,
  int scriptLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/scripts/legacy/$scriptLegacyId/storyboards',
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => StoryboardRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/scripts/legacy/{script_legacy_id}/storyboards` — see `createStoryboardUnderScriptLegacyV1`.
Future<StoryboardRow> createStoryboardUnderScriptLegacy(
  String accessToken,
  int scriptLegacyId, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/scripts/legacy/$scriptLegacyId/storyboards',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(fields ?? <String, dynamic>{}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `GET /api/v1/storyboards/legacy/{legacy_id}`. See `getStoryboardByLegacyIdV1`.
Future<StoryboardRow> fetchStoryboardByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/storyboards/legacy/$legacyId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `PATCH /api/v1/storyboards/legacy/{legacy_id}` — keys per OpenAPI `PatchStoryboardBody` only.
///
/// Unknown keys → HTTP 400. See `patchStoryboardByLegacyIdV1`.
Future<StoryboardRow> updateStoryboardByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/storyboards/legacy/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `DELETE /api/v1/storyboards/legacy/{legacy_id}` — see `deleteStoryboardByLegacyIdV1`.
Future<void> deleteStoryboardByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/storyboards/legacy/$legacyId');
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

class SkillFileMeta {
  const SkillFileMeta({
    required this.path,
    required this.sizeBytes,
  });

  final String path;
  final int sizeBytes;

  factory SkillFileMeta.fromJson(Map<String, dynamic> json) {
    return SkillFileMeta(
      path: json['path'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/skills/summary`. See `getSkillsSummaryV1`.
class SkillsSummary {
  const SkillsSummary({
    required this.markdownFileCount,
    required this.totalBytes,
  });

  final int markdownFileCount;
  final int totalBytes;

  factory SkillsSummary.fromJson(Map<String, dynamic> json) {
    return SkillsSummary(
      markdownFileCount: (json['markdown_file_count'] as num).toInt(),
      totalBytes: (json['total_bytes'] as num).toInt(),
    );
  }
}

class SkillContentResponse {
  const SkillContentResponse({
    required this.path,
    required this.content,
  });

  final String path;
  final String content;

  factory SkillContentResponse.fromJson(Map<String, dynamic> json) {
    return SkillContentResponse(
      path: json['path'] as String,
      content: json['content'] as String,
    );
  }
}

class HarnessToolInfo {
  const HarnessToolInfo({required this.name, required this.description});

  final String name;
  final String description;

  factory HarnessToolInfo.fromJson(Map<String, dynamic> json) {
    return HarnessToolInfo(
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }
}

class HarnessToolsResponse {
  const HarnessToolsResponse({required this.tools});

  final List<HarnessToolInfo> tools;

  factory HarnessToolsResponse.fromJson(Map<String, dynamic> json) {
    return HarnessToolsResponse(
      tools: (json['tools'] as List<dynamic>)
          .map((e) => HarnessToolInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class JobRow {
  const JobRow({
    required this.id,
    required this.ownerUserId,
    required this.kind,
    required this.status,
    required this.payload,
    this.result,
    this.errorMessage,
    this.idempotencyKey,
    this.claimedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String kind;
  final String status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? result;
  final String? errorMessage;
  final String? idempotencyKey;
  /// Worker label when `running` (`WORKER_ID` on server); mirrors OpenAPI `claimed_by`.
  final String? claimedBy;
  final String createdAt;
  final String updatedAt;

  factory JobRow.fromJson(Map<String, dynamic> json) {
    return JobRow(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      kind: json['kind'] as String,
      status: json['status'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      result: json['result'] == null
          ? null
          : Map<String, dynamic>.from(json['result'] as Map),
      errorMessage: json['error_message'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
      claimedBy: json['claimed_by'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}

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
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs').replace(
    queryParameters: qp.isEmpty ? null : qp,
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/jobs/kinds` — distinct kinds for the caller. See `listJobKindsV1`.
Future<List<String>> fetchJobKinds(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/kinds');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .post(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .post(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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

/// `GET /api/v1/skills/summary`. See `getSkillsSummaryV1`.
Future<SkillsSummary> fetchSkillsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillsSummary.fromJson(map);
}

/// `GET /api/v1/skills` — Markdown paths under `data/skills`. See `listSkillsV1`.
Future<List<SkillFileMeta>> fetchSkills(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => SkillFileMeta.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/skills/content?path=…`. See `getSkillContentV1`.
Future<SkillContentResponse> fetchSkillContent(
  String accessToken,
  String relativePath,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content').replace(
    queryParameters: {'path': relativePath},
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `PUT /api/v1/skills/content` — overwrites an **existing** file only (legacy `saveSkillContent`).
/// See `putSkillContentV1`.
Future<SkillContentResponse> saveSkillContent(
  String accessToken,
  String relativePath,
  String content,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content');
  final res = await http
      .put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'path': relativePath, 'content': content}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `POST /api/v1/skills/content` — creates a new file under `data/skills` (**409** if it already exists).
/// See `postSkillContentV1`.
Future<SkillContentResponse> createSkillContent(
  String accessToken,
  String relativePath,
  String content,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'path': relativePath, 'content': content}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 409) {
    throw RustApiException('conflict', statusCode: 409);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `DELETE /api/v1/skills/content?path=…` — removes a regular file only (**204** empty body).
/// See `deleteSkillContentV1`.
Future<void> deleteSkillContent(
  String accessToken,
  String relativePath,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content').replace(
    queryParameters: {'path': relativePath},
  );
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `GET /api/v1/harness/tools`. See `listHarnessToolsV1`.
Future<HarnessToolsResponse> fetchHarnessTools(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/tools');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HarnessToolsResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{legacy_id}` — project plus script briefs. See `getProjectByLegacyIdV1`.
Future<ProjectDetail> fetchProjectByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectDetail.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{legacy_id}/stats` — see `getProjectStatsByLegacyIdV1`.
Future<ProjectStats> fetchProjectStatsByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId/stats');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectStats.fromJson(map);
}

/// Row from **`GET …/projects/legacy/{id}/assets`** — OpenAPI **`AssetRow`**.
class AssetRow {
  const AssetRow({
    required this.id,
    required this.legacyId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;

  factory AssetRow.fromJson(Map<String, dynamic> json) {
    return AssetRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
class NovelRow {
  NovelRow({
    required this.id,
    required this.legacyId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;
  final int? createTimeMs;

  factory NovelRow.fromJson(Map<String, dynamic> json) {
    return NovelRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      chapterIndex: (json['chapter_index'] as num).toInt(),
      reel: json['reel'] as String?,
      chapter: json['chapter'] as String? ?? '',
      chapterData: json['chapter_data'] as String? ?? '',
      event: json['event'] as String?,
      eventState: (json['event_state'] as num).toInt(),
      errorReason: json['error_reason'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// Body of **`GET …/novels`** — OpenAPI **`ListNovelsResponse`**.
class ListNovelsResponse {
  const ListNovelsResponse({
    required this.items,
    required this.total,
  });

  final List<NovelRow> items;
  final int total;

  factory ListNovelsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListNovelsResponse(
      items: raw
          .map((e) => NovelRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// Row from **`POST /api/v1/novels/get-novel-index`** — **`id`** is **`app_novel.legacy_id`**.
class LegacyNovelIndexItem {
  const LegacyNovelIndexItem({
    required this.legacyId,
    required this.chapterIndex,
    required this.chapter,
  });

  final int legacyId;
  final int chapterIndex;
  final String chapter;

  factory LegacyNovelIndexItem.fromJson(Map<String, dynamic> json) {
    return LegacyNovelIndexItem(
      legacyId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      chapter: json['chapter'] as String? ?? '',
    );
  }
}

/// Row from **`POST /api/v1/novels/get-novel`** — response uses **camelCase** (**`chapterData`**, …).
class LegacyNovelPageRow {
  const LegacyNovelPageRow({
    required this.legacyId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
  });

  final int legacyId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;

  factory LegacyNovelPageRow.fromJson(Map<String, dynamic> json) {
    return LegacyNovelPageRow(
      legacyId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      reel: json['reel'] as String?,
      chapter: json['chapter'] as String? ?? '',
      chapterData: json['chapterData'] as String? ?? '',
      event: json['event'] as String?,
      eventState: (json['eventState'] as num).toInt(),
      errorReason: json['errorReason'] as String?,
    );
  }
}

/// **`POST /api/v1/novels/get-novel`** — **`{ data, total }`**.
class LegacyNovelPagedResponse {
  const LegacyNovelPagedResponse({
    required this.data,
    required this.total,
  });

  final List<LegacyNovelPageRow> data;
  final int total;

  factory LegacyNovelPagedResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>;
    return LegacyNovelPagedResponse(
      data: raw
          .map((e) => LegacyNovelPageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One entry for **`POST /api/v1/novels/add-novel`** **`data`** (camelCase **`chapterData`**).
class LegacyNovelAddItem {
  const LegacyNovelAddItem({
    required this.index,
    required this.reel,
    required this.chapter,
    required this.chapterData,
  });

  final int index;
  final String reel;
  final String chapter;
  final String chapterData;

  Map<String, dynamic> toJson() => {
        'index': index,
        'reel': reel,
        'chapter': chapter,
        'chapterData': chapterData,
      };
}

/// Body of **`GET …/assets`** — OpenAPI **`ListAssetsResponse`**.
class ListAssetsResponse {
  const ListAssetsResponse({
    required this.items,
    required this.total,
  });

  final List<AssetRow> items;
  final int total;

  factory ListAssetsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetsResponse(
      items: raw
          .map((e) => AssetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One **`app_asset_image`** row in **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeHistoryImage`**.
class CornerScapeHistoryImage {
  const CornerScapeHistoryImage({
    required this.id,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.legacyImageId,
  });

  final String id;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? legacyImageId;

  factory CornerScapeHistoryImage.fromJson(Map<String, dynamic> json) {
    return CornerScapeHistoryImage(
      id: json['id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      legacyImageId: (json['legacy_image_id'] as num?)?.toInt(),
    );
  }
}

/// One row from **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeAssetItem`**.
class CornerScapeAssetItem {
  const CornerScapeAssetItem({
    required this.id,
    required this.legacyId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
    required this.metadata,
    required this.historyImages,
  });

  final String id;
  final int legacyId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;
  final Map<String, dynamic> metadata;
  final List<CornerScapeHistoryImage> historyImages;

  factory CornerScapeAssetItem.fromJson(Map<String, dynamic> json) {
    final histRaw = json['history_images'] as List<dynamic>? ?? const [];
    final hist = histRaw
        .map(
          (e) =>
              CornerScapeHistoryImage.fromJson(e as Map<String, dynamic>),
        )
        .toList();
    final meta = json['metadata'];
    return CornerScapeAssetItem(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: (json['create_time_ms'] as num?)?.toInt(),
      metadata: meta is Map<String, dynamic>
          ? meta
          : <String, dynamic>{},
      historyImages: hist,
    );
  }
}

/// OpenAPI **`AssetImageRow`** — response from **`POST …/assets/{aid}/images`** (and list items share these fields).
class AssetImageRow {
  const AssetImageRow({
    required this.id,
    required this.assetId,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.legacyImageId,
    this.selected,
  });

  final String id;
  final String assetId;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? legacyImageId;
  /// Present on **`GET …/images`** list items only (`AssetImageListItem`).
  final bool? selected;

  factory AssetImageRow.fromJson(Map<String, dynamic> json) {
    return AssetImageRow(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      legacyImageId: (json['legacy_image_id'] as num?)?.toInt(),
      selected: json['selected'] as bool?,
    );
  }
}

/// OpenAPI **`ListAssetImagesResponse`**.
class ListAssetImagesResponse {
  const ListAssetImagesResponse({
    this.coverLegacyImageId,
    required this.items,
  });

  final int? coverLegacyImageId;
  final List<AssetImageRow> items;

  factory ListAssetImagesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetImagesResponse(
      coverLegacyImageId: (json['cover_legacy_image_id'] as num?)?.toInt(),
      items: raw
          .map((e) => AssetImageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// OpenAPI **`CornerScapeResponse`**.
class CornerScapeResponse {
  const CornerScapeResponse({required this.items});

  final List<CornerScapeAssetItem> items;

  factory CornerScapeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return CornerScapeResponse(
      items: raw
          .map(
            (e) => CornerScapeAssetItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/assets/corner-scape` — see `listCornerScapeAssetsByLegacyV1`.
Future<CornerScapeResponse> fetchCornerScapeAssetsByLegacyId(
  String accessToken,
  int projectLegacyId, {
  List<String>? types,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/corner-scape',
  );
  final body = <String, dynamic>{};
  if (types != null && types.isNotEmpty) {
    body['types'] = types;
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
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return CornerScapeResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images` — see `listProjectAssetImagesByLegacyIdsV1`.
Future<ListAssetImagesResponse> fetchProjectAssetImagesByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images',
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListAssetImagesResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}` — see `getProjectAssetImageByLegacyIdsV1`.
Future<AssetImageRow> fetchProjectAssetImageByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId',
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// Builds `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}/file` — OpenAPI `getProjectAssetImageFileByLegacyIdsV1`.
Uri projectAssetImageFileV1Uri(
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) {
  return Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId/file',
  );
}

/// Fetches image bytes from [`projectAssetImageFileV1Uri`].
///
/// When **`file_path`** is **`https?`**, the server responds with **307**; this client follows redirects and returns the final body (**`200`**).
/// Rows without **`https?`** **`file_path`** and without **`metadata.storage == local`** typically yield **404** from this route.
Future<Uint8List> fetchProjectAssetImageFileByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) async {
  final uri =
      projectAssetImageFileV1Uri(projectLegacyId, assetLegacyId, imageId);
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(
      res.body.isNotEmpty ? res.body : 'binary response ${res.statusCode}',
      statusCode: res.statusCode,
    );
  }
  return res.bodyBytes;
}

/// Loads image bytes for a corner-scape **`history_images`** row.
///
/// **`file_path`** starting with **`http://`** / **`https://`**: plain **GET** (provider URLs).
/// Otherwise: **[fetchProjectAssetImageFileByLegacyIds]** (JWT; **307** follow, **local** PNG, etc.).
/// Returns **`null`** on missing path or transport/HTTP failure.
Future<Uint8List?> fetchCornerScapeHistoryImagePreviewBytes(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  CornerScapeHistoryImage img,
) async {
  final fp = img.filePath;
  if (fp == null || fp.isEmpty) return null;
  final t = fp.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) {
    try {
      final res = await http
          .get(Uri.parse(t))
          .timeout(const Duration(seconds: 120));
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }
  try {
    return await fetchProjectAssetImageFileByLegacyIds(
      accessToken,
      projectLegacyId,
      assetLegacyId,
      img.id,
    );
  } on RustApiException {
    return null;
  }
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images` — see `createProjectAssetImageByLegacyIdsV1`.
Future<AssetImageRow> createProjectAssetImage(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId, {
  String? filePath,
  String? state,
  int? sortIndex,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images',
  );
  final body = <String, dynamic>{};
  if (filePath != null) {
    body['file_path'] = filePath;
  }
  if (state != null) {
    body['state'] = state;
  }
  if (sortIndex != null) {
    body['sort_index'] = sortIndex;
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
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}` — see `patchProjectAssetImageByLegacyIdsV1`.
///
/// [body] must match OpenAPI **`PatchAssetImageBody`** (at least one of **`file_path`**, **`state`**, **`sort_index`**).
Future<AssetImageRow> patchProjectAssetImageByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId',
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
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}` — see `deleteProjectAssetImageByLegacyIdsV1`.
Future<void> deleteProjectAssetImageByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId',
  );
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets` — see `listProjectAssetsByLegacyV1`.
Future<ListAssetsResponse> fetchProjectAssetsByLegacyId(
  String accessToken,
  int projectLegacyId, {
  int? scriptLegacyId,
  String? assetType,
  String? name,
  int? page,
  int? limit,
}) async {
  final qp = <String, String>{};
  if (scriptLegacyId != null) {
    qp['script_legacy_id'] = '$scriptLegacyId';
  }
  if (assetType != null && assetType.isNotEmpty) {
    qp['asset_type'] = assetType;
  }
  if (name != null && name.isNotEmpty) {
    qp['name'] = name;
  }
  if (page != null) {
    qp['page'] = '$page';
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  var uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets',
  );
  if (qp.isNotEmpty) {
    uri = uri.replace(queryParameters: qp);
  }
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListAssetsResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}` — see `getProjectAssetByLegacyIdsV1`.
Future<AssetRow> fetchProjectAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId',
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetRow.fromJson(map);
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/assets` — see `createProjectAssetByLegacyV1`.
Future<AssetRow> createProjectAssetUnderLegacy(
  String accessToken,
  int projectLegacyId, {
  required String name,
  required String type,
  String? description,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets');
  final body = <String, dynamic>{'name': name, 'type': type};
  if (description != null) {
    body['description'] = description;
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
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 409) {
    throw RustApiException(res.body, statusCode: 409);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}` — see `patchProjectAssetByLegacyIdsV1`.
///
/// [body] must match OpenAPI **`PatchAssetBody`** (**`name`** / **`description`** / **`asset_type`** / **`cover_legacy_image_id`**).
Future<AssetRow> patchProjectAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId',
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
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}` — see `deleteProjectAssetByLegacyIdsV1`.
Future<void> deleteProjectAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId',
  );
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/novels` — see `listProjectNovelsByLegacyV1`.
Future<ListNovelsResponse> fetchProjectNovelsByLegacyId(
  String accessToken,
  int projectLegacyId, {
  String? search,
  int? page,
  int? limit,
}) async {
  final qp = <String, String>{};
  if (search != null && search.isNotEmpty) {
    qp['search'] = search;
  }
  if (page != null) {
    qp['page'] = '$page';
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  var uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels',
  );
  if (qp.isNotEmpty) {
    uri = uri.replace(queryParameters: qp);
  }
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListNovelsResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/novels/{novel_legacy_id}` — see `getProjectNovelByLegacyIdsV1`.
Future<NovelRow> fetchProjectNovelByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int novelLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels/$novelLegacyId',
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/novels` — see `createProjectNovelByLegacyV1`.
Future<NovelRow> createProjectNovelUnderLegacy(
  String accessToken,
  int projectLegacyId, {
  int? chapterIndex,
  String? reel,
  String? chapter,
  String? chapterData,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels');
  final body = <String, dynamic>{};
  if (chapterIndex != null) {
    body['chapter_index'] = chapterIndex;
  }
  if (reel != null) {
    body['reel'] = reel;
  }
  if (chapter != null) {
    body['chapter'] = chapter;
  }
  if (chapterData != null) {
    body['chapter_data'] = chapterData;
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
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{project_legacy_id}/novels/{novel_legacy_id}` — see `patchProjectNovelByLegacyIdsV1`.
Future<NovelRow> patchProjectNovelByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int novelLegacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels/$novelLegacyId',
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
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{project_legacy_id}/novels/{novel_legacy_id}` — see `deleteProjectNovelByLegacyIdsV1`.
Future<void> deleteProjectNovelByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int novelLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels/$novelLegacyId',
  );
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `POST /api/v1/novels/get-novel-data` — full **`NovelRow`** list (legacy Electron **`getNovelData`**).
Future<List<NovelRow>> postLegacyNovelsGetNovelData(
  String accessToken,
  int projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/get-novel-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['data'] as List<dynamic>;
  return raw.map((e) => NovelRow.fromJson(e as Map<String, dynamic>)).toList();
}

/// `POST /api/v1/novels/get-novel-index` — **`{ id, index, chapter }`** per row (**`getNovelIndex`**).
Future<List<LegacyNovelIndexItem>> postLegacyNovelsGetNovelIndex(
  String accessToken,
  int projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/get-novel-index');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['data'] as List<dynamic>;
  return raw
      .map((e) => LegacyNovelIndexItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/novels/get-novel` — paginated list + **`total`** (**`getNovel`**).
Future<LegacyNovelPagedResponse> postLegacyNovelsGetNovel(
  String accessToken,
  int projectId, {
  required int page,
  required int limit,
  String? search,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/get-novel');
  final body = <String, dynamic>{
    'projectId': projectId,
    'page': page,
    'limit': limit,
  };
  if (search != null && search.isNotEmpty) {
    body['search'] = search;
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyNovelPagedResponse.fromJson(map);
}

/// `POST /api/v1/novels/add-novel` — returns Chinese **`message`** (empty **`data`** is OK without DB).
Future<String> postLegacyNovelsAddNovel(
  String accessToken,
  int projectId,
  List<LegacyNovelAddItem> data,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/add-novel');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'data': data.map((e) => e.toJson()).toList(),
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/novels/delete-novel` — body **`{ "id": legacy_id }`**.
Future<String> postLegacyNovelsDeleteNovel(
  String accessToken,
  int novelLegacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/delete-novel');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': novelLegacyId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/novels/update-novel` — **`index`** may be int or numeric string.
Future<String> postLegacyNovelsUpdateNovel(
  String accessToken, {
  required int id,
  required Object index,
  required String reel,
  required String chapter,
  required String chapterData,
  required String event,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/update-novel');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'index': index,
          'reel': reel,
          'chapter': chapter,
          'chapterData': chapterData,
          'event': event,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/novels/batch-delete` — **`ids`** = **`app_novel.legacy_id`** (max **500**; empty → **400**).
Future<String> postLegacyNovelsBatchDelete(
  String accessToken,
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/batch-delete');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': legacyIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `PUT …/scripts/{script_legacy_id}/assets/{asset_legacy_id}` — link script to asset (`app_script_asset`).
Future<void> linkScriptToAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int scriptLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/scripts/$scriptLegacyId/assets/$assetLegacyId',
  );
  final res = await http
      .put(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `DELETE …/scripts/{script_legacy_id}/assets/{asset_legacy_id}` — remove link (404 if link absent).
Future<void> unlinkScriptFromAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int scriptLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/scripts/$scriptLegacyId/assets/$assetLegacyId',
  );
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

// =============================================================================
// Production API Bindings (Wave E - Fully Implemented)
// =============================================================================

/// OpenAPI **`BatchGenerateImageItem`** — single item for batch image generation.
class BatchGenerateImageItem {
  const BatchGenerateImageItem({
    required this.storyboardId,
    required this.prompt,
    this.negativePrompt,
    this.model,
    this.resolution,
  });

  final int storyboardId;
  final String prompt;
  final String? negativePrompt;
  final String? model;
  final String? resolution;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'storyboardId': storyboardId,
      'prompt': prompt,
    };
    if (negativePrompt != null) json['negativePrompt'] = negativePrompt;
    if (model != null) json['model'] = model;
    if (resolution != null) json['resolution'] = resolution;
    return json;
  }
}

/// OpenAPI **`BatchGenerateImageResponse`** — enqueued jobs.
class BatchGenerateImageResponse {
  const BatchGenerateImageResponse({
    required this.enqueued,
    required this.total,
  });

  final List<JobRow> enqueued;
  final int total;

  factory BatchGenerateImageResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['enqueued'] as List<dynamic>? ?? const [];
    return BatchGenerateImageResponse(
      enqueued: raw
          .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/production/storyboard/batch-generate-image` — OpenAPI `postStoryboardBatchGenerateImageV1`.
Future<BatchGenerateImageResponse> postStoryboardBatchGenerateImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<BatchGenerateImageItem> items,
  String? model,
  String? resolution,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/batch-generate-image');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'items': items.map((e) => e.toJson()).toList(),
  };
  if (model != null) body['model'] = model;
  if (resolution != null) body['resolution'] = resolution;
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
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchGenerateImageResponse.fromJson(map);
}

/// OpenAPI **`VideoItem`** — video in workbench list.
class VideoItem {
  const VideoItem({
    required this.id,
    this.scriptId,
    this.prompt,
    this.videoUrl,
    this.duration,
    this.state,
    this.trackId,
    this.createdAt,
  });

  final int id;
  final int? scriptId;
  final String? prompt;
  final String? videoUrl;
  final String? duration;
  final String? state;
  final int? trackId;
  final DateTime? createdAt;

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    final raw = json['createdAt'];
    if (raw is String) {
      parsed = DateTime.tryParse(raw);
    }
    return VideoItem(
      id: (json['id'] as num).toInt(),
      scriptId: json['scriptId'] == null
          ? null
          : (json['scriptId'] as num).toInt(),
      prompt: json['prompt'] as String?,
      videoUrl: json['videoUrl'] as String?,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId: json['trackId'] == null
          ? null
          : (json['trackId'] as num).toInt(),
      createdAt: parsed,
    );
  }
}

/// OpenAPI **`VideoListResponse`**.
class VideoListResponse {
  const VideoListResponse({
    required this.videos,
    required this.total,
  });

  final List<VideoItem> videos;
  final int total;

  factory VideoListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['videos'] as List<dynamic>? ?? const [];
    return VideoListResponse(
      videos: raw
          .map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/production/workbench/get-video-list` — OpenAPI `postWorkbenchGetVideoListV1`.
Future<VideoListResponse> postWorkbenchGetVideoListV1(
  String accessToken, {
  required int projectId,
  int? trackId,
  int limit = 50,
  int offset = 0,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/workbench/get-video-list');
  final body = <String, dynamic>{
    'projectId': projectId,
    'limit': limit,
    'offset': offset,
  };
  if (trackId != null) body['trackId'] = trackId;
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
  return VideoListResponse.fromJson(map);
}

/// OpenAPI **`AddTrackResponse`**.
class AddTrackResponse {
  const AddTrackResponse({
    required this.trackId,
    required this.trackName,
    required this.message,
  });

  final int trackId;
  final String trackName;
  final String message;

  factory AddTrackResponse.fromJson(Map<String, dynamic> json) {
    return AddTrackResponse(
      trackId: (json['trackId'] as num).toInt(),
      trackName: json['trackName'] as String,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/add-track` — OpenAPI `postWorkbenchAddTrackV1`.
Future<AddTrackResponse> postWorkbenchAddTrackV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required String trackName,
  String? trackType,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/workbench/add-track');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'trackName': trackName,
  };
  if (trackType != null) body['trackType'] = trackType;
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
  return AddTrackResponse.fromJson(map);
}

/// OpenAPI **`DeleteTrackResponse`**.
class DeleteTrackResponse {
  const DeleteTrackResponse({
    required this.trackId,
    required this.message,
  });

  final int trackId;
  final String message;

  factory DeleteTrackResponse.fromJson(Map<String, dynamic> json) {
    return DeleteTrackResponse(
      trackId: (json['trackId'] as num).toInt(),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/delete-track` — OpenAPI `postWorkbenchDeleteTrackV1`.
Future<DeleteTrackResponse> postWorkbenchDeleteTrackV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int trackId,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/workbench/delete-track');
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
          'trackId': trackId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DeleteTrackResponse.fromJson(map);
}

/// OpenAPI **`DeleteVideoResponse`**.
class DeleteVideoResponse {
  const DeleteVideoResponse({
    required this.storyboardId,
    required this.message,
  });

  final int storyboardId;
  final String message;

  factory DeleteVideoResponse.fromJson(Map<String, dynamic> json) {
    return DeleteVideoResponse(
      storyboardId: (json['storyboardId'] as num).toInt(),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/delete-video` — OpenAPI `postWorkbenchDeleteVideoV1`.
Future<DeleteVideoResponse> postWorkbenchDeleteVideoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/workbench/delete-video');
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
          'storyboardId': storyboardId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DeleteVideoResponse.fromJson(map);
}

/// OpenAPI **`SelectVideoResponse`**.
class SelectVideoResponse {
  const SelectVideoResponse({
    required this.storyboardId,
    required this.videoUrl,
    required this.message,
  });

  final int storyboardId;
  final String videoUrl;
  final String message;

  factory SelectVideoResponse.fromJson(Map<String, dynamic> json) {
    return SelectVideoResponse(
      storyboardId: (json['storyboardId'] as num).toInt(),
      videoUrl: json['videoUrl'] as String,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/select-video` — OpenAPI `postWorkbenchSelectVideoV1`.
Future<SelectVideoResponse> postWorkbenchSelectVideoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
  required String videoUrl,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/workbench/select-video');
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
          'storyboardId': storyboardId,
          'videoUrl': videoUrl,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SelectVideoResponse.fromJson(map);
}

/// OpenAPI **`VideoModelDetail`**.
class VideoModelDetail {
  const VideoModelDetail({
    required this.id,
    required this.modelName,
    required this.provider,
    required this.maxDuration,
    required this.resolutions,
    required this.features,
  });

  final String id;
  final String modelName;
  final String provider;
  final int maxDuration;
  final List<String> resolutions;
  final List<String> features;

  factory VideoModelDetail.fromJson(Map<String, dynamic> json) {
    return VideoModelDetail(
      id: json['id'] as String,
      modelName: json['modelName'] as String,
      provider: json['provider'] as String,
      maxDuration: (json['maxDuration'] as num).toInt(),
      resolutions: (json['resolutions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      features: (json['features'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}

/// `POST /api/v1/production/workbench/get-video-model-detail` — OpenAPI `postWorkbenchGetVideoModelDetailV1`.
Future<VideoModelDetail> postWorkbenchGetVideoModelDetailV1(
  String accessToken,
) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/workbench/get-video-model-detail');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VideoModelDetail.fromJson(map);
}

/// OpenAPI **`GenerateVideoPromptResponse`**.
class GenerateVideoPromptResponse {
  const GenerateVideoPromptResponse({
    required this.prompt,
    required this.model,
    required this.duration,
  });

  final String prompt;
  final String model;
  final int duration;

  factory GenerateVideoPromptResponse.fromJson(Map<String, dynamic> json) {
    return GenerateVideoPromptResponse(
      prompt: json['prompt'] as String,
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
  String? imageUrl,
  String? description,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/workbench/generate-video-prompt');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
  };
  if (imageUrl != null) body['imageUrl'] = imageUrl;
  if (description != null) body['description'] = description;
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
    required this.videos,
    required this.activeJobs,
  });

  final List<VideoItem> videos;
  final List<JobRow> activeJobs;

  factory GetGenerateDataResponse.fromJson(Map<String, dynamic> json) {
    final rawVideos = json['videos'] as List<dynamic>? ?? const [];
    final rawJobs = json['activeJobs'] as List<dynamic>? ?? const [];
    return GetGenerateDataResponse(
      videos: rawVideos
          .map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeJobs: rawJobs
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
      '$kApiBaseUrl/api/v1/production/workbench/get-generate-data');
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
        }),
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

/// OpenAPI **`ProductionStoryboardItem`**.
class ProductionStoryboardItemV1 {
  const ProductionStoryboardItemV1({
    required this.id,
    this.scriptId,
    this.prompt,
    this.url,
    this.duration,
    this.state,
    this.trackId,
    this.flowId,
    this.sbIndex,
  });

  final int id;
  final int? scriptId;
  final String? prompt;
  final String? url;
  final String? duration;
  final String? state;
  final int? trackId;
  final int? flowId;
  final int? sbIndex;

  factory ProductionStoryboardItemV1.fromJson(Map<String, dynamic> json) {
    return ProductionStoryboardItemV1(
      id: (json['id'] as num).toInt(),
      scriptId:
          json['scriptId'] == null ? null : (json['scriptId'] as num).toInt(),
      prompt: json['prompt'] as String?,
      url: json['url'] as String?,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId:
          json['trackId'] == null ? null : (json['trackId'] as num).toInt(),
      flowId: json['flowId'] == null ? null : (json['flowId'] as num).toInt(),
      sbIndex:
          json['sbIndex'] == null ? null : (json['sbIndex'] as num).toInt(),
    );
  }
}

/// OpenAPI **`ProductionGetProductionDataResponse`**.
class ProductionGetProductionDataResponseV1 {
  const ProductionGetProductionDataResponseV1({required this.data});

  final List<ProductionStoryboardItemV1> data;

  factory ProductionGetProductionDataResponseV1.fromJson(
      Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return ProductionGetProductionDataResponseV1(
      data: raw
          .map((e) => ProductionStoryboardItemV1.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// OpenAPI **`StoryboardAddResponse`**.
class StoryboardAddResponse {
  const StoryboardAddResponse({
    required this.storyboardId,
    required this.message,
  });

  final int storyboardId;
  final String message;

  factory StoryboardAddResponse.fromJson(Map<String, dynamic> json) {
    return StoryboardAddResponse(
      storyboardId: (json['storyboardId'] as num).toInt(),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/storyboard/add` — OpenAPI `postStoryboardAddV1`.
Future<StoryboardAddResponse> postStoryboardAddV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required String prompt,
  String? duration,
  String? state,
  int? trackId,
  int? flowId,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/add');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'prompt': prompt,
  };
  if (duration != null) body['duration'] = duration;
  if (state != null) body['state'] = state;
  if (trackId != null) body['trackId'] = trackId;
  if (flowId != null) body['flowId'] = flowId;
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
  return StoryboardAddResponse.fromJson(map);
}

/// OpenAPI **`StoryboardBatchAddInfoResponse`**.
class StoryboardBatchAddInfoResponse {
  const StoryboardBatchAddInfoResponse({
    required this.added,
    required this.message,
  });

  final int added;
  final String message;

  factory StoryboardBatchAddInfoResponse.fromJson(Map<String, dynamic> json) {
    return StoryboardBatchAddInfoResponse(
      added: (json['added'] as num).toInt(),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/storyboard/batch-add-info` — OpenAPI `postStoryboardBatchAddInfoV1`.
Future<StoryboardBatchAddInfoResponse> postStoryboardBatchAddInfoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<String> prompts,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/batch-add-info');
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
          'prompts': prompts,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardBatchAddInfoResponse.fromJson(map);
}

/// `POST /api/v1/production/storyboard/edit-info` — OpenAPI `postStoryboardEditInfoV1`.
Future<int> postStoryboardEditInfoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
  required String prompt,
  String? duration,
  String? state,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/edit-info');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'storyboardId': storyboardId,
    'prompt': prompt,
  };
  if (duration != null) body['duration'] = duration;
  if (state != null) body['state'] = state;
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
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/get-data` — OpenAPI `postStoryboardGetDataV1`.
Future<ProductionStoryboardItemV1> postStoryboardGetDataV1(
  String accessToken, {
  required int storyboardId,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/get-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'storyboardId': storyboardId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProductionStoryboardItemV1.fromJson(map);
}

/// `POST /api/v1/production/storyboard/remove-frame` — OpenAPI `postStoryboardRemoveFrameV1`.
Future<int> postStoryboardRemoveFrameV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/remove-frame');
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
          'storyboardId': storyboardId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/update-url` — OpenAPI `postStoryboardUpdateUrlV1`.
Future<int> postStoryboardUpdateUrlV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
  required String url,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/update-url');
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
          'storyboardId': storyboardId,
          'url': url,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/preview-image` — OpenAPI `postStoryboardPreviewImageV1`.
Future<int> postStoryboardPreviewImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
  required String imageUrl,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/preview-image');
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
          'storyboardId': storyboardId,
          'imageUrl': imageUrl,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/down-preview-image` — OpenAPI `postStoryboardDownPreviewImageV1`.
Future<int> postStoryboardDownPreviewImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/storyboard/down-preview-image');
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
          'storyboardId': storyboardId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.statusCode;
}

/// `POST /api/v1/production/get-storyboard-data` — OpenAPI `postProductionGetStoryboardDataV1`.
Future<ProductionGetProductionDataResponseV1> postProductionGetStoryboardDataV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
}) async {
  final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/production/get-storyboard-data');
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
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProductionGetProductionDataResponseV1.fromJson(map);
}
