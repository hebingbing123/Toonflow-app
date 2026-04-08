import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';
part 'production_assets.dart';
part 'production_edit_image.dart';
part 'production_legacy_routes.dart';
part 'production_workbench.dart';

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
