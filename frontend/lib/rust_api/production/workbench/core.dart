import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';

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
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VideoModelDetail.fromJson(map);
}
