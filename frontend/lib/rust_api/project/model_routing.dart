import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class ProjectModelRoutingDefaults {
  const ProjectModelRoutingDefaults({
    this.textModel,
    this.multimodalModel,
    this.imageModel,
    this.videoModel,
    this.voiceModel,
  });

  final String? textModel;
  final String? multimodalModel;
  final String? imageModel;
  final String? videoModel;
  final String? voiceModel;

  factory ProjectModelRoutingDefaults.fromJson(Map<String, dynamic> json) {
    return ProjectModelRoutingDefaults(
      textModel: json['text_model'] as String?,
      multimodalModel: json['multimodal_model'] as String?,
      imageModel: json['image_model'] as String?,
      videoModel: json['video_model'] as String?,
      voiceModel: json['voice_model'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (textModel != null) 'text_model': textModel,
    if (multimodalModel != null) 'multimodal_model': multimodalModel,
    if (imageModel != null) 'image_model': imageModel,
    if (videoModel != null) 'video_model': videoModel,
    if (voiceModel != null) 'voice_model': voiceModel,
  };
}

class ModelRoutingEffectiveEntry {
  const ModelRoutingEffectiveEntry({
    required this.step,
    required this.slot,
    required this.modelId,
    required this.source,
  });

  final String step;
  final String slot;
  final String modelId;
  final String source;

  factory ModelRoutingEffectiveEntry.fromJson(Map<String, dynamic> json) {
    return ModelRoutingEffectiveEntry(
      step: json['step'] as String,
      slot: json['slot'] as String,
      modelId: json['model_id'] as String,
      source: json['source'] as String,
    );
  }
}

class ProjectModelRoutingResponse {
  const ProjectModelRoutingResponse({
    required this.projectId,
    required this.defaults,
    required this.steps,
    required this.effective,
  });

  final String projectId;
  final ProjectModelRoutingDefaults defaults;
  final Map<String, Map<String, String>> steps;
  final List<ModelRoutingEffectiveEntry> effective;

  factory ProjectModelRoutingResponse.fromJson(Map<String, dynamic> json) {
    final stepsRaw = json['steps'] as Map<String, dynamic>? ?? const {};
    final steps = <String, Map<String, String>>{};
    for (final entry in stepsRaw.entries) {
      final slotMap = entry.value as Map<String, dynamic>? ?? const {};
      final normalized = <String, String>{};
      for (final slotEntry in slotMap.entries) {
        final raw = slotEntry.value;
        if (raw == null) continue;
        final value = raw.toString().trim();
        if (value.isEmpty) continue;
        normalized[slotEntry.key] = value;
      }
      if (normalized.isNotEmpty) {
        steps[entry.key] = normalized;
      }
    }
    final effectiveList = (json['effective'] as List<dynamic>? ?? const [])
        .map(
          (e) => ModelRoutingEffectiveEntry.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
    return ProjectModelRoutingResponse(
      projectId: json['project_id'] as String,
      defaults: ProjectModelRoutingDefaults.fromJson(
        json['defaults'] as Map<String, dynamic>,
      ),
      steps: steps,
      effective: effectiveList,
    );
  }

  String? effectiveModelFor({required String step, required String slot}) {
    for (final e in effective) {
      if (e.step == step && e.slot == slot) return e.modelId;
    }
    return null;
  }
}

class ResolvedProjectModel {
  const ResolvedProjectModel({
    required this.modelId,
    required this.step,
    required this.slot,
    required this.source,
  });

  final String modelId;
  final String step;
  final String slot;
  final String source;

  factory ResolvedProjectModel.fromJson(Map<String, dynamic> json) {
    return ResolvedProjectModel(
      modelId: json['model_id'] as String,
      step: json['step'] as String,
      slot: json['slot'] as String,
      source: json['source'] as String,
    );
  }
}

/// `GET /api/v1/projects/{project_id}/model-routing`
Future<ProjectModelRoutingResponse> fetchProjectModelRoutingV1(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/model-routing',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ProjectModelRoutingResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

/// `PATCH /api/v1/projects/{project_id}/model-routing`
Future<ProjectModelRoutingResponse> patchProjectModelRoutingV1(
  String accessToken,
  String projectId, {
  Map<String, dynamic>? defaults,
  Map<String, Map<String, String>>? steps,
}) async {
  final body = <String, dynamic>{};
  if (defaults != null) body['defaults'] = defaults;
  if (steps != null) body['steps'] = steps;
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/model-routing',
  );
  final res = await http
      .patch(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ProjectModelRoutingResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

/// `POST /api/v1/projects/{project_id}/model-routing/resolve`
Future<ResolvedProjectModel> resolveProjectModelV1(
  String accessToken,
  String projectId, {
  required String step,
  required String slot,
  String? modelId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/model-routing/resolve',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{
          'step': step,
          'slot': slot,
          if (modelId != null && modelId.isNotEmpty) 'model_id': modelId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ResolvedProjectModel.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
