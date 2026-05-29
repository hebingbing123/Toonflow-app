import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class CloneVoiceResponseV1 {
  const CloneVoiceResponseV1({
    required this.customVoiceId,
    required this.provider,
  });

  final String customVoiceId;
  final String provider;

  factory CloneVoiceResponseV1.fromJson(Map<String, dynamic> json) {
    return CloneVoiceResponseV1(
      customVoiceId:
          json['customVoiceId'] as String? ?? json['custom_voice_id'] as String? ?? '',
      provider: json['provider'] as String? ?? 'mock',
    );
  }
}

Future<CloneVoiceResponseV1> postCloneVoiceV1(
  String accessToken, {
  required String projectId,
  required String displayName,
  required List<int> audioBytes,
  String? locale,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tts/clone-voice');
  final response = await http.post(
    uri,
    headers: rustApiJsonAuthHeaders(accessToken),
    body: jsonEncode(<String, dynamic>{
      'projectId': projectId,
      'displayName': displayName,
      if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
      'audioBase64': base64Encode(audioBytes),
    }),
  );
  if (response.statusCode != 200) {
    throw RustApiException.fromHttpResponse(response);
  }
  return CloneVoiceResponseV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(response.body) as Map),
  );
}
