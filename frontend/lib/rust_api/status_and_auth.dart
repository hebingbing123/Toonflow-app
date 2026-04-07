part of 'index.dart';

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

/// OpenAPI `PingResponse` — legacy **`GET /api/test/test`** (`ok` text) as JSON.
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

/// `GET /api/v1/me` — Bearer; see `meV1` / OpenAPI `MeResponse`.
class MeResponse {
  const MeResponse({
    required this.sub,
    this.email,
    required this.planTier,
    this.billingCurrency,
    this.billingProvider,
  });

  final String sub;
  final String? email;
  final String planTier;
  final String? billingCurrency;
  final String? billingProvider;

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      sub: json['sub'] as String,
      email: json['email'] as String?,
      planTier: json['plan_tier'] as String,
      billingCurrency: json['billing_currency'] as String?,
      billingProvider: json['billing_provider'] as String?,
    );
  }
}

Future<MeResponse> fetchMeV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/me');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MeResponse.fromJson(map);
}

/// OpenAPI **`SwitchAiDevToolResponse`** — legacy **`getSwitchAiDevTool`**.
class SwitchAiDevToolV1 {
  const SwitchAiDevToolV1({required this.value});

  final String value;

  factory SwitchAiDevToolV1.fromJson(Map<String, dynamic> json) {
    return SwitchAiDevToolV1(value: json['value'] as String);
  }
}

/// `GET /api/v1/settings/dev/switch-ai-tool` — OpenAPI `getSwitchAiDevToolV1`.
Future<SwitchAiDevToolV1> fetchSwitchAiDevToolV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/dev/switch-ai-tool');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SwitchAiDevToolV1.fromJson(map);
}

/// `PUT /api/v1/settings/dev/switch-ai-tool` — OpenAPI `putSwitchAiDevToolV1` (typically **501**).
Future<int> putSwitchAiDevToolV1(String accessToken, String value) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/dev/switch-ai-tool');
  final res = await http
      .put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'value': value}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// OpenAPI **`MemoryConfig`** — legacy **`getMemory`** / **`sureMemory`** (**camelCase**).
class MemoryConfigV1 {
  const MemoryConfigV1({
    required this.messagesPerSummary,
    required this.shortTermLimit,
    required this.summaryMaxLength,
    required this.summaryLimit,
    required this.ragLimit,
    required this.deepRetrieveSummaryLimit,
    required this.modelOnnxFile,
    required this.modelDtype,
  });

  final int messagesPerSummary;
  final int shortTermLimit;
  final int summaryMaxLength;
  final int summaryLimit;
  final int ragLimit;
  final int deepRetrieveSummaryLimit;
  final List<String> modelOnnxFile;
  final String modelDtype;

  factory MemoryConfigV1.fromJson(Map<String, dynamic> json) {
    final files = json['modelOnnxFile'];
    return MemoryConfigV1(
      messagesPerSummary: (json['messagesPerSummary'] as num).toInt(),
      shortTermLimit: (json['shortTermLimit'] as num).toInt(),
      summaryMaxLength: (json['summaryMaxLength'] as num).toInt(),
      summaryLimit: (json['summaryLimit'] as num).toInt(),
      ragLimit: (json['ragLimit'] as num).toInt(),
      deepRetrieveSummaryLimit: (json['deepRetrieveSummaryLimit'] as num)
          .toInt(),
      modelOnnxFile: (files is List)
          ? files.map((e) => e.toString()).toList()
          : <String>[],
      modelDtype: json['modelDtype'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'messagesPerSummary': messagesPerSummary,
    'shortTermLimit': shortTermLimit,
    'summaryMaxLength': summaryMaxLength,
    'summaryLimit': summaryLimit,
    'ragLimit': ragLimit,
    'deepRetrieveSummaryLimit': deepRetrieveSummaryLimit,
    'modelOnnxFile': modelOnnxFile,
    'modelDtype': modelDtype,
  };

  MemoryConfigV1 copyWith({int? ragLimit}) {
    return MemoryConfigV1(
      messagesPerSummary: messagesPerSummary,
      shortTermLimit: shortTermLimit,
      summaryMaxLength: summaryMaxLength,
      summaryLimit: summaryLimit,
      ragLimit: ragLimit ?? this.ragLimit,
      deepRetrieveSummaryLimit: deepRetrieveSummaryLimit,
      modelOnnxFile: List<String>.from(modelOnnxFile),
      modelDtype: modelDtype,
    );
  }
}

/// `GET /api/v1/settings/memory-config` — OpenAPI `getMemoryConfigV1`.
Future<MemoryConfigV1> fetchMemoryConfigV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/memory-config');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MemoryConfigV1.fromJson(map);
}

/// `POST /api/v1/settings/memory-config` — OpenAPI `postMemoryConfigV1`; returns **`message`** (legacy success text).
Future<String> postMemoryConfigV1(
  String accessToken,
  MemoryConfigV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/memory-config');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String;
}

/// `POST /api/v1/settings/memory-config/clear-agent-memories` — OpenAPI `postSettingsClearAgentMemoriesV1` (often **503** without DB).
Future<int> postSettingsClearAgentMemoriesV1(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/memory-config/clear-agent-memories',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'episodesId': ?episodesId,
  };
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
  return res.statusCode;
}
