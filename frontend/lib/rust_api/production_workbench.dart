part of 'production.dart';

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
