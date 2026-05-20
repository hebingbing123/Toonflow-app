import '../billing/pricing.dart';

/// Shared DTOs reused across system, project, and catalog API slices.
/// `GET /api/v1/usage/summary` — OpenAPI `UsageSummaryResponse`.
class UsageSummaryResponse {
  const UsageSummaryResponse({
    required this.scope,
    required this.eventsLast24h,
    required this.eventsLast7d,
    required this.eventCountsLast7d,
    required this.jobsToday,
    this.dailyJobQuota,
    this.quotaRemaining,
    this.workspaceId,
    this.workspaceName,
  });

  /// Aggregation scope for this response: "user" or "workspace"
  final String scope;
  final int eventsLast24h;
  final int eventsLast7d;
  final Map<String, int> eventCountsLast7d;
  final int jobsToday;
  final int? dailyJobQuota;
  final int? quotaRemaining;
  final String? workspaceId;
  final String? workspaceName;

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
      scope: json['scope'] as String? ?? 'user',
      eventsLast24h: (json['events_last_24h'] as num?)?.toInt() ?? 0,
      eventsLast7d: (json['events_last_7d'] as num?)?.toInt() ?? 0,
      eventCountsLast7d: counts,
      jobsToday: (json['jobs_today'] as num?)?.toInt() ?? 0,
      dailyJobQuota: (json['daily_job_quota'] as num?)?.toInt(),
      quotaRemaining: (json['quota_remaining'] as num?)?.toInt(),
      workspaceId: json['workspace_id'] as String?,
      workspaceName: json['workspace_name'] as String?,
    );
  }
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

/// Row from `GET /api/v1/models` — OpenAPI `ModelListEntry`.
class ModelListEntry {
  const ModelListEntry({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
    required this.name,
    this.modelId,
    this.pricing,
  });

  final int id;
  final String label;
  final String value;
  final String type;
  final String name;
  final String? modelId;
  final ModelPricingPublic? pricing;

  String get effectiveModelId => modelId ?? '$id:$value';

  factory ModelListEntry.fromJson(Map<String, dynamic> json) {
    final pricingRaw = json['pricing'];
    return ModelListEntry(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String,
      value: json['value'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      modelId: json['model_id'] as String?,
      pricing: pricingRaw is Map<String, dynamic>
          ? ModelPricingPublic.fromJson(pricingRaw)
          : null,
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

/// OpenAPI **`VendorCatalogSummary`** — keyless vendor row from static catalog.
class VendorCatalogSummaryV1 {
  const VendorCatalogSummaryV1({
    required this.id,
    required this.name,
    required this.modelCount,
    required this.modelKinds,
    this.defaultBaseUrl,
    this.apiKeyOptional = false,
    this.protocol = 'openai',
    this.videoProvider,
    this.officialApiHost,
  });

  final int id;
  final String name;
  final int modelCount;
  final List<String> modelKinds;
  final String? defaultBaseUrl;
  final bool apiKeyOptional;
  final String protocol;
  final String? videoProvider;
  final String? officialApiHost;

  factory VendorCatalogSummaryV1.fromJson(Map<String, dynamic> json) {
    final kinds = json['modelKinds'] ?? json['model_kinds'];
    final base =
        json['defaultBaseUrl'] as String? ?? json['default_base_url'] as String?;
    final video =
        json['videoProvider'] as String? ?? json['video_provider'] as String?;
    final official = json['officialApiHost'] as String? ??
        json['official_api_host'] as String?;
    return VendorCatalogSummaryV1(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      modelCount: ((json['modelCount'] ?? json['model_count']) as num).toInt(),
      modelKinds: (kinds is List)
          ? kinds.map((e) => e.toString()).toList()
          : <String>[],
      defaultBaseUrl: base?.trim().isEmpty == true ? null : base?.trim(),
      apiKeyOptional:
          json['apiKeyOptional'] as bool? ??
          json['api_key_optional'] as bool? ??
          false,
      protocol: (json['protocol'] as String?)?.trim().isNotEmpty == true
          ? (json['protocol'] as String).trim()
          : 'openai',
      videoProvider: video?.trim().isEmpty == true ? null : video?.trim(),
      officialApiHost:
          official?.trim().isEmpty == true ? null : official?.trim(),
    );
  }
}

/// Per-user vendor configuration from `app_user_profile.vendor_config`.
class VendorConfigEntryV1 {
  const VendorConfigEntryV1({
    required this.vendorId,
    this.displayName,
    this.enabled = false,
    this.selectedModels = const <String>[],
    this.settings = const <String, String>{},
  });

  final String vendorId;
  final String? displayName;
  final bool enabled;
  final List<String> selectedModels;
  final Map<String, String> settings;

  factory VendorConfigEntryV1.fromJson(Map<String, dynamic> json) {
    final models = json['selectedModels'] ?? json['selected_models'];
    final settingsRaw = json['settings'];
    final settings = <String, String>{};
    if (settingsRaw is Map) {
      for (final entry in settingsRaw.entries) {
        settings[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }
    return VendorConfigEntryV1(
      vendorId: (json['vendorId'] ?? json['vendor_id']).toString(),
      displayName: json['displayName'] as String? ?? json['display_name'] as String?,
      enabled: json['enabled'] as bool? ?? false,
      selectedModels: models is List
          ? models.map((e) => e.toString()).toList()
          : const <String>[],
      settings: settings,
    );
  }

  String? get baseUrl =>
      settings['base_url']?.trim().isNotEmpty == true
          ? settings['base_url']!.trim()
          : settings['baseUrl']?.trim();
}

/// One vendor row in `GET /api/v1/settings/vendors/summary`.
class VendorSummaryItemV1 {
  const VendorSummaryItemV1({
    required this.catalog,
    this.userConfig,
  });

  final VendorCatalogSummaryV1 catalog;
  final VendorConfigEntryV1? userConfig;

  factory VendorSummaryItemV1.fromJson(Map<String, dynamic> json) {
    final userRaw = json['userConfig'] ?? json['user_config'];
    return VendorSummaryItemV1(
      catalog: VendorCatalogSummaryV1.fromJson(json),
      userConfig: userRaw is Map<String, dynamic>
          ? VendorConfigEntryV1.fromJson(userRaw)
          : null,
    );
  }

  String get vendorId => catalog.id.toString();

  bool get isEnabled => userConfig?.enabled ?? false;

  List<String> get selectedModels => userConfig?.selectedModels ?? const <String>[];
}

/// OpenAPI **`VendorsSummaryResponse`**.
class VendorsSummaryResponseV1 {
  const VendorsSummaryResponseV1({required this.vendors, required this.source});

  final List<VendorSummaryItemV1> vendors;
  final String source;

  factory VendorsSummaryResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['vendors'];
    final list = <VendorSummaryItemV1>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(VendorSummaryItemV1.fromJson(e));
        }
      }
    }
    return VendorsSummaryResponseV1(
      vendors: list,
      source: json['source'] as String,
    );
  }
}

/// OpenAPI **`TextModelDefaultResponse`** — prior **`getTextModel`** stub + default composite id.
class TextModelDefaultV1 {
  const TextModelDefaultV1({
    required this.stubPlaceholder,
    required this.defaultModelId,
  });

  final String stubPlaceholder;
  final String defaultModelId;

  factory TextModelDefaultV1.fromJson(Map<String, dynamic> json) {
    return TextModelDefaultV1(
      stubPlaceholder: json['stub_placeholder'] as String,
      defaultModelId: json['default_model_id'] as String,
    );
  }
}
