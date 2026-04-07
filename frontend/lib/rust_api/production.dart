import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';
part 'production_assets.dart';
part 'production_edit_image.dart';

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
        body: jsonEncode({'projectId': projectId, 'episodesId': episodesId}),
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
    throw ArgumentError.value(
      path,
      'path',
      'must start with /api/v1/production/',
    );
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
    '$kApiBaseUrl/api/v1/production/storyboard/batch-generate-image',
  );
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
  const VideoListResponse({required this.videos, required this.total});

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
    '$kApiBaseUrl/api/v1/production/workbench/get-video-list',
  );
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
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/workbench/add-track');
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
  const DeleteTrackResponse({required this.trackId, required this.message});

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
    '$kApiBaseUrl/api/v1/production/workbench/delete-track',
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
    '$kApiBaseUrl/api/v1/production/workbench/delete-video',
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
    '$kApiBaseUrl/api/v1/production/workbench/select-video',
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
    required this.modelId,
    required this.modelName,
    required this.provider,
    required this.maxDuration,
    required this.resolutions,
    required this.features,
  });

  final String modelId;
  final String modelName;
  final String provider;
  final int maxDuration;
  final List<String> resolutions;
  final List<String> features;

  factory VideoModelDetail.fromJson(Map<String, dynamic> json) {
    return VideoModelDetail(
      modelId: json['modelId'] as String,
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
    '$kApiBaseUrl/api/v1/production/workbench/get-video-model-detail',
  );
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
    '$kApiBaseUrl/api/v1/production/workbench/generate-video-prompt',
  );
  final body = <String, dynamic>{'projectId': projectId, 'scriptId': scriptId};
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
      scriptId: json['scriptId'] == null
          ? null
          : (json['scriptId'] as num).toInt(),
      prompt: json['prompt'] as String?,
      url: json['url'] as String?,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId: json['trackId'] == null
          ? null
          : (json['trackId'] as num).toInt(),
      flowId: json['flowId'] == null ? null : (json['flowId'] as num).toInt(),
      sbIndex: json['sbIndex'] == null
          ? null
          : (json['sbIndex'] as num).toInt(),
    );
  }
}

/// OpenAPI **`ProductionGetProductionDataResponse`**.
class ProductionGetProductionDataResponseV1 {
  const ProductionGetProductionDataResponseV1({required this.data});

  final List<ProductionStoryboardItemV1> data;

  factory ProductionGetProductionDataResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return ProductionGetProductionDataResponseV1(
      data: raw
          .map(
            (e) =>
                ProductionStoryboardItemV1.fromJson(e as Map<String, dynamic>),
          )
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
  int? duration,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/add');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'prompt': prompt,
  };
  if (duration != null) body['duration'] = duration;
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
    required this.storyboardIds,
  });

  final int added;
  final List<int> storyboardIds;

  factory StoryboardBatchAddInfoResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['storyboardIds'] as List<dynamic>? ?? const [];
    return StoryboardBatchAddInfoResponse(
      added: (json['added'] as num).toInt(),
      storyboardIds: raw.map((e) => (e as num).toInt()).toList(),
    );
  }
}

class StoryboardBatchAddInfoItem {
  const StoryboardBatchAddInfoItem({required this.prompt, this.duration});

  final String prompt;
  final int? duration;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{'prompt': prompt};
    if (duration != null) body['duration'] = duration;
    return body;
  }
}

/// `POST /api/v1/production/storyboard/batch-add-info` — OpenAPI `postStoryboardBatchAddInfoV1`.
Future<StoryboardBatchAddInfoResponse> postStoryboardBatchAddInfoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<StoryboardBatchAddInfoItem> storyboards,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/batch-add-info',
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
          'storyboards': storyboards.map((e) => e.toJson()).toList(),
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
  required int storyboardId,
  required String prompt,
  int? duration,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/edit-info');
  final body = <String, dynamic>{
    'storyboardId': storyboardId,
    'prompt': prompt,
  };
  if (duration != null) body['duration'] = duration;
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
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/get-data');
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
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/remove-frame',
  );
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
  return res.statusCode;
}

class UpdateStoryboardUrlResponseV1 {
  const UpdateStoryboardUrlResponseV1({
    required this.storyboardId,
    required this.imageUrl,
    required this.message,
  });

  final int storyboardId;
  final String imageUrl;
  final String message;

  factory UpdateStoryboardUrlResponseV1.fromJson(Map<String, dynamic> json) {
    return UpdateStoryboardUrlResponseV1(
      storyboardId: (json['storyboardId'] as num).toInt(),
      imageUrl: json['imageUrl'] as String,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/storyboard/update-url` — OpenAPI `postStoryboardUpdateUrlV1`.
Future<UpdateStoryboardUrlResponseV1> postStoryboardUpdateUrlV1(
  String accessToken, {
  required int storyboardId,
  required String imageUrl,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/update-url');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'storyboardId': storyboardId,
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
  return UpdateStoryboardUrlResponseV1.fromJson(map);
}

class PreviewImageResponseV1 {
  const PreviewImageResponseV1({
    required this.storyboardId,
    this.imageUrl,
    this.prompt,
  });

  final int storyboardId;
  final String? imageUrl;
  final String? prompt;

  factory PreviewImageResponseV1.fromJson(Map<String, dynamic> json) {
    return PreviewImageResponseV1(
      storyboardId: (json['storyboardId'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      prompt: json['prompt'] as String?,
    );
  }
}

/// `POST /api/v1/production/storyboard/preview-image` — OpenAPI `postStoryboardPreviewImageV1`.
Future<PreviewImageResponseV1> postStoryboardPreviewImageV1(
  String accessToken, {
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/preview-image',
  );
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
  return PreviewImageResponseV1.fromJson(map);
}

class DownPreviewImageResponseV1 {
  const DownPreviewImageResponseV1({
    required this.storyboardId,
    this.previewUrl,
    required this.message,
  });

  final int storyboardId;
  final String? previewUrl;
  final String message;

  factory DownPreviewImageResponseV1.fromJson(Map<String, dynamic> json) {
    return DownPreviewImageResponseV1(
      storyboardId: (json['storyboardId'] as num).toInt(),
      previewUrl: json['previewUrl'] as String?,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/storyboard/down-preview-image` — OpenAPI `postStoryboardDownPreviewImageV1`.
Future<DownPreviewImageResponseV1> postStoryboardDownPreviewImageV1(
  String accessToken, {
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/down-preview-image',
  );
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
  return DownPreviewImageResponseV1.fromJson(map);
}

/// `POST /api/v1/production/get-storyboard-data` — OpenAPI `postProductionGetStoryboardDataV1`.
Future<ProductionGetProductionDataResponseV1> postProductionGetStoryboardDataV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-storyboard-data');
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
  return ProductionGetProductionDataResponseV1.fromJson(map);
}
