part of '../index.dart';

/// Health, ping, version, and readiness system probes.
/// JSON body for **`GET /health`** and **`GET /api/v1/health`** (OpenAPI `HealthResponse`).
class HealthResponse {
  const HealthResponse({required this.status, required this.service});

  final String status;
  final String service;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      service: json['service'] as String,
    );
  }
}

/// `GET /api/v1/health` — no auth.
Future<HealthResponse> fetchHealthV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/health');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HealthResponse.fromJson(map);
}

/// Unversioned **`GET /health`** — same JSON as [fetchHealthV1].
Future<HealthResponse> fetchHealthRoot() async {
  final uri = Uri.parse('$kApiBaseUrl/health');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HealthResponse.fromJson(map);
}

/// OpenAPI `PingResponse` — prior **`GET /api/test/test`** (`ok` text) as JSON.
class PingResponse {
  const PingResponse({required this.ok});

  final bool ok;

  factory PingResponse.fromJson(Map<String, dynamic> json) {
    return PingResponse(ok: json['ok'] as bool);
  }
}

/// `GET /api/v1/ping` — no auth.
Future<PingResponse> fetchPingV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/ping');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PingResponse.fromJson(map);
}

/// `GET /api/v1/version` — no auth; OpenAPI `VersionResponse`.
class VersionResponse {
  const VersionResponse({
    required this.service,
    required this.version,
    this.gitSha,
  });

  final String service;
  final String version;
  final String? gitSha;

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      service: json['service'] as String,
      version: json['version'] as String,
      gitSha: json['git_sha'] as String?,
    );
  }
}

Future<VersionResponse> fetchVersionV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/version');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VersionResponse.fromJson(map);
}

/// `GET /api/v1/ready` — no auth; see `readyV1`.
class ReadyV1Response {
  const ReadyV1Response({required this.status, required this.database});

  final String status;
  final String database;

  factory ReadyV1Response.fromJson(Map<String, dynamic> json) {
    return ReadyV1Response(
      status: json['status'] as String,
      database: json['database'] as String,
    );
  }
}

Future<ReadyV1Response> fetchReadyV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/ready');
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ReadyV1Response.fromJson(map);
}
