part of 'index.dart';

/// Row from **`GET …/projects/{project_id}/assets`** — OpenAPI **`AssetRow`**.
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

/// One row from legacy **`POST /api/v1/assets/get-assets-api`** (including nested children via **`sonAssets`**).
class LegacyAssetGetAssetsApiItem {
  const LegacyAssetGetAssetsApiItem({
    required this.id,
    required this.projectId,
    required this.assetType,
    required this.name,
    this.assetsId,
    this.imageId,
    this.filePath,
    this.state,
    this.errorReason,
    this.src,
    required this.sonAssets,
  });

  final int id;
  final int projectId;
  final String assetType;
  final String name;
  final int? assetsId;
  final int? imageId;
  final String? filePath;
  final String? state;
  final String? errorReason;
  final String? src;
  final List<LegacyAssetGetAssetsApiItem> sonAssets;

  factory LegacyAssetGetAssetsApiItem.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['sonAssets'] as List<dynamic>? ?? const [];
    return LegacyAssetGetAssetsApiItem(
      id: (json['id'] as num).toInt(),
      projectId: (json['projectId'] as num?)?.toInt() ?? 0,
      assetType: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetsId: (json['assetsId'] as num?)?.toInt(),
      imageId: (json['imageId'] as num?)?.toInt(),
      filePath: json['filePath'] as String?,
      state: json['state'] as String?,
      errorReason: json['errorReason'] as String?,
      src: json['src'] as String?,
      sonAssets: rawChildren
          .map(
            (e) =>
                LegacyAssetGetAssetsApiItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Body from legacy **`POST /api/v1/assets/get-assets-api`**.
class LegacyAssetGetAssetsApiResponse {
  const LegacyAssetGetAssetsApiResponse({
    required this.data,
    required this.total,
  });

  final List<LegacyAssetGetAssetsApiItem> data;
  final int total;

  factory LegacyAssetGetAssetsApiResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return LegacyAssetGetAssetsApiResponse(
      data: raw
          .map(
            (e) =>
                LegacyAssetGetAssetsApiItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
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

/// One item in legacy **`POST /api/v1/assets/get-image`** response **`tempAssets`**.
class LegacyAssetGetImageTempAsset {
  const LegacyAssetGetImageTempAsset({
    this.legacyImageId,
    required this.imageUuid,
    required this.filePath,
    required this.assetsId,
    required this.assetType,
    this.state,
    required this.selected,
  });

  final int? legacyImageId;
  final String imageUuid;
  final String filePath;
  final int assetsId;
  final String assetType;
  final String? state;
  final bool selected;

  factory LegacyAssetGetImageTempAsset.fromJson(Map<String, dynamic> json) {
    return LegacyAssetGetImageTempAsset(
      legacyImageId: (json['id'] as num?)?.toInt(),
      imageUuid: json['imageUuid'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      assetsId: (json['assetsId'] as num).toInt(),
      assetType: json['type'] as String? ?? '',
      state: json['state'] as String?,
      selected: json['selected'] as bool? ?? false,
    );
  }
}

/// Body of legacy **`POST /api/v1/assets/get-image`**.
class LegacyAssetGetImageResponse {
  const LegacyAssetGetImageResponse({
    required this.id,
    this.imageId,
    required this.tempAssets,
  });

  final int id;
  final int? imageId;
  final List<LegacyAssetGetImageTempAsset> tempAssets;

  factory LegacyAssetGetImageResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['tempAssets'] as List<dynamic>? ?? const [];
    return LegacyAssetGetImageResponse(
      id: (json['id'] as num).toInt(),
      imageId: (json['imageId'] as num?)?.toInt(),
      tempAssets: raw
          .map(
            (e) => LegacyAssetGetImageTempAsset.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// Body of legacy **`POST /api/v1/assets/upload-clip`**.
class LegacyAssetUploadClipResponse {
  const LegacyAssetUploadClipResponse({required this.message});

  final String message;

  factory LegacyAssetUploadClipResponse.fromJson(Map<String, dynamic> json) {
    return LegacyAssetUploadClipResponse(
      message: json['message'] as String? ?? '',
    );
  }
}

/// One row in legacy **`POST /api/v1/assets/get-material-data`** response **`data`**.
class LegacyAssetMaterialDataItem {
  const LegacyAssetMaterialDataItem({
    required this.id,
    required this.name,
    required this.filePath,
    required this.assetType,
  });

  final int id;
  final String name;
  final String filePath;
  final String assetType;

  factory LegacyAssetMaterialDataItem.fromJson(Map<String, dynamic> json) {
    return LegacyAssetMaterialDataItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      assetType: json['type'] as String? ?? '',
    );
  }
}

/// One row in legacy **`POST /api/v1/assets/get-material-data`** response **`video`**.
class LegacyAssetMaterialVideoItem {
  const LegacyAssetMaterialVideoItem({
    required this.id,
    required this.filePath,
    this.videoTrackId,
  });

  final int id;
  final String filePath;
  final int? videoTrackId;

  factory LegacyAssetMaterialVideoItem.fromJson(Map<String, dynamic> json) {
    return LegacyAssetMaterialVideoItem(
      id: (json['id'] as num).toInt(),
      filePath: json['filePath'] as String? ?? '',
      videoTrackId: (json['videoTrackId'] as num?)?.toInt(),
    );
  }
}

/// Body of legacy **`POST /api/v1/assets/get-material-data`**.
class LegacyAssetMaterialDataResponse {
  const LegacyAssetMaterialDataResponse({
    required this.data,
    required this.video,
  });

  final List<LegacyAssetMaterialDataItem> data;
  final List<LegacyAssetMaterialVideoItem> video;

  factory LegacyAssetMaterialDataResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? const [];
    final rawVideo = json['video'] as List<dynamic>? ?? const [];
    return LegacyAssetMaterialDataResponse(
      data: rawData
          .map(
            (e) =>
                LegacyAssetMaterialDataItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      video: rawVideo
          .map(
            (e) => LegacyAssetMaterialVideoItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// One row in legacy **`POST /api/v1/assets/batch-generation-data`** response **`data`**.
class LegacyAssetBatchGenerationDataItem {
  const LegacyAssetBatchGenerationDataItem({
    required this.id,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
  });

  final int id;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;

  factory LegacyAssetBatchGenerationDataItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return LegacyAssetBatchGenerationDataItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      assetType: json['type'] as String? ?? '',
      description: json['description'] as String?,
      createTimeMs: (json['createTimeMs'] as num?)?.toInt(),
    );
  }
}

/// Body of legacy **`POST /api/v1/assets/batch-generation-data`**.
class LegacyAssetBatchGenerationDataResponse {
  const LegacyAssetBatchGenerationDataResponse({
    required this.data,
    required this.total,
  });

  final List<LegacyAssetBatchGenerationDataItem> data;
  final int total;

  factory LegacyAssetBatchGenerationDataResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawData = json['data'] as List<dynamic>? ?? const [];
    return LegacyAssetBatchGenerationDataResponse(
      data: rawData
          .map(
            (e) => LegacyAssetBatchGenerationDataItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One row in legacy **`POST /api/v1/assets/polling-image-assets`** response.
class LegacyAssetPollingImageAssetsItem {
  const LegacyAssetPollingImageAssetsItem({
    required this.id,
    this.state,
    this.filePath,
  });

  final int id;
  final String? state;
  final String? filePath;

  factory LegacyAssetPollingImageAssetsItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return LegacyAssetPollingImageAssetsItem(
      id: (json['id'] as num).toInt(),
      state: json['state'] as String?,
      filePath: json['filePath'] as String?,
    );
  }
}

/// One row in legacy **`POST /api/v1/assets/polling-prompt-assets`** response.
class LegacyAssetPollingPromptAssetsItem {
  const LegacyAssetPollingPromptAssetsItem({
    required this.id,
    required this.name,
    required this.assetType,
    required this.promptState,
  });

  final int id;
  final String name;
  final String assetType;
  final String promptState;

  factory LegacyAssetPollingPromptAssetsItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return LegacyAssetPollingPromptAssetsItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      assetType: json['type'] as String? ?? '',
      promptState: json['promptState'] as String? ?? '',
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
