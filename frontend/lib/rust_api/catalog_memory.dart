part of 'index.dart';

/// `GET /api/v1/usage/summary` — OpenAPI `UsageSummaryResponse`.
class UsageSummaryResponse {
  const UsageSummaryResponse({
    required this.eventsLast24h,
    required this.eventsLast7d,
    required this.eventCountsLast7d,
  });

  final int eventsLast24h;
  final int eventsLast7d;
  final Map<String, int> eventCountsLast7d;

  factory UsageSummaryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['event_counts_last_7d'];
    final counts = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is num) {
          counts[k] = v.toInt();
        }
      });
    }
    return UsageSummaryResponse(
      eventsLast24h: (json['events_last_24h'] as num).toInt(),
      eventsLast7d: (json['events_last_7d'] as num).toInt(),
      eventCountsLast7d: counts,
    );
  }
}

/// `GET /api/v1/usage/summary` — see `usageSummaryV1`.
Future<UsageSummaryResponse> fetchUsageSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/usage/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UsageSummaryResponse.fromJson(map);
}

/// One row from **`GET /api/v1/prompts`** (`PromptTemplateRow` in OpenAPI).
class PromptTemplateRowV1 {
  const PromptTemplateRowV1({
    required this.id,
    required this.name,
    required this.type,
    required this.data,
  });

  final int id;
  final String name;
  final String type;
  final String data;

  factory PromptTemplateRowV1.fromJson(Map<String, dynamic> json) {
    return PromptTemplateRowV1(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      data: json['data'] as String,
    );
  }
}

/// `GET /api/v1/prompts` — OpenAPI `listPromptsV1`.
Future<List<PromptTemplateRowV1>> fetchPromptsV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PromptTemplateRowV1.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/prompts/{legacy_id}` — OpenAPI `getPromptByLegacyIdV1`.
Future<PromptTemplateRowV1> fetchPromptByLegacyIdV1(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$legacyId');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PromptTemplateRowV1.fromJson(map);
}

/// `PATCH /api/v1/prompts/{legacy_id}` — OpenAPI `patchPromptByLegacyIdV1` (**`data`** only).
///
/// **`legacy_id`** must be **1**, **2**, or **3**. Returns the updated row (same shape as GET).
Future<PromptTemplateRowV1> patchPromptByLegacyIdV1(
  String accessToken,
  int legacyId,
  String data,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': data}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PromptTemplateRowV1.fromJson(map);
}

/// OpenAPI **`VisualManualEntry`**.
class VisualManualEntryV1 {
  const VisualManualEntryV1({
    required this.label,
    required this.value,
    required this.data,
  });

  final String label;
  final String value;
  final String data;

  factory VisualManualEntryV1.fromJson(Map<String, dynamic> json) {
    return VisualManualEntryV1(
      label: json['label'] as String,
      value: json['value'] as String,
      data: json['data'] as String,
    );
  }
}

/// OpenAPI **`VisualManualStyle`**.
class VisualManualStyleV1 {
  const VisualManualStyleV1({
    required this.name,
    required this.image,
    required this.stylePath,
    required this.data,
  });

  final String name;
  final List<String> image;
  final String stylePath;
  final List<VisualManualEntryV1> data;

  factory VisualManualStyleV1.fromJson(Map<String, dynamic> json) {
    final imgs = json['image'] as List<dynamic>? ?? const [];
    final slots = json['data'] as List<dynamic>? ?? const [];
    return VisualManualStyleV1(
      name: json['name'] as String,
      image: imgs.map((e) => e as String).toList(),
      stylePath: json['stylePath'] as String,
      data: slots
          .map((e) => VisualManualEntryV1.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// OpenAPI **`VisualManualResponse`**.
class VisualManualResponseV1 {
  const VisualManualResponseV1({required this.styles});

  final List<VisualManualStyleV1> styles;

  factory VisualManualResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['styles'] as List<dynamic>? ?? const [];
    return VisualManualResponseV1(
      styles: raw
          .map((e) => VisualManualStyleV1.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// `GET /api/v1/visual-manual` — OpenAPI `getVisualManualV1`.
Future<VisualManualResponseV1> fetchVisualManualV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}

/// `POST /api/v1/visual-manual` — OpenAPI `postVisualManualV1` (same JSON as GET; body ignored).
Future<VisualManualResponseV1> fetchVisualManualPostV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}

/// Builds `GET /api/v1/skills/binary?path=` — OpenAPI `getSkillBinaryV1` (JWT on the request).
Uri skillsBinaryV1Uri(String pathUnderDataSkills) {
  return Uri.parse(
    '$kApiBaseUrl/api/v1/skills/binary',
  ).replace(queryParameters: {'path': pathUnderDataSkills});
}

/// Fetches raw image (or other allowed) bytes from [`skillsBinaryV1Uri`].
Future<Uint8List> fetchSkillsBinaryV1(
  String accessToken,
  String pathUnderDataSkills,
) async {
  final uri = skillsBinaryV1Uri(pathUnderDataSkills);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(
      res.body.isNotEmpty ? res.body : 'binary response ${res.statusCode}',
      statusCode: res.statusCode,
    );
  }
  return res.bodyBytes;
}

/// Row from `GET /api/v1/models` — OpenAPI `ModelListEntry`.
class ModelListEntry {
  const ModelListEntry({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
    required this.name,
  });

  final int id;
  final String label;
  final String value;
  final String type;
  final String name;

  factory ModelListEntry.fromJson(Map<String, dynamic> json) {
    return ModelListEntry(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String,
      value: json['value'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
    );
  }
}

/// `GET /api/v1/models/detail` body — OpenAPI `ModelDetailResponse`.
class ModelDetailResponse {
  const ModelDetailResponse({
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.modelName,
    required this.type,
  });

  final int vendorId;
  final String vendorName;
  final String name;
  final String modelName;
  final String type;

  factory ModelDetailResponse.fromJson(Map<String, dynamic> json) {
    return ModelDetailResponse(
      vendorId: (json['vendor_id'] as num).toInt(),
      vendorName: json['vendor_name'] as String,
      name: json['name'] as String,
      modelName: json['model_name'] as String,
      type: json['type'] as String,
    );
  }
}

/// `GET /api/v1/models?type=…` — Bearer; see `listModelsV1`.
Future<List<ModelListEntry>> fetchModelsCatalog(
  String accessToken, {
  String typeFilter = 'all',
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/models',
  ).replace(queryParameters: {'type': typeFilter});
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ModelListEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// OpenAPI **`VendorCatalogSummary`** — keyless vendor row from static catalog.
class VendorCatalogSummaryV1 {
  const VendorCatalogSummaryV1({
    required this.id,
    required this.name,
    required this.modelCount,
    required this.modelKinds,
  });

  final int id;
  final String name;
  final int modelCount;
  final List<String> modelKinds;

  factory VendorCatalogSummaryV1.fromJson(Map<String, dynamic> json) {
    final kinds = json['modelKinds'];
    return VendorCatalogSummaryV1(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      modelCount: (json['modelCount'] as num).toInt(),
      modelKinds: (kinds is List)
          ? kinds.map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}

/// OpenAPI **`VendorsSummaryResponse`**.
class VendorsSummaryResponseV1 {
  const VendorsSummaryResponseV1({required this.vendors, required this.source});

  final List<VendorCatalogSummaryV1> vendors;
  final String source;

  factory VendorsSummaryResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['vendors'];
    final list = <VendorCatalogSummaryV1>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(VendorCatalogSummaryV1.fromJson(e));
        }
      }
    }
    return VendorsSummaryResponseV1(
      vendors: list,
      source: json['source'] as String,
    );
  }
}

/// `GET /api/v1/settings/vendors/summary` — OpenAPI `getSettingsVendorsSummaryV1`.
Future<VendorsSummaryResponseV1> fetchVendorsSummaryV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VendorsSummaryResponseV1.fromJson(map);
}

/// `GET /api/v1/models/detail?model_id=…` — Bearer; see `modelDetailV1`.
Future<ModelDetailResponse> fetchModelDetail(
  String accessToken, {
  required String modelId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/models/detail',
  ).replace(queryParameters: {'model_id': modelId});
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ModelDetailResponse.fromJson(map);
}

/// OpenAPI **`TextModelDefaultResponse`** — legacy **`getTextModel`** stub + default composite id.
class TextModelDefaultV1 {
  const TextModelDefaultV1({
    required this.legacyPlaceholder,
    required this.defaultModelId,
  });

  final String legacyPlaceholder;
  final String defaultModelId;

  factory TextModelDefaultV1.fromJson(Map<String, dynamic> json) {
    return TextModelDefaultV1(
      legacyPlaceholder: json['legacy_placeholder'] as String,
      defaultModelId: json['default_model_id'] as String,
    );
  }
}

/// `GET /api/v1/models/text-default` — OpenAPI `getTextModelDefaultV1`.
Future<TextModelDefaultV1> fetchTextModelDefaultV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models/text-default');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return TextModelDefaultV1.fromJson(map);
}

/// `POST /api/v1/agents/memory/query` — camelCase body; see `queryAgentMemoryV1`.
Future<List<dynamic>> queryAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/query');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'episodesId': episodesId,
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return jsonDecode(res.body) as List<dynamic>;
}

/// `POST /api/v1/agents/memory/clear` — OpenAPI `clearAgentMemoryV1` (**`clearType`**: `all` | `message` | `summary`).
///
/// Legacy **`type`** is also accepted by the server as an alias for **`clearType`**.
Future<bool> clearAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
  String clearType = 'all',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/clear');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'clearType': clearType,
  };
  if (episodesId != null) body['episodesId'] = episodesId;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['ok'] == true;
}

/// `POST /api/v1/agents/memory/append` — OpenAPI `appendAgentMemoryV1`; returns new message UUID.
Future<String> appendAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  required String content,
  int? episodesId,
  String role = 'user',
  String? name,
  int? createTime,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/append');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'content': content,
    'role': role,
  };
  if (episodesId != null) body['episodesId'] = episodesId;
  if (name != null) body['name'] = name;
  if (createTime != null) body['createTime'] = createTime;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['id'] as String;
}
