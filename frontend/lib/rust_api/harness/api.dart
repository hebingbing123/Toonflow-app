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

/// `persistHarnessUserWasmV1` — **201** JSON body.
class PersistHarnessUserWasmResponse {
  const PersistHarnessUserWasmResponse({
    required this.id,
    required this.wasmSha256Hex,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String wasmSha256Hex;
  final int sizeBytes;
  final DateTime createdAt;

  factory PersistHarnessUserWasmResponse.fromJson(Map<String, dynamic> json) {
    return PersistHarnessUserWasmResponse(
      id: json['id'] as String,
      wasmSha256Hex: json['wasm_sha256_hex'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// One row returned by **`listHarnessUserWasmV1`** (**no** `wasm_bytes`).
class HarnessUserWasmRecordView {
  const HarnessUserWasmRecordView({
    required this.id,
    required this.wasmSha256Hex,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String wasmSha256Hex;
  final int sizeBytes;
  final DateTime createdAt;

  factory HarnessUserWasmRecordView.fromJson(Map<String, dynamic> json) {
    return HarnessUserWasmRecordView(
      id: json['id'] as String,
      wasmSha256Hex: json['wasm_sha256_hex'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// **`listHarnessUserWasmV1`** — **200** JSON body (`items`).
class ListHarnessUserWasmResponse {
  const ListHarnessUserWasmResponse({required this.items});

  final List<HarnessUserWasmRecordView> items;

  factory ListHarnessUserWasmResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListHarnessUserWasmResponse(
      items: raw
          .map((e) => HarnessUserWasmRecordView.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// **`revokeHarnessUserWasmV1`** — **200** JSON body.
class RevokeHarnessUserWasmResponse {
  const RevokeHarnessUserWasmResponse({
    required this.id,
    required this.revokedAt,
  });

  final String id;
  final DateTime revokedAt;

  factory RevokeHarnessUserWasmResponse.fromJson(Map<String, dynamic> json) {
    return RevokeHarnessUserWasmResponse(
      id: json['id'] as String,
      revokedAt: DateTime.parse(json['revoked_at'] as String),
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

/// **`POST /api/v1/harness/user-wasm`**. See `persistHarnessUserWasmV1`.
Future<PersistHarnessUserWasmResponse> persistHarnessUserWasm(
  String accessToken,
  List<int> wasmBytes, {
  String contentType = 'application/wasm',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/user-wasm');
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
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PersistHarnessUserWasmResponse.fromJson(map);
}

/// **`GET /api/v1/harness/user-wasm`**. See `listHarnessUserWasmV1`.
Future<ListHarnessUserWasmResponse> listHarnessUserWasm(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/user-wasm');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListHarnessUserWasmResponse.fromJson(map);
}

/// **`DELETE /api/v1/harness/user-wasm/{id}`**. See `revokeHarnessUserWasmV1`.
Future<RevokeHarnessUserWasmResponse> revokeHarnessUserWasm(
  String accessToken,
  String wasmRowId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/user-wasm/$wasmRowId');
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return RevokeHarnessUserWasmResponse.fromJson(map);
}
