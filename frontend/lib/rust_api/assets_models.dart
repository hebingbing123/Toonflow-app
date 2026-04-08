part of 'index.dart';

/// Row from **`GET …/projects/legacy/{id}/assets`** — OpenAPI **`AssetRow`**.
class AssetRow {
  const AssetRow({
    required this.id,
    required this.legacyId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;

  factory AssetRow.fromJson(Map<String, dynamic> json) {
    return AssetRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// Body of **`GET …/assets`** — OpenAPI **`ListAssetsResponse`**.
class ListAssetsResponse {
  const ListAssetsResponse({required this.items, required this.total});

  final List<AssetRow> items;
  final int total;

  factory ListAssetsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetsResponse(
      items: raw
          .map((e) => AssetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One **`app_asset_image`** row in **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeHistoryImage`**.
class CornerScapeHistoryImage {
  const CornerScapeHistoryImage({
    required this.id,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.legacyImageId,
  });

  final String id;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? legacyImageId;

  factory CornerScapeHistoryImage.fromJson(Map<String, dynamic> json) {
    return CornerScapeHistoryImage(
      id: json['id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      legacyImageId: (json['legacy_image_id'] as num?)?.toInt(),
    );
  }
}

/// One row from **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeAssetItem`**.
class CornerScapeAssetItem {
  const CornerScapeAssetItem({
    required this.id,
    required this.legacyId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
    required this.metadata,
    required this.historyImages,
  });

  final String id;
  final int legacyId;
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
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: (json['create_time_ms'] as num?)?.toInt(),
      metadata: meta is Map<String, dynamic> ? meta : <String, dynamic>{},
      historyImages: hist,
    );
  }
}

/// OpenAPI **`AssetImageRow`** — response from **`POST …/assets/{aid}/images`** (and list items share these fields).
class AssetImageRow {
  const AssetImageRow({
    required this.id,
    required this.assetId,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.legacyImageId,
    this.selected,
  });

  final String id;
  final String assetId;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? legacyImageId;

  /// Present on **`GET …/images`** list items only (`AssetImageListItem`).
  final bool? selected;

  factory AssetImageRow.fromJson(Map<String, dynamic> json) {
    return AssetImageRow(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      legacyImageId: (json['legacy_image_id'] as num?)?.toInt(),
      selected: json['selected'] as bool?,
    );
  }
}

/// OpenAPI **`ListAssetImagesResponse`**.
class ListAssetImagesResponse {
  const ListAssetImagesResponse({this.coverLegacyImageId, required this.items});

  final int? coverLegacyImageId;
  final List<AssetImageRow> items;

  factory ListAssetImagesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetImagesResponse(
      coverLegacyImageId: (json['cover_legacy_image_id'] as num?)?.toInt(),
      items: raw
          .map((e) => AssetImageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
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
