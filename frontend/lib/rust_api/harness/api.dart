import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Harness tool discovery models and endpoints.
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

/// `validateHarnessUserWasmV1` — **200** JSON body.
class ValidateHarnessUserWasmResponse {
  const ValidateHarnessUserWasmResponse({
    required this.validated,
    required this.sizeBytes,
  });

  final bool validated;
  final int sizeBytes;

  factory ValidateHarnessUserWasmResponse.fromJson(Map<String, dynamic> json) {
    return ValidateHarnessUserWasmResponse(
      validated: json['validated'] as bool,
      sizeBytes: (json['size_bytes'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/harness/tools`. See `listHarnessToolsV1`.
Future<HarnessToolsResponse> fetchHarnessTools(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/tools');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HarnessToolsResponse.fromJson(map);
}

/// `POST /api/v1/harness/user-wasm/validate`. See `validateHarnessUserWasmV1`.
///
/// Sends raw module bytes; default [contentType] matches OpenAPI (`application/wasm`).
Future<ValidateHarnessUserWasmResponse> validateHarnessUserWasm(
  String accessToken,
  List<int> wasmBytes, {
  String contentType = 'application/wasm',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/user-wasm/validate');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': contentType,
        },
        body: wasmBytes,
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ValidateHarnessUserWasmResponse.fromJson(map);
}
