part of '../../index.dart';

/// One **`app_asset_image`** row in **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeHistoryImage`**.
class CornerScapeHistoryImage {
  const CornerScapeHistoryImage({
    required this.id,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.numericImageId,
  });

  final String id;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? numericImageId;

  factory CornerScapeHistoryImage.fromJson(Map<String, dynamic> json) {
    return CornerScapeHistoryImage(
      id: json['id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      numericImageId: (json['numeric_image_id'] as num?)?.toInt(),
    );
  }
}

/// One row from **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeAssetItem`**.
class CornerScapeAssetItem {
  const CornerScapeAssetItem({
    required this.id,
    required this.numericId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
    required this.metadata,
    required this.historyImages,
  });

  final String id;
  final int numericId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;
  final Map<String, dynamic> metadata;
  final List<CornerScapeHistoryImage> historyImages;

  factory CornerScapeAssetItem.fromJson(Map<String, dynamic> json) {
    final histRaw = json['history_images'] as List<dynamic>? ?? const [];
    final hist = histRaw
        .map((e) => CornerScapeHistoryImage.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['metadata'];
    return CornerScapeAssetItem(
      id: json['id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: (json['create_time_ms'] as num?)?.toInt(),
      metadata: meta is Map<String, dynamic> ? meta : <String, dynamic>{},
      historyImages: hist,
    );
  }
}

/// OpenAPI **`CornerScapeResponse`**.
class CornerScapeResponse {
  const CornerScapeResponse({required this.items});

  final List<CornerScapeAssetItem> items;

  factory CornerScapeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return CornerScapeResponse(
      items: raw
          .map((e) => CornerScapeAssetItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
