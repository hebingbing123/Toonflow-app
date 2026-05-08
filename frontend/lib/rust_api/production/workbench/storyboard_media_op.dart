import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import '../routes.dart';
import 'video_selection.dart';

/// Payload for **`op`: `enqueueVideoExport`** on unified storyboard media op (J2).
class StoryboardMediaEnqueueVideoExportPayload {
  const StoryboardMediaEnqueueVideoExportPayload({required this.job});

  final JobRow job;

  factory StoryboardMediaEnqueueVideoExportPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return StoryboardMediaEnqueueVideoExportPayload(
      job: JobRow.fromJson(json['job'] as Map<String, dynamic>),
    );
  }
}

/// `POST /api/v1/production/workbench/storyboard-media-op` — **`postProductionWorkbenchStoryboardMediaOpV1`**.
class StoryboardMediaOpResponse {
  const StoryboardMediaOpResponse({
    required this.op,
    this.selectVideo,
    this.enqueueVideoExport,
    this.patchRegeneration,
  });

  final String op;
  final SelectVideoResponse? selectVideo;
  final StoryboardMediaEnqueueVideoExportPayload? enqueueVideoExport;
  final ProductionPatchResponse? patchRegeneration;

  factory StoryboardMediaOpResponse.fromJson(Map<String, dynamic> json) {
    return StoryboardMediaOpResponse(
      op: json['op'] as String? ?? '',
      selectVideo: json['selectVideo'] == null
          ? null
          : SelectVideoResponse.fromJson(
              json['selectVideo'] as Map<String, dynamic>,
            ),
      enqueueVideoExport: json['enqueueVideoExport'] == null
          ? null
          : StoryboardMediaEnqueueVideoExportPayload.fromJson(
              json['enqueueVideoExport'] as Map<String, dynamic>,
            ),
      patchRegeneration: json['patchRegeneration'] == null
          ? null
          : ProductionPatchResponse.fromJson(
              json['patchRegeneration'] as Map<String, dynamic>,
            ),
    );
  }
}

Future<StoryboardMediaOpResponse> postWorkbenchStoryboardMediaOpV1(
  String accessToken,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/storyboard-media-op',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 25));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardMediaOpResponse.fromJson(map);
}
