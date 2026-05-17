import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class ProjectCharacterV1 {
  const ProjectCharacterV1({
    required this.id,
    required this.projectId,
    required this.name,
    this.assetId,
    required this.voiceConfig,
  });

  final String id;
  final String projectId;
  final String name;
  final String? assetId;
  final Map<String, dynamic> voiceConfig;

  factory ProjectCharacterV1.fromJson(Map<String, dynamic> json) {
    return ProjectCharacterV1(
      id: json['id'] as String? ?? '',
      projectId:
          json['projectId'] as String? ?? json['project_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetId: json['assetId'] as String? ?? json['asset_id'] as String?,
      voiceConfig: (json['voiceConfig'] ?? json['voice_config']) is Map
          ? Map<String, dynamic>.from(
              (json['voiceConfig'] ?? json['voice_config']) as Map,
            )
          : <String, dynamic>{},
    );
  }
}

Future<List<ProjectCharacterV1>> listProjectCharactersV1(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/characters');
  final response = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (response.statusCode != 200) {
    throw RustApiException.fromHttpResponse(response);
  }
  final list = jsonDecode(response.body) as List<dynamic>;
  return list
      .map(
        (e) => ProjectCharacterV1.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(growable: false);
}

Future<ProjectCharacterV1> createProjectCharacterV1(
  String accessToken,
  String projectId, {
  required String name,
  String? assetId,
  Map<String, dynamic>? voiceConfig,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/characters');
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'name': name,
      'assetId': ?assetId,
      'voiceConfig': voiceConfig ?? <String, dynamic>{},
    }),
  );
  if (response.statusCode != 201) {
    throw RustApiException.fromHttpResponse(response);
  }
  return ProjectCharacterV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(response.body) as Map),
  );
}

Future<ProjectCharacterV1> patchProjectCharacterV1(
  String accessToken,
  String projectId,
  String characterId, {
  String? name,
  String? assetId,
  Map<String, dynamic>? voiceConfig,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/characters/$characterId',
  );
  final body = <String, dynamic>{};
  if (name != null) {
    body['name'] = name;
  }
  if (assetId != null) {
    body['assetId'] = assetId;
  }
  if (voiceConfig != null) {
    body['voiceConfig'] = voiceConfig;
  }
  final response = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );
  if (response.statusCode != 200) {
    throw RustApiException.fromHttpResponse(response);
  }
  return ProjectCharacterV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(response.body) as Map),
  );
}

Future<http.Response> previewTtsV1(
  String accessToken, {
  required String text,
  String? projectId,
  String? voiceId,
  String? provider,
  String? emotion,
  double? speed,
  String? characterId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tts/preview');
  return http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'text': text,
      'project_id': ?projectId,
      'voice_id': ?voiceId,
      'provider': ?provider,
      'emotion': ?emotion,
      'speed': ?speed,
      'character_id': ?characterId,
    }),
  );
}
