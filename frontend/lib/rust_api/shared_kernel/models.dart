/// Shared DTOs reused across system, project, and catalog API slices.
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
